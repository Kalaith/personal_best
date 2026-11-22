# Personal Best: agent TODO

Updated 16 November 2026. Only outstanding work an agent can do alone belongs
here: bug fixes, required improvements and next steps. Player observation
sessions, listening and publishing are left out on purpose. Remove a task
when it is done. The evidence behind sections 1 to 4 is in
[NEXT_STEPS](NEXT_STEPS.md); the wider plan is in
[FULL_GAME_PLAN](FULL_GAME_PLAN.md).

Review basis (16 November): `parse_all`, the headless editor import and
`season_sim` all run clean. The three bugs in section 1 were confirmed still
present by reading the current source. Nothing was looked at or played.

## 1. Bugs (fix before anything else)

- [ ] **Week-12 orders take the money and never arrive.**
  `ShopRules.problem` (`scripts/core/shop_rules.gd`) has no deadline check
  and deliveries only happen in `WeekRules.begin_week`. Refuse an order
  that cannot arrive in the season and say why beside Buy.
- [ ] **A finished season cannot be reopened.** `main.gd` sets
  `title.has_save` false when the phase is `done`, and `_continue` only
  routes to intake or the planner. Add a results route from the title that
  rebuilds the race results and finale from saved state without resolving
  the event or paying bonuses again.
- [ ] **A failed save is ignored.** `_start_week` and `_after_week` call
  `_save_now()` and carry on whatever it returns. Hold the player at the
  boundary with a visible retry, keep the season in memory, and show a
  failed purchase's rollback in the shop at once.
- [ ] **Saved routines are barely validated.** `save_game.gd`
  `_check_client` accepts `{exercise: easy_run, sets: 999}` with no load.
  Validate shape and bounds with the catalog's own constraints, plus
  client id uniqueness, phase and intake coherence and booking values.
- [ ] **Add a headless save check** in `tools/` on isolated files: a season
  round-trips to the same next week, malformed data is refused, a corrupt
  primary recovers from the backup, and an injected write failure loses
  nothing and spends nothing.

## 2. Required improvements

- [ ] **First-session introduction** on the real sliding bar: stop in a
  target, read a signal, hold back on red; skippable; the amber rule at
  its first moment.
- [ ] **A visual key for the icons and END, PAC, STR, REC, PK**, shown in
  context and reachable by focus, not only by tooltip.
- [ ] **Repeat exercise cards less** after the introduction, with a button
  to see the instructions again.
- [ ] **Coaching sounds** (stopped bar, right and wrong call, safe red
  stop, milestone, purchase and delivery) with an effects volume beside
  Music. Everything stays readable muted.
- [ ] **Shutdown leak in the capture tour**: nine ObjectDB instances and
  four resources still in use at exit. Find the owner (the settings store
  held its file in The Last Hearth) and check an ordinary scene teardown.
- [ ] **Version and wording.** `project.godot` has no `config/version`,
  and the finale says "This prototype ends here." Add the version; reword
  the finale when the roster work lands.
- [ ] **Quit, credits, icon.** Check the title offers Quit on desktop; add
  a credits page with Godot's licence text; the Windows preset has
  `application/modify_resources=false` and no icon.

## 3. Verification an agent can do

- [ ] **Pad and rebound keys through a whole season** by scripted input in
  the capture tour, including the chart explanations.
- [ ] **Browser pass.** `.\publish.ps1 -BuildOnly`, serve the web build
  locally and check startup, audio starting after the first click, a save
  and a reload in Chrome.
- [ ] **Source the educational copy.** Check each exercise card against
  public exercise guidance, note the source in `docs/`, and mark what is a
  game abstraction.

## 4. Next steps (the roster)

- [ ] **Roster selection and capacity** in the core rules, with a planner
  layout that holds five clients at 1280x800 (cards are one unscrolled row
  today).
- [ ] **Six more clients** to make the designed eight, using the current
  attributes, exercises and assessment model, each with a distinct coaching
  need. Age, gender and size never decide ability.
- [ ] **Extend `season_sim`** to varied roster combinations and report
  goals per client and policy, as it does for Jordan and Peg.

## Screen fit: a real 1920x1080 layout (from spiritwright, 18 Nov 2026)

