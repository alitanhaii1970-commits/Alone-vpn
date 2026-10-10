#!/usr/bin/env python3
"""Patch permission-result races in the pinned v2ray_box Android plugin.

This intentionally fails closed if the pinned upstream source shape changes. The
plugin is pinned in pubspec.yaml, so these replacements remain reviewable and
reproducible rather than silently modifying arbitrary dependency versions.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

RELATIVE_SOURCE = Path("android/src/main/kotlin/com/example/v2ray_box/V2rayBoxPlugin.kt")


def fail(message: str) -> "NoReturn":
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def locate_source() -> Path:
    roots = [Path(os.environ.get("PUB_CACHE", Path.home() / ".pub-cache"))]
    candidates: list[Path] = []
    for root in roots:
        if root.exists():
            candidates.extend(root.glob(f"git/*/{RELATIVE_SOURCE.as_posix()}"))
            candidates.extend(root.glob(f"hosted/*/*/*/{RELATIVE_SOURCE.as_posix()}"))
    unique = sorted({p.resolve() for p in candidates if p.is_file()})
    if len(unique) != 1:
        fail(
            "Expected exactly one cached v2ray_box Android plugin source, "
            f"found {len(unique)}. Run flutter pub get and verify the pinned dependency."
        )
    return unique[0]


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        fail(f"Expected one occurrence of {label}, found {count}; refusing an unsafe patch.")
    return source.replace(old, new, 1)


def patch(source: str) -> str:
    if "ALONE_VPN_PERMISSION_RACE_PATCH" in source:
        print("v2ray_box permission patch is already applied.")
        return source

    source = replace_once(
        source,
        "PluginRegistry.ActivityResultListener, ServiceConnection.Callback, CommandClient.Handler {",
        "PluginRegistry.ActivityResultListener, PluginRegistry.RequestPermissionsResultListener,\n"
        "    ServiceConnection.Callback, CommandClient.Handler {",
        "plugin permission-result interface",
    )
    source = replace_once(
        source,
        "    private val serviceActionToken = AtomicLong(0L)\n",
        "    private val serviceActionToken = AtomicLong(0L)\n"
        "    // ALONE_VPN_PERMISSION_RACE_PATCH: reject a delayed OS permission result after Cancel.\n"
        "    @Volatile private var pendingPermissionActionToken: Long? = null\n"
        "    @Volatile private var pendingPermissionPrompt = false\n",
        "service action token field",
    )

    # Register the Android 13+ runtime-permission callback alongside activity results.
    source = replace_once(
        source,
        "        binding.addActivityResultListener(this)\n        connection = ServiceConnection(activity!!, this)",
        "        binding.addActivityResultListener(this)\n"
        "        binding.addRequestPermissionsResultListener(this)\n"
        "        connection = ServiceConnection(activity!!, this)",
        "initial activity listener registration",
    )
    source = replace_once(
        source,
        "        binding.addActivityResultListener(this)\n    }\n\n    override fun onDetachedFromActivity()",
        "        binding.addActivityResultListener(this)\n"
        "        binding.addRequestPermissionsResultListener(this)\n"
        "    }\n\n    override fun onDetachedFromActivity()",
        "reattached activity listener registration",
    )

    # Pass the native action token through all three service-start entry points
    # that are initiated by a config connection/restart.
    for log_text in (
        'Log.d(TAG, "start cancelled after stop/wait")',
        'Log.d(TAG, "restart cancelled after stop/wait")',
        'Log.d(TAG, "start_with_json cancelled after stop/wait")',
    ):
        old = f"{log_text}\n                            success(true)\n                            return@runCatching\n                        }}\n                        startService()\n                        success(true)"
        new = f"{log_text}\n                            success(true)\n                            return@runCatching\n                        }}\n                        startService(actionToken)\n                        success(true)"
        source = replace_once(source, old, new, f"token-aware service start ({log_text})")

    old_start_service = '''    private fun startService() {
        if (!checkNotificationPermission()) {
            grantNotificationPermission()
            return
        }
        scope.launch(Dispatchers.IO) {
            if (Settings.rebuildServiceMode()) {
                connection?.reconnect()
            }
            if (Settings.serviceMode == ServiceMode.VPN) {
                if (prepareVpn()) {
                    Log.d(TAG, "VPN permission required")
                    return@launch
                }
            }
            applicationContext?.let { BoxService.start(it) }
        }
    }'''
    new_start_service = '''    private fun startService(actionToken: Long? = null) {
        if (actionToken != null && !isServiceActionCurrent(actionToken)) {
            Log.d(TAG, "Ignoring stale service start before permission check")
            return
        }
        if (!checkNotificationPermission()) {
            pendingPermissionActionToken = actionToken
            pendingPermissionPrompt = true
            grantNotificationPermission()
            return
        }
        scope.launch(Dispatchers.IO) {
            if (actionToken != null && !isServiceActionCurrent(actionToken)) return@launch
            if (Settings.rebuildServiceMode()) {
                connection?.reconnect()
            }
            if (actionToken != null && !isServiceActionCurrent(actionToken)) return@launch
            if (Settings.serviceMode == ServiceMode.VPN) {
                // Set these before prepareVpn(): ActivityResult can be delivered as
                // soon as the OS consent sheet is dismissed.
                pendingPermissionActionToken = actionToken
                pendingPermissionPrompt = true
                if (prepareVpn()) {
                    Log.d(TAG, "VPN permission required or request handled")
                    return@launch
                }
                pendingPermissionActionToken = null
                pendingPermissionPrompt = false
            }
            if (actionToken != null && !isServiceActionCurrent(actionToken)) return@launch
            applicationContext?.let { BoxService.start(it) }
        }
    }'''
    source = replace_once(source, old_start_service, new_start_service, "startService permission flow")

    old_prepare_vpn = '''    private suspend fun prepareVpn() = withContext(Dispatchers.Main) {
        val act = activity ?: return@withContext false
        try {
            val intent = VpnService.prepare(act)
            if (intent != null) {
                act.startActivityForResult(intent, VPN_PERMISSION_REQUEST_CODE)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            onServiceAlert(Alert.RequestVPNPermission, e.message)
            false
        }
    }'''
    new_prepare_vpn = '''    private suspend fun prepareVpn() = withContext(Dispatchers.Main) {
        val act = activity ?: run {
            pendingPermissionPrompt = false
            pendingPermissionActionToken = null
            onServiceAlert(Alert.RequestVPNPermission, "Activity not available")
            return@withContext true
        }
        try {
            val intent = VpnService.prepare(act)
            if (intent != null) {
                act.startActivityForResult(intent, VPN_PERMISSION_REQUEST_CODE)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            pendingPermissionPrompt = false
            pendingPermissionActionToken = null
            onServiceAlert(Alert.RequestVPNPermission, e.message)
            true
        }
    }'''
    source = replace_once(source, old_prepare_vpn, new_prepare_vpn, "prepareVpn error handling")

    old_grant_notification = '''    private fun grantNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity?.let {
                ActivityCompat.requestPermissions(
                    it,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    NOTIFICATION_PERMISSION_REQUEST_CODE
                )
            }
        }
    }'''
    new_grant_notification = '''    private fun grantNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val act = activity
        if (act == null) {
            pendingPermissionPrompt = false
            pendingPermissionActionToken = null
            onServiceAlert(Alert.RequestNotificationPermission, "Activity not available")
            return
        }
        ActivityCompat.requestPermissions(
            act,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE
        )
    }'''
    source = replace_once(
        source,
        old_grant_notification,
        new_grant_notification,
        "notification permission request handling",
    )

    old_activity_result = '''    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                startService()
            } else {
                onServiceAlert(Alert.RequestVPNPermission, null)
            }
            return true
        } else if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                startService()
            } else {
                onServiceAlert(Alert.RequestNotificationPermission, null)
            }
            return true
        }
        return false
    }'''
    new_activity_result = '''    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            val tracked = pendingPermissionPrompt
            val token = pendingPermissionActionToken
            pendingPermissionPrompt = false
            pendingPermissionActionToken = null
            if (tracked && token != null && !isServiceActionCurrent(token)) {
                Log.d(TAG, "Ignoring stale VPN permission result after cancellation")
                return true
            }
            if (resultCode == Activity.RESULT_OK) {
                startService(if (tracked) token else null)
            } else {
                onServiceAlert(Alert.RequestVPNPermission, null)
            }
            return true
        } else if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            // Kept for hosts that dispatch a notification result as an activity result.
            if (resultCode == Activity.RESULT_OK) {
                startService()
            } else {
                onServiceAlert(Alert.RequestNotificationPermission, null)
            }
            return true
        }
        return false
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) return false
        val tracked = pendingPermissionPrompt
        val token = pendingPermissionActionToken
        pendingPermissionPrompt = false
        pendingPermissionActionToken = null
        if (tracked && token != null && !isServiceActionCurrent(token)) {
            Log.d(TAG, "Ignoring stale notification permission result after cancellation")
            return true
        }
        if (grantResults.any { it == PackageManager.PERMISSION_GRANTED }) {
            startService(if (tracked) token else null)
        } else {
            onServiceAlert(Alert.RequestNotificationPermission, null)
        }
        return true
    }'''
    source = replace_once(source, old_activity_result, new_activity_result, "activity permission-result handlers")
    return source


def main() -> None:
    source_path = locate_source()
    original = source_path.read_text(encoding="utf-8")
    modified = patch(original)
    if modified != original:
        source_path.write_text(modified, encoding="utf-8")
        print(f"Patched native permission flow: {source_path}")
    else:
        print(f"Native permission flow already ready: {source_path}")


if __name__ == "__main__":
    main()
