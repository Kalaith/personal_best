# Personal Best: from vertical slice to full game

Planning baseline: 29 October 2026, source revision `f1ba94e`.

This is a proposed production plan, not a change to implemented rules. The
user's assessment is that the two-character slice has gone well. Preserve what
works about Jordan and Peg while proving that it remains enjoyable at scale.
Record adopted rule changes in `DECISIONS.md` as each slice is implemented.

## 1. The full game we are aiming for

**Recommendation: ship a complete, replayable marathon coaching game first.**
One season follows a chosen group through twelve weeks, three mini goals and
the Harbour City Marathon. Different clients and equipment choices make another
season worth playing. Coaching remains the main activity; gym growth supports it.

Proposed first-release scope:

- Eight authored marathon clients, including Jordan and Peg, with up to five
  active in a season. A smaller roster remains a valid way to play.
- Keep the Jordan-and-Peg introduction available, with a skippable guided start.
- Choose the full-season roster before week 1. Everyone shares the same calendar
  and race; avoid introducing partial training blocks through late admissions.
- Give each client a distinct assessment, target, coaching need, availability,
  personal motivation and short progression through the season.
- Keep the five existing minigames, shared sliding bar, four-entry routines,
  existing attributes and three-block structure. Expand their situations and
  feedback where playtesting finds repetition.
- Make equipment choices useful across different rosters, with visible gym
  changes and results that explain the effects of preparation.
- Deliver a satisfying, recoverable ending and a clear route to a new season.
- Windows first, with the secondary web build verified before advertising it.

This recommendation deliberately bounds the first release. Persistent careers,
returning clients, seven- or ten-client gyms and other sports are a separate
expansion decision. They are present in the wider design but need more than six
extra character records: they change saves, progression, workload and economy.

## 2. What already exists and what still needs work

The source already contains the full twelve-week season, two authored clients,
five minigames, routine suggestions, background training, weather, purchases,
reputation, mini goals, taper, race results, finale and planner saves. Music and
settings exist. The recent planner, shop and routine-editor refinements are part
of the baseline; they do not need to be rebuilt as expansion milestones.

Source inspection for this plan reconfirmed these expansion blockers:

| Area | Current limit | Why it comes first |
|---|---|---|
| Recruitment | `GameState.new_game` activates every catalog client | Adding six records would activate all eight |
| Save validation | Routine entries check ids and integral sets, but not complete load/bounds | More campaign state increases recovery risk |
| Checkpoints | `_start_week` and `_after_week` do not act on save failure | A longer season must not silently outrun its save |
| Ending | Title Continue excludes completed seasons | Saved results cannot be revisited through that route |
| Delivery | Shop rules have no final-week deadline | A purchase can be paid for without a delivery week |

`NEXT_STEPS.md` retains the detailed 25 October investigation and its historical
verification results. Those results are not new tests performed for this plan.
The user's positive slice assessment is useful product evidence, but does not
establish five-client pacing, unfamiliar-player comprehension or release quality.

## 3. Ordered milestones

Each milestone consists of small playable commits, not one large merge. Its exit
criteria decide when to expand further. Estimates should follow the workload
experiment in F03; the GDD's original week estimates predate this larger slice.

### F01 — A season the player can safely finish

Deliver in separate fixes:

1. Validate complete saved routines, client uniqueness, bookings, phase coherence
   and nested results/history before restoring state.
2. Keep failed checkpoints recoverable, retain in-memory progress, and provide a
   visible retry. Show purchase-save failures immediately and preserve rollback.
3. Prevent orders whose delivery falls beyond the season.
4. Restore completed race results and the finale from saved state, without
   awarding money or reputation again. Distinguish results review from restart.

Exit: valid saves reproduce the same subsequent outcomes; malformed saves fail
before rendering; backup recovery works; injected write failures lose neither
progress nor money; week-11 deliveries arrive and week-12 orders are refused;
closing during the ending does not lose access to it. Use isolated fixtures in
`tools/`, never the player's real save. These fixes preserve the existing rules.

### F02 — Teach the coaching language through play

- Build a short, skippable introduction using the real bar and client signals:
  timing a normal press, choosing a useful encouragement, holding back on red,
  and understanding amber when the block changes.