Spiritwright (commit `4a335a1`) now lays out at 1920x1080 on a 1080p screen
instead of stretching a 1280x720 layout by 1.5x, so bigger screens show more
room, not bigger text. How it works: `project.godot` has a 1920x1080 viewport
with `stretch/mode="canvas_items"` and `stretch/aspect="expand"`, and
`scripts/ui/screen_fit.gd` (started from `main.gd`'s `_ready` with
`ScreenFit.watch(get_tree().root)`) sets `root.content_scale_size` on every
resize. Windows between 1280x720 and 1920x1080 get one layout unit per
pixel. Larger screens are scaled up so the layout stays at least 1920x1080
(4K doubles), and smaller ones are shrunk to a 1280x720 layout. The Interface
size setting (`content_scale_factor`) still multiplies on top. Use the
toolkit's `res://addons/hatchery/settings/screen_fit.gd` (it also handles
high-DPI screens and takes the smallest layout as an argument) rather than
copying spiritwright's file.

- [ ] `project.godot`: viewport 1280x800 -> 1920x1080 (or 1920x1200 to keep
  the 16:10 Deck shape), add `window/stretch/aspect="expand"` (now `keep`,
  so a 16:9 screen gets side bars). Mount screen fit, with its smallest
  layout at 1280x800 if the Deck stays the floor.
- [ ] `ui/shed_kit.gd` already handles the canvas shrunk onto a phone; make
  sure it reads the layout size, not the 1280x800 constant, so it and screen
  fit don't both shrink.
- [ ] `ui/game_settings.gd` panel is fixed at 720x560; check it at 1920.
- [ ] Capture every screen (title, settings, the main play screen and each
  panel/overlay) at 1920x1080, 1600x900, 1280x720 and 1280x800, and look at
  them: nothing pinned to the old 1280 edge, no panel left skinny in the
  middle of a wide layout, no text overlapping. Then play the web build in
  Chrome at a full-screen 1080p window and a small one.
- [ ] Toggle full screen and drag-resize the window mid-screen: anything
  sized once at build time (e.g. `get_viewport_rect()` read in `_ready`)
  must follow `resized`, or it keeps the old width.

## Analytics: anonymous play stats to Hatchery Signals (from one_more_upgrade, 22 Nov 2026)

one_more_upgrade (commits `57848cc` and `19a5af8`) now sends anonymous play
stats to Hatchery Signals, the WebHatchery analytics portal
(`D:\WebHatchery\apps\game_analytics`, live at
`https://webhatchery.au/game_analytics`). The client lives in the toolkit:
`res://addons/hatchery/telemetry/signals_client.gd` (toolkit commit `acd98a2`;
documented under "telemetry" in `godot_toolkit/GODOT_TOOLKIT.md`; the event
contract is `apps/game_analytics/docs/EVENT_CONTRACT.md`). It sends session
start, a heartbeat per minute of active play, session end, once-per-install
milestones and, for run-based games, `run_started` / `run_ended` reports.
Events go out in batches in the background and never block the game. Reports,
milestones and the session end are kept in `user://` until they are delivered.
Every build (editor, local preview, itch, webhatchery.au) sends to the live
portal and tags its source. Reporting is off headless, with `--no-save` or
`--no-analytics`, and when the player turns off "Share anonymous play stats".
Use the toolkit files; do not copy one_more_upgrade's. For a working example,
read one_more_upgrade's `scripts/presentation/main.gd` (search for
`analytics`), `scripts/presentation/settings_flow.gd`,
`scripts/presentation/run_report.gd`, `tools/analytics_check.gd` and the
Analytics line in its `AGENTS.md`.

- [ ] **Config.** Add `data/analytics.json`:
  ```json
  {
  	"schema_version": 1,
  	"endpoint": "https://webhatchery.au/game_analytics/api/v1/events",
  	"game": "personal_best",
  	"write_key": "<prefix>-<40 hex digits>"
  }
  ```
  Make a new random key, for example in PowerShell:
  `"pb-" + -join ((1..20) | ForEach-Object { '{0:x2}' -f (Get-Random -Maximum 256) })`.
  The key ships in the build. It identifies the game and is not a secret.
  Check that each preset's `include_filter` in `export_presets.cfg` takes it
  (`data/*.json` or `*.json` already does).
