"""Choose the newest installed Xcode with an iPhoneOS SDK, without downloading tools."""
import glob, json, os, pathlib, re, subprocess
candidates = {}
for path in glob.glob("/Applications/Xcode*.app"):
    developer = str(pathlib.Path(path).resolve() / "Contents/Developer")
    if developer in candidates:
        continue
    env = dict(os.environ, DEVELOPER_DIR=developer)
    try:
        version = subprocess.check_output(["xcodebuild", "-version"], env=env, text=True).strip()
        sdk = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-version"], env=env, text=True).strip()
        match = re.search(r"Xcode (\d+(?:\.\d+)*)", version)
        if match:
            candidates[developer] = (tuple(map(int, match[1].split("."))), version, sdk)
    except subprocess.CalledProcessError:
        continue
if not candidates:
    raise SystemExit("No installed Xcode with an iOS device SDK")
developer, (_, version, sdk) = max(candidates.items(), key=lambda item: item[1][0])
with open(os.environ["GITHUB_ENV"], "a") as f:
    f.write(f"DEVELOPER_DIR={developer}\n")
pathlib.Path("xcode-version.txt").write_text(version + "\niPhoneOS SDK " + sdk + "\n")
pathlib.Path("build-metadata.json").write_text(json.dumps({"xcode": version, "iphoneOSSDK": sdk, "developerDir": developer, "commit": os.environ["GITHUB_SHA"]}, indent=2))
print(version, "SDK", sdk, developer)
