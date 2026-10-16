#!/usr/bin/env python3
"""Push small result files (reports, logs, screenshots) to the ci-logs branch via the contents API.

usage: publish_ci_files.py <prefix> <file> [<file> ...]
"""
import base64, io, json, os, sys, urllib.request, urllib.error

prefix, files = sys.argv[1], sys.argv[2:]
repo, token = os.environ["GITHUB_REPOSITORY"], os.environ["GH_TOKEN"]
for f in files:
    if not os.path.isfile(f):
        continue
    data = open(f, "rb").read()
    if f.lower().endswith(".png"):
        try:
            from PIL import Image
            im = Image.open(io.BytesIO(data)); im.thumbnail((540, 1200))
            buf = io.BytesIO(); im.save(buf, "PNG", optimize=True); data = buf.getvalue()
        except Exception as e:
            print("resize skipped:", e)
    if len(data) > 700_000 and not f.lower().endswith(".png"):
        data = data[-700_000:]
    path = f"ci-logs/{prefix}-{os.path.basename(f)}"
    body = json.dumps({"message": f"ci: {path}", "branch": "ci-logs",
                       "content": base64.b64encode(data).decode()}).encode()
    req = urllib.request.Request(f"https://api.github.com/repos/{repo}/contents/{path}", data=body, method="PUT",
        headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"})
    try:
        urllib.request.urlopen(req, timeout=60).read(); print("published", path)
    except urllib.error.HTTPError as e:
        print("could not publish", path, e.code, e.read()[:200])
