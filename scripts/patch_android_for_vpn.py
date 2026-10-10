#!/usr/bin/env python3
"""Idempotently prepare a freshly generated Flutter Android project for v2ray_box."""
from __future__ import annotations

import glob
import os
import re
import shutil
import sys
from pathlib import Path

MANIFEST_PATH = Path("android/app/src/main/AndroidManifest.xml")
GRADLE_KTS_PATH = Path("android/app/build.gradle.kts")
GRADLE_GROOVY_PATH = Path("android/app/build.gradle")

PERMISSIONS = {
    "android.permission.INTERNET": '    <uses-permission android:name="android.permission.INTERNET" />',
    "android.permission.FOREGROUND_SERVICE": '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />',
    "android.permission.FOREGROUND_SERVICE_SPECIAL_USE": '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />',
    "android.permission.POST_NOTIFICATIONS": '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
    "android.permission.RECEIVE_BOOT_COMPLETED": '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />',
    "android.permission.CHANGE_NETWORK_STATE": '    <uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />',
    "android.permission.ACCESS_NETWORK_STATE": '    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />',
    "android.permission.QUERY_ALL_PACKAGES": '''    <uses-permission
        android:name="android.permission.QUERY_ALL_PACKAGES"
        tools:ignore="QueryAllPackagesPermission" />''',
}

SERVICES = {
    "com.example.v2ray_box.bg.VPNService": '''    <service
        android:name="com.example.v2ray_box.bg.VPNService"
        android:exported="false"
        android:foregroundServiceType="specialUse"
        android:permission="android.permission.BIND_VPN_SERVICE">
        <intent-filter>
            <action android:name="android.net.VpnService" />
        </intent-filter>
        <property
            android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
            android:value="vpn" />
    </service>''',
    "com.example.v2ray_box.bg.ProxyService": '''    <service
        android:name="com.example.v2ray_box.bg.ProxyService"
        android:exported="false"
        android:foregroundServiceType="specialUse">
        <property
            android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
            android:value="proxy" />
    </service>''',
}


def fail(message: str) -> "NoReturn":
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def patch_manifest() -> None:
    if not MANIFEST_PATH.is_file():
        fail(f"{MANIFEST_PATH} not found. Run 'flutter create .' first.")

    manifest = MANIFEST_PATH.read_text(encoding="utf-8")
    manifest = re.sub(r'android:label="[^"]*"', 'android:label="ALONE VPN"', manifest, count=1)

    if "xmlns:tools=" not in manifest:
        manifest, n = re.subn(
            r'(<manifest\s+xmlns:android="[^"]+")',
            r'\1 xmlns:tools="http://schemas.android.com/tools"',
            manifest,
            count=1,
        )
        if n != 1:
            fail("Could not add tools namespace to AndroidManifest.xml.")

    # Add only missing permissions so rerunning this script remains safe.
    missing_permissions = [
        xml for name, xml in PERMISSIONS.items()
        if f'android:name="{name}"' not in manifest
    ]
    if missing_permissions:
        marker = re.search(r'^\s*<application\b', manifest, flags=re.MULTILINE)
        if marker is None:
            fail("Could not find <application> in AndroidManifest.xml.")
        insert_at = marker.start()
        manifest = manifest[:insert_at] + "\n".join(missing_permissions) + "\n\n" + manifest[insert_at:]

    app_match = re.search(r'<application\b[^>]*>', manifest, flags=re.DOTALL)
    if app_match is None:
        fail("Could not parse the <application> element.")
    app_tag = app_match.group(0)
    if "android:usesCleartextTraffic=" not in app_tag:
        app_tag = app_tag[:-1] + '\n        android:usesCleartextTraffic="true">'
    if "tools:targetApi=" not in app_tag:
        app_tag = app_tag[:-1] + '\n        tools:targetApi="31">'
    manifest = manifest[:app_match.start()] + app_tag + manifest[app_match.end():]

    # Insert each service only if it is missing.
    missing_services = [
        xml for name, xml in SERVICES.items()
        if f'android:name="{name}"' not in manifest
    ]
    if missing_services:
        marker = manifest.lower().rfind("</application>")
        if marker < 0:
            fail("Could not find </application> in AndroidManifest.xml.")
        block = "\n\n".join(missing_services) + "\n    "
        manifest = manifest[:marker] + block + manifest[marker:]

    MANIFEST_PATH.write_text(manifest, encoding="utf-8")
    print("AndroidManifest.xml patched (safe to rerun).")


def patch_gradle() -> None:
    gradle_path = GRADLE_KTS_PATH if GRADLE_KTS_PATH.is_file() else GRADLE_GROOVY_PATH
    if not gradle_path.is_file():
        fail("Neither build.gradle.kts nor build.gradle exists; run 'flutter create .' first.")

    gradle = gradle_path.read_text(encoding="utf-8")
    is_kts = gradle_path == GRADLE_KTS_PATH

    # Keep this idempotent: the workflow may be rerun against a reused checkout.
    if "multiDexEnabled" not in gradle:
        if is_kts:
            gradle, n = re.subn(r'(defaultConfig\s*\{)', r'\1\n        multiDexEnabled = true\n        ', gradle, count=1)
        else:
            gradle, n = re.subn(r'(defaultConfig\s*\{)', r'\1\n        multiDexEnabled true\n        ', gradle, count=1)
        if n != 1:
            fail("Could not find defaultConfig block in Gradle file.")

    if "useLegacyPackaging" not in gradle:
        if is_kts:
            addition = '''\n    packaging {\n        jniLibs {\n            useLegacyPackaging = true\n        }\n    }'''
        else:
            addition = '''\n    packagingOptions {\n        jniLibs {\n            useLegacyPackaging = true\n        }\n    }'''
        gradle, n = re.subn(r'(android\s*\{)', lambda m: m.group(1) + addition, gradle, count=1)
        if n != 1:
            fail("Could not find android block in Gradle file.")

    if "fileTree" not in gradle or "*.aar" not in gradle:
        dep_line = (
            '    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar")))\n'
            if is_kts else
            "    implementation fileTree(dir: 'libs', include: ['*.aar'])\n"
        )
        # Fix the Kotlin DSL's closing parentheses explicitly; keep the string clear.
        if is_kts:
            dep_line = '    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar"))))\n'
        if re.search(r'^[ \t]*dependencies\s*\{', gradle, flags=re.MULTILINE):
            gradle = re.sub(r'(^[ \t]*dependencies\s*\{)', lambda m: m.group(1) + "\n" + dep_line.rstrip(), gradle, count=1, flags=re.MULTILINE)
        else:
            gradle += "\n\ndependencies {\n" + dep_line + "}\n"

    gradle_path.write_text(gradle, encoding="utf-8")
    print(f"{gradle_path} patched (safe to rerun).")


def copy_icons() -> None:
    if not Path("android_res").is_dir():
        print("No android_res icon directory; keeping the generated Flutter icon.")
        return
    for source_dir in glob.glob("android_res/mipmap-*"):
        icon = Path(source_dir) / "ic_launcher.png"
        if not icon.is_file():
            continue
        destination = Path("android/app/src/main/res") / Path(source_dir).name
        destination.mkdir(parents=True, exist_ok=True)
        shutil.copy2(icon, destination / icon.name)
    print("Launcher icon copied.")


if __name__ == "__main__":
    patch_manifest()
    copy_icons()
    patch_gradle()
