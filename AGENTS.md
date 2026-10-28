# Personal Best project guidance

Personal Best is a 2D coaching game: the player is a personal trainer working out of a backyard shed, preparing clients for a marathon. `docs/GAME_DESIGN.md` is the design document; `docs/DECISIONS.md` records every choice made where the design was silent or had to be adapted, and is the list to review after playtesting. Read both before changing rules. The shared standards at the end of this file apply as well as everything here.

## Product invariants

- The coached session is the heart of the game. Every coaching minigame uses the one sliding bar (`scripts/ui/slide_bar.gd`); a new minigame changes what the zones mean, not the input.
- Pushing harder is not always right. Holding back must stay a winning decision whenever the client signals red, and clients always show a readable signal (meter colour, face and a body-language line) before a push or hold-back choice.
- Every result explains itself: session wrap-up, mini goals and the marathon say what caused the outcome in plain words. Do not add a number the player cannot trace back to a choice.
- Session fees are never reduced by a missed goal; only bonuses are lost.
- This is a fitness game: screens show before they tell. Prefer a ring, bar, radar, icon or time line to a sentence (`scripts/ui/charts.gd`), keep the full explanation in a tooltip, and spell out in words only what went wrong. Do not bring paragraphs back.
- Age, gender and body size never set ability on their own. Starting attributes come from the intake assessment shown to the player.

## Project engineering

- **Compatibility** renderer, 1280×800 base resolution with `canvas_items` stretch. All UI is built in code from `scripts/ui/style.gd` (the toolkit `UiKit` and one warm palette); figures and the gym are drawn with `_draw`.
- The shared WebHatchery Godot toolkit (`../godot_toolkit`) is linked in as `res://addons/hatchery/` by `..\godot_toolkit\tools\Link-Toolkit.ps1 -ProjectDir .` (a junction, ignored by Git). Personal Best uses its balance facade, JSON and data-rule helpers, `Det` for seeded picks, `JsonSave`, the screen switcher, and the UI kit. Change toolkit code in `../godot_toolkit` under its own AGENTS.md.
- Rules live in `scripts/core/` (no scene tree, all randomness from seeded generators forked per week and client). Screens live in `scripts/ui/`; they read state and call core functions, never change state any other way.
- Balance numbers live in `data/balance.json`; clients, exercises and the shop live in `data/clients.json`, `data/exercises.json` and `data/shop.json` with stable ids. `scripts/core/catalog.gd` validates all of them at startup.
- The campaign is saved at the weekly planner only (`user://personal_best_save.json`). A purchase is refused if saving it fails.

## Project checks

- `tools/season_sim.gd` plays whole seasons headlessly with scripted coaching (good, average and careless) and prints readiness at each milestone and the event results. Run it after a balance change:
  `& "C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tools/season_sim.gd`
- `tools/parse_all.gd` compiles every script (`--headless --script res://tools/parse_all.gd`), and the parse/import check is `--headless --editor --quit`.
- `tools/capture.gd` drives the real game through every screen and saves PNGs (needs a window, not `--headless`): `--path . --script res://tools/capture.gd`; shots are written flat to `docs/verification/`.
- Verify anything visual by running the game (`Run.ps1`).

## Commit voice

Commit lines describe what changed as it is felt in the shed and by the clients.

```
Peg now tells you when her legs are sore if you ask the right question (check-in)
```

## Publishing

Publishing (`publish.ps1`, `publish-itch.ps1`) requires separate authorisation. `.\publish.ps1 -BuildOnly` (export only, no deploy) is fine for verification. Both are the shared templates from `../godot_toolkit/templates/`. Exports need the **standard (non-mono)** Godot 4.7.2 console editor; `Run.ps1` uses the installed mono editor for playing.

## Shared WebHatchery Godot standards

Identical in every WebHatchery Godot project's AGENTS.md; change all together. Project-specific rules go above.

### Working

- Stay inside this project unless the user broadens the task; preserve user changes; never overwrite original art.
- No installing/upgrading Godot, export templates, tools, plugins or GDExtensions without approval; prefer built-in features.

