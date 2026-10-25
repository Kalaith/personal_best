# Title image

Generated with the built-in imagegen tool on 26 October 2026. The Alchemy Tower
example supplied by the owner informed the level of painterly detail; each scene
was composed for this game's setting and live menu. Text remains native Godot UI.

Asset: `assets/art/ui/title_screen.png`. Original artwork remains preserved.

## Generation prompt

Use case: stylized-concept. Create original polished illustrated game title background for Personal Best, landscape 16:10 1920x1200. Warm human-scale backyard coaching gym in a timber shed with wide doors opening onto garden and a park jogging path in soft morning light. RIGHT half shows a supportive trainer with clipboard encouraging two clearly different adult clients: Jordan a lean brown-skinned 20-year-old man with short black hair, blue athletic shirt and dark shorts, and Peg a stockier older woman with silver bob hair, rose pink athletic top and plum shorts. They are preparing for a marathon, chatting and warming up naturally, not bodybuilding poses. Mats, dumbbells, skipping rope and step box, worn wood, hanging towel and water bottle; modest equipment, welcoming inclusive setting. Hand-painted warm 2D illustration, expressive faces, tactile detailed environment, cinematic golden light, muted terracotta, sage and honey wood palette. LEFT 42 percent is shaded shed wall and softly lit equipment providing dark quiet low-detail area for live title and menu. No text, numbers, letters, logos, UI, borders or watermarks. Save image locally and return path.

## Integration and verification

- The title uses this project-local image with aspect-preserving cover scaling.
- Text, focus, settings, saves and start actions remain native Godot UI.
- Godot 4.7.2 headless editor import completed successfully.
- Silent automated windowed capture ran on the OpenGL Compatibility renderer;
  the rendered title was visually inspected at one fixed size.
- Capture: `docs/verification/01_title.png`. Reproduce with
  `Godot --path . --audio-driver Dummy --script res://tools/capture_title.gd`.
- `-- --details` also captures `title_new_game.png`; the expanded creator or
  save-replacement confirmation was inspected without starting over or saving.
- Capture exited with code 0 and reported ObjectDB/resource cleanup warnings
  during shutdown. These remain unresolved; title rendering succeeded.
- No gameplay simulation suite, export, browser/touch pass or human playtest
  was run for this title-art change. Nothing was pushed or published.