- Introduce the condition icons, assessment chart and routine warnings at their
  first use. Keep detailed help available without restoring paragraphs to screens.
- Teach the week boundary and what quitting mid-week replays.
- Let experienced players dismiss repeated instructions and revisit help.
- Observe unfamiliar players through the first mini goal. Record confusion,
  mistaken cue readings, assistance required and time spent per screen.

Exit: players can book clients, change a routine, explain a red hold-back choice,
and describe why Jordan and Peg need different preparation without coaching from
the observer. Investigate recurring confusion before adjusting difficulty.

### F03 — Prove a larger roster is enjoyable

Do this before authoring the entire cast.

- Separate the candidate catalog from the selected active roster. Core rules
  enforce unique selection and the supported roster limit; UI only sends commands.
- Build selection and a planner that remain readable with two, three and five
  clients at 1280x800. Show who needs attention and which sessions are booked.
- Add two fully playable clients to exercise Social and Analytical personalities
  and different training constraints. Use them to prove the authoring process.
- Extend saves with explicit version migration for existing two-client seasons.
  Adding catalog clients must not add them to an already running season.
- Measure complete weeks and season repetition with the larger roster. Use a
  temporary verification fixture for five-client layout until five authored
  clients exist; do not ship duplicate characters as content.

Workload risk: at the GDD's 3–5 minutes per session, five clients with 9–15 sessions
each imply roughly 135–375 minutes of coaching alone. This is planning arithmetic,
not measured runtime. Roster growth can become repetition and makes a replayed
week more costly after quitting.

First reduce repeated instructions, unnecessary transitions and routine-editing
friction. Keep smaller rosters selectable. If sessions or checkpoint spacing
still feel too long, decide explicitly whether to change session counts, pacing
or save boundaries; do not quietly add auto-coaching that removes the core game.

Exit: a multi-client week stays readable and engaging; intake, booking, routines,
milestones and results work for arbitrary selected ids; saves migrate; adding a
client does not shift another client's seeded random outcomes. Before closing
F04, repeat the workload check with five real authored clients for a whole season.

### F04 — Complete the eight-person cast

Add the remaining four clients one at a time, using the F03 authoring process.
Each completed client gets a separate validated, playable commit.

Use these six provisional coaching briefs for the additions; names, appearances
and stories are authored later. They describe assessed needs, not demographic
rules, and must become more than personality labels.

| Brief | Distinction to explore | What the player learns |
|---|---|---|
| Social first-timer | Modest assessment, values encouragement and consistency | Keeping training manageable supports adherence |
| Analytical runner | Good base, uneven pacing knowledge | Explain the purpose of a session and control effort |
| Fast short-distance runner | Pace ahead of endurance | Short-distance speed does not replace a distance base |
| Steady runner chasing a time | Endurance ahead of pace | Choose targeted work instead of repeating strengths |
| Strong newcomer to running | Strength ahead of endurance and knowledge | A good assessment can still reveal specific gaps |
| Experienced, busy runner | Strong base with limited availability | Plan useful work around recovery and real commitments |

For every client, author intake and goal requirements, four block suggestions,
availability and condition weights, an identifiable appearance, short milestone
reactions, and success/miss ending variants. Give personal context without long
dialogue interruptions. Reuse existing exercise systems wherever they fit.

Exit: eight validated clients have distinct coaching needs and readable reasons
for their targets. Each has a verified full-season path and outcome explanations.
Exercise every client under good, average and careless scripted coaching across
multiple seeds; check mixed rosters and human play as separate evidence. Include
poor timing with sensible decisions to see whether judgment still matters.

### F05 — Make the gym and season progression worth choosing

- Rebalance income, reputation gates, equipment costs and delivery timing against
  both small and full rosters. Five-client income must not trivialise the shop;
  two-client play must still offer useful choices.
- Ensure every purchasable item has a current-season benefit, an understandable
  tradeoff and enough time to use it. Show delivered kit in the shed.
- Review block transitions, mini-goal feedback and taper prompts with the full
  cast. Make routine review useful without requiring repetitive rebuilding.
- Finish the finale as a personal summary for each client plus a gym summary:
  the goal, the result, the choices that mattered and what to try next season.
