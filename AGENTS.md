# Personal Best project guidance

Personal Best is a 2D coaching game: the player is a personal trainer working out of a backyard shed, preparing clients for a marathon. `gdd_personal_best.md` is the design document; `docs/DECISIONS.md` records every choice made where the design was silent or had to be adapted, and is the list to review after playtesting. Read both before changing rules. The shared standards at the end of this file apply as well as everything here.

## Product invariants

- The coached session is the heart of the game. Every coaching minigame uses the one sliding bar (`scripts/ui/slide_bar.gd`); a new minigame changes what the zones mean, not the input.
- Pushing harder is not always right. Holding back must stay a winning decision whenever the client signals red, and clients always show a readable signal (meter colour, face and a body-language line) before a push or hold-back choice.
- Every result explains itself: session wrap-up, mini goals and the marathon say what caused the outcome in plain words. Do not add a number the player cannot trace back to a choice.
- Session fees are never reduced by a missed goal; only bonuses are lost.
- Age, gender and body size never set ability on their own. Starting attributes come from the intake assessment shown to the player.

## Project engineering

- **Compatibility** renderer, 1280×800 base resolution with `canvas_items` stretch. All UI is built in code from `scripts/ui/style.gd` (the toolkit `UiKit` and one warm palette); figures and the gym are drawn with `_draw`.
- The shared WebHatchery Godot toolkit (`../godot_toolkit`) is linked in as `res://addons/hatchery/` by `..\godot_toolkit\tools\Link-Toolkit.ps1 -ProjectDir .` (a junction, ignored by Git). Personal Best uses its balance facade, JSON and data-rule helpers, `Det` for seeded picks, `JsonSave`, the screen switcher, and the UI kit. Change toolkit code in `../godot_toolkit` under its own AGENTS.md.
- Rules live in `scripts/core/` (no scene tree, all randomness from seeded generators forked per week and client). Screens live in `scripts/ui/`; they read state and call core functions, never change state any other way.
- Balance numbers live in `data/balance.json`; clients, exercises and the shop live in `data/clients.json`, `data/exercises.json` and `data/shop.json` with stable ids. `scripts/core/catalog.gd` validates all of them at startup.
- The campaign is saved at the weekly planner only (`user://personal_best_save.json`). A purchase is refused if saving it fails.

## Project checks

- `tools/season_sim.gd` plays whole seasons headlessly with scripted coaching (good, average and careless) and prints readiness at each milestone and the event results. Run it after a balance change:
  `& "C:\Program Files\Godot\Godot_v4.2.2-stable_mono_win64_console.exe" --headless --path . --script res://tools/season_sim.gd`
- Parse/import check: `--headless --editor --quit`.
- Verify anything visual by running the game (`Run.ps1`).

## Commit voice

Commit lines describe what changed as it is felt in the shed and by the clients.

```
Peg now tells you when her legs are sore if you ask the right question (check-in)
```

## Publishing

Publishing (`publish.ps1`, `publish-itch.ps1`) requires separate authorisation. `.\publish.ps1 -BuildOnly` (export only, no deploy) is fine for verification. Both are the shared templates from `../godot_toolkit/templates/`. Exports need the **standard (non-mono)** Godot 4.2.2 console editor; `Run.ps1` uses the installed mono editor for playing.

## Shared WebHatchery Godot standards

This section is identical in the AGENTS.md of every WebHatchery Godot project (`bound_god`, `small_following`, `spiritwright`, `godot_toolkit`). Change it in all four together; project-specific rules go in the sections above.

### Working

- Work only inside this project unless the user explicitly broadens the task. Preserve any user changes.
- Do not install or upgrade Godot, export templates, tools, plugins or GDExtensions without approval. Prefer built-in engine features.
- Do not overwrite original art.

### Code

- Godot **4.2.2** GDScript. The renderer is set per project (see above).
- Static typing everywhere: variables, parameters and return types.
- Load dependencies with `const X = preload("res://...")`.
- Tabs, LF, UTF-8, final newline (`.editorconfig`).
- Split scripts by responsibility before they grow. Size limits are below.
- Simulation and rules code never touches the scene tree, `Time`, `OS` or the global `randi()`/`randf()`. All randomness comes from an owned `RandomNumberGenerator`, so the same seed gives the same result. Presentation reads that state and sends commands; it never changes it any other way.
- Balance numbers and catalogs live in JSON under `data/` with stable ids (and `schema_version` where a catalog has one), validated at startup. Missing or mistyped data fails fast: report it, never silently default in code.
- Keep every catalog (upgrades, parts, miracles, blocks and so on) bounded to implemented effects. Do not add entries the code does not support.
- Persistent state lives under `user://` with schema validation, staged writes and backup recovery. A failed save must never lose progress or spend anything.

### Verification

- Do not create a `tests/` directory, test frameworks or test addons. Automated checks, where a project has them, are headless scripts in `tools/`, kept out of the exported game.
- Checks do not gate commits. Run the full set (the project's checks, if any, and a parse/import check with `--headless --editor --quit`) when a major feature or milestone is finished, and fix what they find before calling it done.
- Headless checks do not verify visuals, audio, input or feel. Verify anything visual by running the game (`Run.ps1`) and looking at it.
- Say plainly what was and was not checked.

### Size limits (hard rule)

- **No function may exceed 400 lines.**
- **No file may exceed 800 lines**: scripts, scenes, data, docs and text catalogs. Check with `git ls-files -co --exclude-standard | grep -E '\.(gd|tscn|json|md)$' | xargs wc -l | sort -n | tail`.
- When a change would push a function or file past its limit, or one is already over, **bring it below the limit in the same change**. Split a long function into well-named helpers; shrink a file by moving a cohesive responsibility (HUD, settings wiring, area building, save validation, layout, a catalog section and so on) into its own file and having the original delegate to or load it.
- **Never shrink a function or file by deleting blank lines, joining statements, removing comments, minifying or packing several entries onto one line.** Blank lines between functions and the existing comment density stay as they are. Line count comes down by moving content, not by squeezing it.
- Keep public members that other scripts use working, either in place or through a delegating function.

### Commits

- Commit early and often: after every complete, working step (a system, a fix, a data pass), not at the end of a milestone. Commits do not wait on checks (see Verification).
- Commit **all pending project changes**, including modified, added and deleted files you did not make yourself. Do not leave user changes or another agent's changes uncommitted because you did not touch them: review and preserve their contents, include them in the validation, and finish with a clean working tree.
- Existing ignore rules still apply to generated files, local tooling and credentials. Never force-add ignored files or commit secrets.
- Do not push or publish unless the user asks.

Message style: one line describing what changed **as it is felt by the player** (for the toolkit, by the games that use it), then a short plain tag in parentheses saying what it is technically.

```
Neris raises a ward whenever she is struck (spirit trait)
A prayer at the tree now feeds the god's Favour (shrine favour)
The Lantern Fair opens: be more interesting than the fair (third map)
Every game's saves now survive a torn write (json save)
Scribes set down the covenant: design and building plan (docs)
```

- Present tense, no trailing period, under ~100 characters before the tag where possible.
- Fixes and refactors are still described by their effect: `Builders no longer wall themselves into the cottage they are raising (site reservation fix)`, `No script over 800 lines: split main and the ritual screen (refactor)`.
- Tags are lowercase and plain: the system touched, `docs`, `refactor`, or a milestone id such as `M25`.
- Add a body only when the reason is not obvious from the line.