### Code

- Godot **4.7.2** GDScript, statically typed everywhere (variables, parameters, returns). `const X = preload("res://...")`. Tabs, LF, UTF-8, final newline.
- Simulation/rules code never touches the scene tree, `Time`, `OS` or global `randi()`/`randf()`; randomness comes from an owned `RandomNumberGenerator` (same seed, same result). Presentation reads state and sends commands, nothing else.
- Balance and catalogs (upgrades, parts, miracles, blocks, ...) live in JSON under `data/` with stable ids (and `schema_version` where present), validated at startup, holding only implemented effects. Missing or mistyped data fails fast and is reported; never default silently in code.
- Persistent state lives under `user://` with schema validation, staged writes and backup recovery. A failed save never loses progress or spends anything.

### Verification

- No `tests/` directory, frameworks or addons. Any automated checks are headless scripts in `tools/`, kept out of the export.
- Checks don't gate commits. At a major feature or milestone, run all checks (plus `--headless --editor --quit`) and fix findings.
- Headless checks can't verify visuals, audio, input or feel: run the game and look. State plainly what was and wasn't checked.

### Verification images

- Only `docs/verification/` (flat; keep its `.gdignore` and `docs/`'s). Reference art: `docs/reference/` or `docs/art/`.
- Capture via the toolkit's `testing/capture_runner.gd` or `testing/capture_paths.gd` (`CapturePaths.file(label)`); never pass an output directory or write elsewhere (`builds/`, `exports/`, OS temp, `user://`).
- Stable names `<label>.png`: no subfolders, timestamps, run/revision/size suffixes, `-final`/`-fix` variants or backups. Recapturing a screen or state overwrites; new labels only for genuinely new ones.
- One window size and UI scale per game. Look at the image before saying a visual change works.

### Size limits (hard rule)

- **Functions ≤ 400 lines; files ≤ 800 lines** (scripts, scenes, data, docs, catalogs). Check: `git ls-files -co --exclude-standard | grep -E '\.(gd|tscn|json|md)$' | xargs wc -l | sort -n | tail`.
- Split scripts by responsibility before they grow. A change that would cross a limit, or touches something already over, brings it under in the same change: split functions into named helpers; move a cohesive responsibility (HUD, settings wiring, area building, save validation, layout, a catalog section, ...) into its own file the original delegates to or loads. Keep public members other scripts use working.
- **Never shrink by deleting blank lines, joining statements, removing comments, minifying or packing entries onto one line.** Move content; don't squeeze it.

### Commits

- **ALWAYS commit each feature slice and bug fix the moment it works. Mandatory.** One slice per commit; never batch, never leave finished work uncommitted, never end a turn with an uncommitted feature or fix. Don't wait to be asked or offer instead of doing it; a later request ("also tweak X") is a new slice.
- Commit **all pending changes**, including modified, added and deleted files you didn't make: review and preserve them, include them in validation, finish with a clean tree.
- **Before the final reply of any turn that touched files:** run `git status --short`; if it prints anything, commit and rerun until empty. A dirty tree means unfinished; the closing summary says the tree is clean.
- Ignore rules still apply; never force-add ignored files or commit secrets. Don't push or publish unless asked.

Message: one present-tense line, no trailing period, under ~100 characters before the tag, saying what changed **as the player feels it** (for the toolkit, as the games using it feel it), then a plain lowercase tag in parentheses for what it technically is (the system touched, `docs`, `refactor` for structural changes, or a milestone id such as `M25`). Fixes and refactors are still described by effect. Add a body only when the reason isn't obvious.

```
The Lantern Fair opens: be more interesting than the fair (third map)
A prayer at the tree now feeds the god's Favour (shrine favour)
Builders no longer wall themselves into the cottage they are raising (site reservation fix)
No script over 800 lines: split main and the ritual screen (refactor)
Every game's saves now survive a torn write (json save)
Scribes set down the covenant: design and building plan (docs)
```
