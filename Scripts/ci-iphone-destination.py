#!/usr/bin/env python3
"""Print an xcodebuild -destination for an available iPhone simulator."""
import re
import subprocess
import sys

out = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available"], text=True)
phones = re.findall(r"^\s+(iPhone [^(]+?) \(([0-9A-Fa-f-]{36})\)", out, re.M)
if not phones:
    sys.exit("No iPhone simulator available")
for name, udid in phones:
    if name.strip() == "iPhone 16":
        print(f"platform=iOS Simulator,id={udid}")
        sys.exit(0)
for name, udid in phones:
    if name.startswith("iPhone 16"):
        print(f"platform=iOS Simulator,id={udid}")
        sys.exit(0)
print(f"platform=iOS Simulator,id={phones[0][1]}")
