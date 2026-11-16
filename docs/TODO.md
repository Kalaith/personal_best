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

## Rules that still hold

- One shared sliding-bar input; no second coaching system.
- Rules stay in `scripts/core/` and `data/`; saves validate before use.
- Files stay under 800 lines. See `AGENTS.md`.
