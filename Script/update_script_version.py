import os
import re
import sys


root, script_name, crc, match_files, javascript_changed, marker = sys.argv[1:]
pattern = re.compile(rb"/" + re.escape(script_name.encode()) + rb"(?:-[0-9]+\.min)?\.js")
replacement = f"/{script_name}-{crc}.min.js".encode()
marker_time = os.path.getmtime(marker)

for directory, _, files in os.walk(root):
    for filename in files:
        if match_files == "*.html":
            matches = filename.endswith(".html")
        else:
            matches = filename == match_files
        if not matches:
            continue
        path = os.path.join(directory, filename)
        if javascript_changed != "TRUE" and os.path.getmtime(path) <= marker_time:
            continue
        with open(path, "rb") as handle:
            content = handle.read()
        updated = pattern.sub(replacement, content)
        if updated != content:
            with open(path, "wb") as handle:
                handle.write(updated)
