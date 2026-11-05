# UI refresh - 27 October 2026

Reference: the supplied WhatsApp video (60.54 seconds). Frames at 20 seconds (home) and 45 seconds (gameplay) were inspected. The video remains unchanged.

## Changes

- New transparent red open-top hero bus with a driver and cream seats, with the existing dynamic level and difficulty signs.
- City background, smaller home feature buttons, adjusted Play button position, illustrated supplies/spin/reward buttons.
- Native Blender-rendered rounded 3D game buses with smaller arrows, roof hatches, side windows, wheels, metallic trim, shadows and fixed camera depth. All 384 length/color/direction combinations are bundled as WebP and cached at startup. Source: tool/blender/render_reference_sprites.py and sprite_geometry.py. A canvas fallback is retained for missing artwork.
- Fixed premultiplied alpha handling in the sprite loader to prevent pale outlines, with opaque/transparent pixels skipped for faster loading.
- Glossy passengers, pink scenery, blossom trees, tilted parking bays, clearer level heading, compact blue booster cards.
- Purple Bus Supplies popup, blue Settings panel, illustrated loading screen and cyan progress bar.
- Sort and Shuffle display as Arrange and Jumble. Persistent booster keys, prices and actions are unchanged.

## Scope

Game rules, level generator, scoring/rewards, progress services, purchases, ad behavior, navigation, boarding and animation callbacks are unchanged. GameLayout still supplies drawing, routes and tap coordinates together. Procedural level arrangements and passenger counts stay those of this project; the reference is visual guidance, not a replacement of its rules or level data.

## Review artifacts

- Source backup before edits: D:/bus_game_review/source_before_ui.zip
- Before screenshots: D:/bus_game_review/before/
- After screenshots: D:/bus_game_review/after/ (small and tall phone sizes, home, gameplay, every popup, and reference level 139)
- Source of generated assets and final prompts: tool/art/ui_asset_prompts.md

## Validation

Use the existing suites:

    C:/dev/flutter/bin/flutter.bat analyze
    C:/dev/flutter/bin/flutter.bat test --dart-define=SHOT_DIR=D:/bus_game_review/after
    C:/dev/flutter/bin/flutter.bat test integration_test/app_test.dart -d emulator-5554

The layout suite additionally verifies both new home images and all 384 native bus sprites are in the bundle, and opens level 139 through Play on both phone sizes. The native integration suite retains all original scenarios; only the two displayed booster labels were updated.
