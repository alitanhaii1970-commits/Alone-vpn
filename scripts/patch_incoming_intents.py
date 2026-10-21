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

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Forwards links / shared text / opened files to Dart (lib/services/incoming.dart). */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, String>? = null

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
        pending = extract(intent)
    }

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
    if "alone/intent" in src:
        print("MainActivity already patched")
        return
    f.write_text(KOTLIN % {"pkg": m.group(1)}, encoding="utf-8")
    print("MainActivity.kt rewritten:", f)


patch_manifest()
patch_kotlin()
