#!/usr/bin/env python3
"""Let ALONE VPN receive links, shared text and files from other apps.

* AndroidManifest: VIEW filters for vless:// vmess:// ss:// trojan:// hysteria2:// ... links,
  VIEW for text / json / OpenVPN-profile files, and SEND for shared text.
* MainActivity.kt: reads the intent (text or file contents, max 256 KB) and hands it to Dart over
  the MethodChannel "alone/intent" (see lib/services/incoming.dart).
Idempotent: safe to run again on a reused checkout.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

MANIFEST = Path("android/app/src/main/AndroidManifest.xml")
MARK = "alone-incoming"

SCHEMES = ["vless", "vmess", "ss", "trojan", "hysteria", "hysteria2", "hy2", "tuic", "wireguard", "socks", "ssh"]
FILTERS = "\n            <!-- %s -->\n" % MARK + """            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
""" + "".join('                <data android:scheme="%s"/>\n' % s for s in SCHEMES) + """            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:scheme="content"/>
                <data android:scheme="file"/>
                <data android:mimeType="text/plain"/>
                <data android:mimeType="application/json"/>
                <data android:mimeType="application/x-openvpn-profile"/>
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:mimeType="text/plain"/>
            </intent-filter>
"""

KOTLIN = '''package %(pkg)s

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.Uri
import android.os.IBinder
import android.provider.OpenableColumns
import de.blinkt.openvpn.api.IOpenVPNAPIService
import de.blinkt.openvpn.api.IOpenVPNStatusCallback
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 1) Forwards links / shared text / opened files to Dart (lib/services/incoming.dart).
 * 2) Bridges lib/services/ovpn.dart to the OpenVPN for Android app through its remote API.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var ovpnChannel: MethodChannel? = null
    private var pending: Map<String, String>? = null

    private var ovpn: IOpenVPNAPIService? = null
    private var ovpnBound = false
    private var ovpnConfig: String? = null
    private val reqApi = 20311
    private val reqVpn = 20312

    private val ovpnStatus = object : IOpenVPNStatusCallback.Stub() {
        override fun newStatus(uuid: String?, state: String?, message: String?, level: String?) {
            sendOvpn(state ?: "", message ?: "")
        }
    }

    private val ovpnConn = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            ovpn = IOpenVPNAPIService.Stub.asInterface(service)
            try {
                ovpn?.registerStatusCallback(ovpnStatus)
            } catch (_: Exception) {
            }
            askApiPermission()
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            ovpn = null
            ovpnBound = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "alone/intent").also { ch ->
            ch.setMethodCallHandler { call, result ->
                if (call.method == "initial") {
                    result.success(pending)
                    pending = null
                } else {
                    result.notImplemented()
                }
            }
        }
        ovpnChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "alone/ovpn").also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "installed" -> result.success(ovpnInstalled())
                    "install" -> {
                        openOvpnStore()
                        result.success(null)
                    }
                    "start" -> {
                        ovpnConfig = call.argument<String>("config")
                        startOvpn()
                        result.success(null)
                    }
                    "stop" -> {
                        try {
                            ovpn?.disconnect()
                        } catch (_: Exception) {
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        pending = extract(intent)
    }

    // ---------------- OpenVPN for Android ----------------
    private fun ovpnInstalled(): Boolean = try {
        packageManager.getPackageInfo("de.blinkt.openvpn", 0)
        true
    } catch (_: Exception) {
        false
    }

    private fun openOvpnStore() {
        val uris = listOf("market://details?id=de.blinkt.openvpn", "https://f-droid.org/packages/de.blinkt.openvpn/", "https://play.google.com/store/apps/details?id=de.blinkt.openvpn")
        for (u in uris) {
            try {
                startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(u)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                return
            } catch (_: Exception) {
            }
        }
    }

    private fun sendOvpn(state: String, message: String) {
        runOnUiThread { ovpnChannel?.invokeMethod("status", mapOf("state" to state, "message" to message)) }
    }

    private fun startOvpn() {
        if (!ovpnInstalled()) {
            sendOvpn("NO_API", "OpenVPN for Android is not installed")
            return
        }
        if (ovpn != null) {
            askApiPermission()
            return
        }
        val i = Intent("de.blinkt.openvpn.api.IOpenVPNAPIService")
        i.setPackage("de.blinkt.openvpn")
        val ok = try {
            bindService(i, ovpnConn, Context.BIND_AUTO_CREATE)
        } catch (_: Exception) {
            false
        }
        ovpnBound = ok
        if (!ok) sendOvpn("NO_API", "could not bind to OpenVPN for Android")
    }

    private fun askApiPermission() {
        try {
            val i = ovpn!!.prepare(packageName)
            if (i != null) startActivityForResult(i, reqApi) else askVpnPermission()
        } catch (e: Exception) {
            sendOvpn("NO_API", e.message ?: "")
        }
    }

    private fun askVpnPermission() {
        try {
            val i = ovpn!!.prepareVPNService()
            if (i != null) startActivityForResult(i, reqVpn) else startNow()
        } catch (e: Exception) {
            sendOvpn("NO_API", e.message ?: "")
        }
    }

    private fun startNow() {
        val cfg = ovpnConfig ?: return
        ovpnConfig = null
        try {
            ovpn!!.startVPN(cfg)
        } catch (e: Exception) {
            sendOvpn("START_FAILED", e.message ?: "")
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            reqApi -> {
                if (resultCode == Activity.RESULT_OK) askVpnPermission() else sendOvpn("API_DENIED", "")
                return
            }
            reqVpn -> {
                if (resultCode == Activity.RESULT_OK) startNow() else sendOvpn("VPN_DENIED", "")
                return
            }
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        if (ovpnBound) {
            try {
                unbindService(ovpnConn)
            } catch (_: Exception) {
            }
            ovpnBound = false
        }
        super.onDestroy()
    }

    // ---------------- incoming links / text / files ----------------
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val m = extract(intent) ?: return
        val ch = channel
        if (ch != null) ch.invokeMethod("incoming", m) else pending = m
    }

    private fun extract(i: Intent?): Map<String, String>? {
        if (i == null) return null
        try {
            when (i.action) {
                Intent.ACTION_SEND -> {
                    val t = i.getStringExtra(Intent.EXTRA_TEXT)
                    if (!t.isNullOrBlank()) return mapOf("text" to t, "name" to "shared text")
                    @Suppress("DEPRECATION")
                    val u = i.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                    if (u != null) return readUri(u)
                }
                Intent.ACTION_VIEW -> {
                    val d = i.data ?: return null
                    val s = d.scheme ?: ""
                    return if (s == "content" || s == "file") readUri(d) else mapOf("text" to d.toString(), "name" to s)
                }
            }
        } catch (_: Exception) {
        }
        return null
    }

    private fun readUri(u: Uri): Map<String, String>? {
        var name = u.lastPathSegment ?: "file"
        try {
            contentResolver.query(u, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) c.getString(0)?.let { name = it }
            }
        } catch (_: Exception) {
        }
        val limit = 262144
        val buf = ByteArray(limit)
        var n = 0
        contentResolver.openInputStream(u)?.use { s ->
            while (n < limit) {
                val r = s.read(buf, n, limit - n)
                if (r <= 0) break
                n += r
            }
        } ?: return null
        return mapOf("text" to String(buf, 0, n, Charsets.UTF_8), "name" to name)
    }
}
'''


def fail(msg: str) -> None:
    print("patch_incoming_intents: " + msg, file=sys.stderr)
    sys.exit(1)


def patch_manifest() -> None:
    if not MANIFEST.is_file():
        fail("AndroidManifest.xml not found; run 'flutter create .' first.")
    x = MANIFEST.read_text(encoding="utf-8")
    if MARK in x:
        print("manifest already patched")
        return
    i = x.find("</activity>")
    if i < 0:
        fail("no </activity> in the manifest")
    MANIFEST.write_text(x[:i] + FILTERS + "        " + x[i:], encoding="utf-8")
    print("manifest: intent filters added")


def patch_kotlin() -> None:
    cands = sorted(Path("android/app/src/main").glob("**/MainActivity.kt"))
    if not cands:
        fail("MainActivity.kt not found")
    f = cands[0]
    src = f.read_text(encoding="utf-8")
    m = re.search(r"^package\s+([\w.]+)", src, re.M)
    if not m:
        fail("no package line in " + str(f))
    if "alone/ovpn" in src:
        print("MainActivity already patched")
        return
    f.write_text(KOTLIN % {"pkg": m.group(1)}, encoding="utf-8")
    print("MainActivity.kt rewritten:", f)


def patch_queries() -> None:
    x = MANIFEST.read_text(encoding="utf-8")
    if "de.blinkt.openvpn" in x:
        return
    pkg = '<package android:name="de.blinkt.openvpn"/>'
    if "<queries>" in x:
        x = x.replace("<queries>", "<queries>\n        " + pkg, 1)
    else:
        x = x.replace("<application", "<queries>\n        " + pkg + "\n    </queries>\n    <application", 1)
    MANIFEST.write_text(x, encoding="utf-8")
    print("manifest: package visibility for OpenVPN for Android added")


def copy_api_sources() -> None:
    import shutil

    src = Path("android_res/ovpn")
    if not src.is_dir():
        fail("android_res/ovpn not found (run from the repository root)")
    shutil.copytree(src / "aidl", Path("android/app/src/main/aidl"), dirs_exist_ok=True)
    shutil.copytree(src / "java", Path("android/app/src/main/java"), dirs_exist_ok=True)
    print("OpenVPN for Android remote API sources copied")


def enable_aidl() -> None:
    for name in ("build.gradle.kts", "build.gradle"):
        f = Path("android/app") / name
        if not f.is_file():
            continue
        g = f.read_text(encoding="utf-8")
        if "aidl" in g:
            print("aidl already enabled")
            return
        if name.endswith(".kts"):
            g2 = re.sub(r"(android\s*\{\n)", r"\1    buildFeatures {\n        aidl = true\n    }\n", g, count=1)
        else:
            g2 = re.sub(r"(android\s*\{\n)", r"\1    buildFeatures {\n        aidl true\n    }\n", g, count=1)
        if g2 == g:
            fail("could not find the android { block in " + str(f))
        f.write_text(g2, encoding="utf-8")
        print("aidl enabled in", f)
        return
    fail("no app build.gradle(.kts) found")


patch_manifest()
patch_queries()
copy_api_sources()
enable_aidl()
patch_kotlin()
