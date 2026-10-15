#!/usr/bin/env python3
"""Sign the release build with the persistent ALONE keystore (provided via env vars).

Does nothing when ALONE_KEYSTORE is not set, so the build falls back to Flutter's default.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

KTS = Path("android/app/build.gradle.kts")
GROOVY = Path("android/app/build.gradle")

if not os.environ.get("ALONE_KEYSTORE") or not Path(os.environ["ALONE_KEYSTORE"]).is_file():
    print("No release keystore configured; leaving signing untouched.")
    sys.exit(0)

path = KTS if KTS.is_file() else GROOVY
if not path.is_file():
    sys.exit("build.gradle(.kts) not found; run 'flutter create .' first.")
src = path.read_text(encoding="utf-8")
if "ALONE_KEYSTORE" in src:
    print("already patched")
    sys.exit(0)

if path == KTS:
    block = '''
    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("ALONE_KEYSTORE"))
            storePassword = System.getenv("ALONE_STORE_PASS")
            keyAlias = "alone"
            keyPassword = System.getenv("ALONE_STORE_PASS")
        }
    }
'''
    src, n = re.subn(r'signingConfigs\.getByName\("debug"\)', 'signingConfigs.getByName("release")', src)
else:
    block = '''
    signingConfigs {
        release {
            storeFile file(System.getenv("ALONE_KEYSTORE"))
            storePassword System.getenv("ALONE_STORE_PASS")
            keyAlias "alone"
            keyPassword System.getenv("ALONE_STORE_PASS")
        }
    }
'''
    src, n = re.subn(r'signingConfigs\.debug', 'signingConfigs.release', src)
if n < 1:
    sys.exit("release buildType signingConfig line not found in " + str(path))

src, m = re.subn(r'(\n\s*buildTypes\s*\{)', lambda mm: block + mm.group(1), src, count=1)
if m != 1:
    sys.exit("buildTypes block not found in " + str(path))
path.write_text(src, encoding="utf-8")
print(f"{path} patched for release signing")
