"""Keep the runner, XCTest plug-in and library bundle IDs exactly compatible with v1."""
import plistlib, sys, zipfile
root = "Payload/WebDriverAgentRunner-Runner.app/"
paths = ["Info.plist", "PlugIns/WebDriverAgentRunner.xctest/Info.plist", "PlugIns/WebDriverAgentRunner.xctest/Frameworks/WebDriverAgentLib.framework/Info.plist"]
with zipfile.ZipFile(sys.argv[1]) as old, zipfile.ZipFile(sys.argv[2]) as new:
    for path in paths:
        a = plistlib.loads(old.read(root + path))
        b = plistlib.loads(new.read(root + path))
        assert a["CFBundleIdentifier"] == b["CFBundleIdentifier"], path
        print(path, b["CFBundleIdentifier"])
