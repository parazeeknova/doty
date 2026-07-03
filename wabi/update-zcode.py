#!/usr/bin/env python3
import urllib.request
import re
import sys
import subprocess
import os

DESKTOP_NIX = os.path.join(os.path.dirname(os.path.dirname(__file__)), "modules/hosts/apostrophe/packages/desktop.nix")

def get_latest_zcode_version():
    url = "https://zcode.z.ai/en"
    try:
        req = urllib.request.Request(
            url, 
            headers={'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'}
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            html = response.read().decode('utf-8')
    except Exception as e:
        print(f"Error fetching latest version from {url}: {e}")
        return None

    # Find matches like: https://cdn-zcode.z.ai/zcode/electron/releases/3.2.5/ZCode-3.2.5-linux-x64.AppImage
    pattern = r'https://cdn-zcode\.z\.ai/zcode/electron/releases/(\d+\.\d+\.\d+)/ZCode-\1-linux-x64\.AppImage'
    versions = re.findall(pattern, html)
    if not versions:
        print("Could not find any ZCode release versions in page.")
        return None

    # Sort versions semantically
    def semver_key(v):
        return [int(x) for x in v.split('.')]

    latest_version = max(set(versions), key=semver_key)
    return latest_version

def get_current_zcode_info():
    if not os.path.exists(DESKTOP_NIX):
        print(f"Error: {DESKTOP_NIX} not found.")
        return None, None

    with open(DESKTOP_NIX, 'r') as f:
        content = f.read()

    # Search for ZCode block
    zcode_match = re.search(r'# -- ZCode --.*?pname\s*=\s*"zcode";\s*version\s*=\s*"([^"]+)";.*?sha256\s*=\s*"([^"]+)";', content, re.DOTALL)
    if not zcode_match:
        print("Could not locate ZCode block in desktop.nix.")
        return None, None

    return zcode_match.group(1), zcode_match.group(2)

def update_zcode_in_file(new_version, new_hash):
    with open(DESKTOP_NIX, 'r') as f:
        content = f.read()

    # Regex to find the version, url, and sha256 within the ZCode block
    pattern = re.compile(
        r'(# -- ZCode --.*?pname\s*=\s*"zcode";\s*version\s*=\s*")[^"]+("\s*;\s*src\s*=\s*fetchurl\s*\{\s*url\s*=\s*")[^"]+("\s*;\s*sha256\s*=\s*")[^"]+("\s*;\s*\};)',
        re.DOTALL
    )

    new_url = f"https://cdn-zcode.z.ai/zcode/electron/releases/{new_version}/ZCode-{new_version}-linux-x64.AppImage"

    def repl(m):
        return f"{m.group(1)}{new_version}{m.group(2)}{new_url}{m.group(3)}{new_hash}{m.group(4)}"

    new_content, count = pattern.subn(repl, content)
    if count == 0:
        print("Failed to replace ZCode block in desktop.nix.")
        return False

    with open(DESKTOP_NIX, 'w') as f:
        f.write(new_content)

    print(f"Successfully updated desktop.nix to version {new_version} with hash {new_hash}")
    return True

def main():
    print("Checking for ZCode updates...")
    latest_version = get_latest_zcode_version()
    if not latest_version:
        sys.exit(1)

    current_version, current_hash = get_current_zcode_info()
    if not current_version:
        sys.exit(1)

    print(f"Current local version: {current_version}")
    print(f"Latest online version: {latest_version}")

    if latest_version == current_version:
        print("ZCode is already up to date!")
        sys.exit(0)

    print(f"New version {latest_version} available! Fetching new hash...")
    new_url = f"https://cdn-zcode.z.ai/zcode/electron/releases/{latest_version}/ZCode-{latest_version}-linux-x64.AppImage"
    
    try:
        # Run nix-prefetch-url to get the new sha256 hash in base32
        result = subprocess.run(["nix-prefetch-url", new_url], capture_output=True, text=True, check=True)
        new_hash = result.stdout.strip()
        if not new_hash:
            print("Failed to get hash from nix-prefetch-url.")
            sys.exit(1)
        print(f"Fetched hash: {new_hash}")
    except Exception as e:
        print(f"Error running nix-prefetch-url: {e}")
        sys.exit(1)

    if update_zcode_in_file(latest_version, new_hash):
        print("Update complete!")
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
