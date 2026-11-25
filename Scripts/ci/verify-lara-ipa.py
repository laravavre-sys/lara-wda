"""Validate the actual release archive, not merely the packaging script."""
import plistlib
import sys
import zipfile

root = "Payload/WebDriverAgentRunner-Runner.app/"
with zipfile.ZipFile(sys.argv[1]) as ipa:
    names = ipa.namelist()
    assert ipa.testzip() is None, "Corrupt ZIP entry"
    assert not any(n.startswith(root + "Frameworks/") for n in names), "Bundled XCTest dependencies"
    for suffix in ("Info.plist", "PlugIns/WebDriverAgentRunner.xctest/Info.plist"):
        info = plistlib.loads(ipa.read(root + suffix))
        assert info["NSPhotoLibraryAddUsageDescription"] == "Lara Studio ukladá fotky a videá do Galérie"
        assert info["UIFileSharingEnabled"] is True
    lib = root + "PlugIns/WebDriverAgentRunner.xctest/Frameworks/WebDriverAgentLib.framework/WebDriverAgentLib"
    binary = ipa.read(lib)
    assert b"FBMediaCommands" in binary, "Media handler missing"
    assert b"/wda/saveToPhotos" in binary, "Route missing"
    assert b"Photos.framework/Photos" in binary, "Photos framework not linked"
print("IPA structure, privacy keys, handler, route and Photos linkage verified")