- [ ] **Portal key (the user's step).** The portal accepts a batch only if
  `GAME_WRITE_KEYS_JSON` in `apps/game_analytics/backend/.env` (local and
  production) has `"personal_best": "<the key>"`. Do not read or edit that
  `.env`. Tell the user the slug and key so they can add them. Until they do,
  every batch gets HTTP 403 and is dropped. The game is not affected.
- [ ] **Version.** `project.godot` has no `application/config/version`, and
  each batch reports it (the default is `0.0.0`). Add one, e.g.
  `config/version="0.1.0"`.
- [ ] **Mount the client.** Start it in `scripts/main.gd`'s `_ready`. The
  pattern:
  ```gdscript
  const SignalsClient = preload("res://addons/hatchery/telemetry/signals_client.gd")
  const SignalsConfig = preload("res://addons/hatchery/telemetry/signals_config.gd")
  var analytics: SignalsClient
  # in _ready, once settings are loaded:
  analytics = SignalsClient.new()
  add_child(analytics)
  analytics.is_playing = func() -> bool: return <in gameplay>
  analytics.start("res://data/analytics.json", SignalsConfig.allowed(),
  		bool(<settings>.value(SignalsClient.SETTING_KEY)), false)  # false: no Steam bridge
  ```
  `is_playing`: true while a week or session is being planned or played; false
  on the title and settings. The client counts active time only while the
  window has focus and either `is_playing` is true or the player gave input in
  the last 45 s. The session end is sent automatically on quit.
- [ ] **Opt-out setting.** Settings are `scripts/ui/game_settings.gd` (extends
  the toolkit's `settings_bundle.gd`; DEFAULTS and the Display section at the
  top). Add `SignalsClient.SETTING_KEY: true` to the defaults, a toggle
  labelled `SignalsClient.SETTING_LABEL` ("Share anonymous play stats") in the
  Display section (or the nearest equivalent), and on a change call
  `analytics.set_enabled(bool(<settings>.value(SignalsClient.SETTING_KEY)))`.
  one_more_upgrade does this in `settings_flow.gd` (DEFAULTS, WORDS and
  sections) and in `main.gd`'s setting-changed handler.
- [ ] **Milestones.** Call `analytics.milestone_once("<name>")` at the first
  meaningful progression moments. Names are stable snake_case ids, sent once
  per installation, and each must answer a design question ("do players get
  past X?"). Do not report every action. Suggested: `first_session_planned`,
  `first_shop_purchase`, `week_<n>_completed` for each of the 12 weeks and
  `marathon_reached`.
- [ ] **Run reports.** One playthrough (12 weeks to the marathon) is a run.
  Send `run_started` at a new game and `run_ended` at the marathon or when the
  player abandons it (`outcome`, the week reached, each client's finish time
  in seconds and whether they met their goal as flags, injuries, money). Call
  `analytics.game_completed()` at the marathon. Put the report builders in one
  pure script (like one_more_upgrade's `run_report.gd`: same state in, same
  report out). Call `analytics.run_started(report)` when a run begins (send
  `{}` when a saved run is continued) and `analytics.run_ended(report)` when
  it ends, before the run state is replaced. `analytics.run_seconds()` gives
  the run's active seconds. Reports hold catalogue ids, counts and flags only:
  snake_case keys, ints, floats, bools or id-like strings, one level of
  nesting (an id => count map or a list of up to 64 scalars), 8 KB at most.
  The portal's run view reads `wave`, `floor`, `bosses`, `seconds`, `outcome`,
  `mode`, `killer`, `player`, `enemy`, `lab` and `sets`, so use those names
  where they fit. Other keys are kept too.
- [ ] **Check.** Add `tools/analytics_check.gd` (headless, seconds,
  `extends SceneTree`, prints FAIL lines, exits 1). It must check that
  `SignalsConfig.read("res://data/analytics.json", errors)` gives no errors,
  that every milestone name the game uses is snake_case, and, if the game
  sends run reports, that reports built from scripted play pass
  `ReportRules.problems()` (`addons/hatchery/telemetry/report_rules.gd`) and
  survive `JsonIo.whole_numbers(JsonIo.from_bytes(JsonIo.bytes(...)))` with
  their counts still ints. Copy the optional
  `-- --endpoint=http://127.0.0.1:<port>/events` path from one_more_upgrade's
  check, which sends one real batch to a local server and expects 202. Never
  point it at the live portal. Also run the project's parse check and
  `--headless --editor --path . --quit`.
- [ ] **Docs.** Add an Analytics line to `AGENTS.md`, modelled on
  one_more_upgrade's: the client and where it starts, `data/analytics.json`
  and the key that must match `GAME_WRITE_KEYS_JSON.personal_best`, what the
  reports hold (ids, counts and flags only, never free text), when reporting
  is off, and the check command. Add the check to the checks list. Capture the
  settings screen with the new toggle and look at it.

## Rules that still hold

- One shared sliding-bar input; no second coaching system.
- Rules stay in `scripts/core/` and `data/`; saves validate before use.
- Files stay under 800 lines. See `AGENTS.md`.
