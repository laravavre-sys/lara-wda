# Lara WDA v2 fast input

Session reset now defaults to waitForIdleTimeout=0, animationCoolOffTimeout=0, shouldWaitForQuiescence=false, useFirstMatch=true, snapshotMaxDepth=50 and maxTypingFrequency=60. POST /session/:id/appium/settings reads/writes all six; typingFrequency is an alias of maxTypingFrequency. Use just one spelling per request. Settings reset for each new session. To opt back into XCTest quiescence, set shouldWaitForQuiescence=true AND a positive waitForIdleTimeout.

Coordinate tap resolves its target once and uses the existing upstream XCPointerEventPath/XCSynthesizedEventRecord builder (50 ms touch), followed by event-synthesis completion. It no longer calls native XCTest tap. The upstream synthesized drag preserves press duration and velocity semantics but no longer waits for animations after dispatch. /wda/keys already used one synthesized text event upstream; it is preserved and defaults to 60 chars/s, with frequency override and input validation. Default quiescence is bypassed on both XCTest selector variants, including pre-event.

Tap, dragfromtoforduration and keys have sessionless aliases in addition to /session/:id paths. Coordinates remain screen points, not screenshot pixels; existing element-relative coordinate resolution and display/orientation metadata are retained. Directional /wda/swipe now synthesizes a path from the resolved target center (or requested coordinate) toward the requested edge, up to 40% of target bounds, clamped within them; default velocity is 500 points/s and a positive explicit velocity is supported. Native /element/:id/click still uses the upstream implementation with disabled default quiescence; W3C actions retain configurable animationCoolOffTimeout.

The Photos handler and project linkage are byte-for-byte unchanged from v1. CI validates the actual IPA privacy entries, Photos symbols, and all three bundle identifiers against the downloaded v1 asset. Top-level XCTest frameworks are excluded exactly as in v1; the plug-in's WDA library stays packaged.

Build uses a standard public-repository macos-26 runner, choosing the newest installed Xcode that includes an iPhoneOS SDK (no tool download or paid service). The built-in ephemeral GitHub workflow token publishes the release; no user key/secret is added. Xcode/SDK metadata and SHA256 are attached to the release. Published assets are not overwritten.

## Device acceptance (not yet measured)
- Re-sign/install v2, start a session with no performance capabilities; GET settings must show defaults.
- Time at least 30 coordinate taps on a safe test UI, in portrait and both landscape orientations; report median and p95 end-to-end latency. Goal: <1 s, not a guarantee.
- Focus a test text field and POST one 100-character caption; goal <2 s. At 60 chars/s event duration alone is about 1.67 s. Test emoji, accented letters, newline, delete and repeated batches.
- Verify drag endpoints, short and long press durations, W3C swipes, and errors on invalid input.
- Toggle settings, verify GET reflects them, and create a second session to check reset.
- Regression-test saveToPhotos for JPG/PNG/HEIC/MP4/MOV, permission grant/denial, file cleanup and error response shape.
- Target requests must await visible UI state where necessary: removing idle waits does not make an app transition instantaneous.
