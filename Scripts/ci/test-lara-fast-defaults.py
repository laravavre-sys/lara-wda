"""Source-contract checks, not device performance tests."""
from pathlib import Path
root = Path(__file__).resolve().parents[2]
read = lambda p: (root / p).read_text()
config = read("WebDriverAgentLib/Utilities/FBConfiguration.m").split("- (void)resetSessionSettings")[1]
for expected in ["self.waitForIdleTimeout = 0.;", "self.animationCoolOffTimeout = 0.;", "self.shouldWaitForQuiescence = NO;", "self.useFirstMatch = YES;", "self.maxTypingFrequencyOverride = @60;", "FBSnapshotMaxDepthKey, @50"]:
    assert expected in config, expected
settings = read("WebDriverAgentLib/Utilities/FBSettingsHandler.m")
for name in ['@"shouldWaitForQuiescence"', '@"typingFrequency"', "FB_SETTING_WAIT_FOR_IDLE_TIMEOUT", "FB_SETTING_ANIMATION_COOL_OFF_TIMEOUT", "FB_SETTING_USE_FIRST_MATCH", "FB_SETTING_SNAPSHOT_MAX_DEPTH"]:
    assert settings.count("map[" + name + "]") == 2, name
commands = read("WebDriverAgentLib/Commands/FBElementCommands.m")
tap = commands.split("+ (id<FBResponsePayload>)handleTap:")[1].split("+ (id<FBResponsePayload>)handlePinch:")[0]
assert "[target tap]" not in tap
assert "fb_pressDragEventFromPoint" in tap and "synthesizeEventWithRecord" in tap
for path in ["/wda/tap", "/wda/dragfromtoforduration", "/wda/keys"]:
    assert f'POST:@"{path}"].withoutSession' in commands
touch = read("WebDriverAgentLib/Categories/XCUIApplication+FBTouchAction.m")
drag = touch.split("- (BOOL)fb_pressAtCoordinate:")[1].split("+ (XCSynthesizedEventRecord *)fb_pressDragEventFromPoint:")[0]
assert "fb_waitUntilStableWithTimeout" not in drag
typing = read("WebDriverAgentLib/Categories/XCUIElement+FBTyping.m")
assert "initForTextInput" in typing and "synthesizeEventWithRecord" in typing
print("Fast defaults, settings read/write, synthesized tap/drag/typing and route aliases verified")
