# Personal Best: next work

Reviewed 25 October 2026 against `47019cf` and the current design and decisions.
This is an ordered implementation backlog, not a change to the game rules.

## Review assessment

The core game is already a complete two-client, twelve-week season: intake,
routine building, five coaching minigames, background training, shop deliveries,
three mini goals, taper, marathon and a comparative finale. The recent visual
pass makes progress much easier to scan. Preserve the shared sliding-bar input,
readable client signals, full session fees and explanations tied to choices.

The next work should make that loop dependable and understandable before
expanding it. More activities or a different engine would not address the
current gaps. The eight-client pool and five-client roster remain design targets,
not existing features.

The previous review's three inconsistencies are addressed in the source:
`session_report.gd` scales early-stop fatigue by completed repeats;
`readiness.gd` and `event_rules.gd` share injury-aware race readiness; and
`encouragement.gd` excludes the flying situation outside green. These were
checked by reading the current code, not by rerunning the old focused probes.

## 1. Make saved seasons safe to resume

**Priority: high. Fix before adding campaign state.**

Evidence:

- `scripts/core/save_game.gd`, `_check_client`, validates exercise ids and
  integral sets but does not require the appropriate `load` or `kg` field or
  enforce the exercise's set limits. A temporary headless probe confirmed that
  `{exercise: easy_run, sets: 999}` passes validation without any load. Runtime
  readers such as `RoutineRules.tier` and the planner require those fields.
- `scripts/main.gd`, `_start_week`, ignores the result of `_save_now()` and
  begins the week anyway. `_after_week` also advances to the next screen after
  a failed checkpoint. This can leave the player playing beyond the last
  durable save. Purchase rollback already exists and should be preserved.
- `_buy` stores save errors in `_notice`, then opens a shop screen that does
  not display that notice. The explanation waits until the planner opens.

Work:

- Validate saved routine shapes and bounds using the same catalog constraints
  as routine creation. Check client identity uniqueness, phase/intake coherence,
  booking values and nested result/history shapes before restore uses them.
- Give failed checkpoints a visible retry route and retain the in-memory
  season. Keep the player at a recoverable boundary until persistence succeeds.
- Show failed-purchase rollback immediately in the shop.

Done when: a valid season round-trips with the same next-week outcome; malformed
routine data is rejected before rendering; a corrupt primary can recover from a
valid backup; and injected write failure neither loses progress nor spends cash
or silently carries the player past a failed checkpoint. Use focused `tools/`
checks with isolated save files, not the player's real save.

## 2. Close the final week and preserve the ending

**Priority: high. Small, concrete player-facing fixes.**

Evidence:

- `ShopRules.problem` has no delivery-deadline check. A temporary probe bought
  foam rollers in week 12, spent $60, then finished with `phase = done`, the
  rollers still pending and ownership false. Deliveries only happen in
  `WeekRules.begin_week`, and there is no following week in this campaign.
- `main.gd`, `_after_week`, saves `done` before showing the race screens.
  `show_title` disables Continue for `done`, and `_continue` only routes to
  intake or planner. Closing during race results therefore leaves no title
  route back to the saved ending, despite `ClientState.event_result` existing.

Work:

- Refuse orders that cannot arrive in the remaining season and explain the
  deadline beside Buy. Keep the existing next-week delivery rule.
- Offer a completed-season results route from the title, reconstructing the
  race results and finale from saved state without resolving the event again.
- Keep restarting a season separate from reviewing its ending.

Done when: week-11 purchases arrive in week 12; week-12 orders cannot spend
money; closing after the final checkpoint and reopening recovers both clients'
results; and reopening never pays bonuses or reputation twice.

## 3. Teach the first block through play

**Priority: next product improvement after the reliability fixes.**

Evidence:

- The game has instructional exercise cards but no guided first-session flow
  (`session_screen.gd`; `docs/DECISIONS.md`). The cards repeat their explanation
  whenever an exercise begins.
- The inspected planner uses unlabelled fatigue, motivation and rapport icons;
  the wrap-up and finale abbreviate attributes as END, PAC, STR, REC and PK.
  Tooltips carry the meanings, so scanning is good once the vocabulary is known.
- The scripted coaches choose from rule-provided answers; their results cannot
  establish whether a new player understands the cue under timing pressure.

Work:

- Add a short, skippable first-session introduction using the actual bar:
  stop in a target, read a signal, then make a safe hold-back choice on red.
  Explain the amber block rule at its first relevant moment.