- Refresh all capacity and future-upgrade wording to match the chosen release
  scope. Do not sell extra client slots that cannot be used.

Exit: contrasting purchases support contrasting roster needs; missed bonuses do
not reduce earned fees; there is a viable path after a missed mini goal; and
small-roster play remains satisfying. Results are traceable to actual state and
choices. A fresh season provides different decisions without requiring a grind.

### F06 — Finish presentation and release quality

- Polish silhouettes, expressions and body language across the cast; preserve
  readable signals before every push/hold decision and non-colour cues.
- Add restrained coaching, result and delivery sounds with separate effects
  volume. Every cue must still work muted.
- Verify keyboard, mouse, rebound controls and gamepad through the entire loop,
  including focus, scrolling and access to chart explanations.
- Check interface scales, full-screen transitions and supported display sizes.
- Review educational copy against authoritative public guidance in a dedicated
  sourced pass; keep simplified game abstractions distinguishable from advice.
- Diagnose capture shutdown warnings and ordinary screen cleanup. Profile a
  long full-roster season rather than inferring performance from a short capture.
- Export Windows and web; verify actual launch, audio, save/reload and completed
  results on each supported target. Record limitations and known issues.

Exit: no known progress-loss defect, all advertised inputs complete a season,
the full cast has been played, explanations have been reviewed, and platform
checks are documented. Build/export verification is allowed; publishing remains
a separately authorised action.

## 4. Decisions to resolve before their dependent milestone

These are recommendations for planning, not approvals inferred from this request.
Unrelated work in F01 and F02 can proceed without settling the career model.

| Decision | Recommended first release | Resolve before |
|---|---|---|
| Campaign shape | Independent twelve-week seasons; no carried-over money or kit | F03 save and selection design |
| Admission timing | Select before week 1; no mid-season replacements | F03 recruitment |
| Roster size | Up to five, with smaller rosters allowed | F03 workload check |
| Capacity beyond five | Defer; extension provides equipment space only | F05 shop and scope wording |
| Returning clients and drop-outs | Defer; missed goals still lead to an ending | F04 story authoring |
| One or two coached sessions weekly | Keep current one; revisit only from workload evidence | F04 availability tuning |
| Save boundaries | Preserve planner checkpoints initially; measure replay cost | F03 workload check |
| Release platforms | Windows first; web only after its own verification | F06 release scope |

If a continuing gym career is essential to the full-game vision, add a distinct
milestone after F05 and before F06: season transition, archived results, returning
client reassessment and new goals, persistent gym/cash, sustainable economy and
save migration. Validate two consecutive seasons without duplicate rewards or
stale fatigue/injuries. Seven- and ten-client capacity then requires another
workload/layout check and sufficient recruitable clients; eight authored people
alone cannot fill ten unique slots. Do not enable the studio merely by removing
its `future` flag.

Keep additional sports, staff, rent, procedural clients, playable racing and
online systems outside this release. Reconsider them after the marathon game
has demonstrated that its coaching and replay loop hold up.

## 5. Delivery and verification discipline

Dependency order: F01 → F02 → F03 → F04 → F05 → F06. Rough character briefs and
presentation planning can happen early; final content tuning depends on the
roster and workload decisions. If scope must shrink, defer career expansion and
extra presentation variants before cutting recovery, readable cues or endings.

- Update this plan's milestone status and `DECISIONS.md` from actual delivery
  evidence. Keep proposed features out of runtime catalogs until implemented.
- Keep deterministic rules in core, typed GDScript, validated JSON data and
  stable ids. Split responsibilities before file/function limits are exceeded.
- At each major milestone run all applicable tools and editor/import checks;
  after balance changes run `tools/season_sim.gd`. Add focused headless scripts
  under `tools/` only for meaningful new failure modes.
- For visual changes run the real game and inspect captures in the flat
  `docs/verification/` directory. Automation cannot establish input feel.
- Record automated outcomes, rendered checks and human observations separately.
- Commit each working slice immediately; do not push or deploy without a request.

Immediate next implementation slice: F01 save validation and recovery. Then
complete ending recovery before introducing any new campaign state or clients.

This planning pass inspected design, decisions, backlog and relevant current
source. It changed documentation only; no runtime, export or human playtest was
performed, and no new content or rule change is claimed as implemented.