- Introduce icon and attribute meanings in context using a compact visual key
  and focus-accessible explanations. Keep detailed explanations in tooltips.
- After introduction, reduce repeated exercise-card text and let the player
  request the instructions again. Do not add a second coaching input system.

Done when: a new player can book both clients, explain the icon meters, complete
each minigame and describe why Jordan and Peg need different coaching by the
first mini goal. Prepare a short observation sheet; actual player sessions are
the evidence needed before changing timing, difficulty or season length.

## 4. Make the roster and gym capacity matter

**Priority: expansion after the first-block comprehension check.**

Evidence:

- `GameState.new_game` instantiates every catalog client; the catalog currently
  contains Jordan and Peg. There is no candidate selection or admission loop.
- The design calls for five active clients from eight authored clients.
  Capacity currently appears in the planner but does not constrain recruitment.
- The shed extension truthfully labels its extra client slots as for later
  seasons; only its equipment slots have a use in the current season.
- The planner lays all client cards in one horizontal row with horizontal
  scrolling disabled. Simply adding more clients would require a layout change.

Work in bounded commits:

- First add roster selection and enforce active capacity in core rules, with
  a planner layout that handles five clients at the existing 1280x800 base.
- Then author the remaining six marathon clients using the current attributes,
  personalities, exercises and assessment model. Give them distinct coaching
  needs and schedules; age, gender and size must not determine ability.
- Keep the two-client introductory season available. Do not enable returning
  clients, drop-outs or new sports as part of this slice. Revisit the extension's
  client-capacity wording only when those slots become usable.

Done when: the catalog contains eight validated clients, a season can select
up to five without overflow, every selected client survives save/resume and
receives all milestones and an event result, and the planner remains readable.
Run seasons across varied roster combinations before calling their balance done.

## 5. Finish coaching feedback and the release verification pass

**Priority: after the playable roster slice; required before calling it release-ready.**

Evidence:

- Music and its volume control exist; the decision log's earlier "No audio or
  tutorial" bullet is stale about audio. There are no coaching sound effects.
- `docs/DECISIONS.md` still lists gamepad play, browser export, long real-player
  sessions and educational-text review as unverified. The finale still explicitly
  calls the game a prototype.
- This review's capture tour reached the ending but reported nine ObjectDB
  instances and four resources still in use at shutdown. That is a cleanup
  finding, not proof of a leak during ordinary play.

Work:

- Add restrained cues for a stopped bar, correct/incorrect coaching, safe red
  stop, milestone and purchase/delivery, with an effects-volume control.
  Keep all information readable with sound muted.
- Diagnose capture shutdown ownership and check ordinary scene teardown before
  deciding whether the cleanup belongs to the game or capture tool.
- Verify keyboard, mouse, rebound controls and gamepad navigation through a
  complete loop, including access to chart explanations. Verify a web export's
  startup, audio activation and save/reload in a browser.
- Review educational copy against authoritative public exercise guidance in a
  dedicated sourced pass; distinguish game abstractions from training advice.
- Refresh the decision log and release wording from actual evidence. Keep
  publishing as a separately authorised action.

Done when: the feedback works audibly and muted; supported controls can complete
the season; Windows and browser verification is recorded with limits; and the
educational copy and known-issues list have been reviewed. A successful export
alone does not establish browser behavior or player engagement.

## Evidence from this review

- Godot 4.7.2 `tools/parse_all.gd`: 48 scripts, zero failed to load.
- Headless editor import: exit 0, no script/import errors reported.
- `tools/season_sim.gd`: 24 seasons completed. Good coach goals: Jordan 5/8,
  Peg 8/8; average: Jordan 0/8, Peg 6/8; careless: both 0/8. These demonstrate
  separation between the scripted policies, not human difficulty or fairness.
- Temporary read-only rule probes confirmed malformed-routine acceptance and
  the final-week undelivered purchase. The probe script was removed afterward;
  it did not read or write the player's save.
- Automated windowed tour through `Run.ps1` and `tools/capture.gd`: 20 captures
  produced in `docs/verification/`, with the shutdown diagnostics noted above.
  Inspected planner, session, wrap-up, shop, mini goal, race-week planner,
  Jordan's race result and finale at 1280x800. This was rendered automation,
  not a manual timing/input playtest. Audio was muted by the tour.
- No live save-failure injection, backup-recovery test, gamepad play, browser
  play, audio assessment or human season playtest was performed. No gameplay
  rules were changed by this review.
