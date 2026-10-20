# Personal Best: decisions to review

Written 2026-10-20 while building the first playable prototype from
`gdd_personal_best.md` (draft 0.3). Every item below is a choice made where
the design was silent, ambiguous or had to be adapted. Each says what was
built and where to change it. None of it has been playtested by a person yet;
the numbers are tuned only against the scripted coaches in `tools/season_sim.gd`.

## Scope

- **The prototype is the full 12-week loop, not Milestone 1.** The request was
  "from a client walking in the door to the event at the end", so the build
  includes all three blocks, the weekly planner, every mini goal, the
  marathon result, the shop, reputation and capacity. Milestone 2 items not
  built: the pool of eight clients, more than two active clients, client
  drop-outs, returning clients.
- **Both clients arrive in week 1 and run the same race.** Jordan walks in
  first, then Peg. The race is the "Harbour City Marathon".
- **Names and stories are invented**: Client A is Jordan Reyes (20, student,
  footballer, Competitive); Client B is Margaret "Peg" Holloway (60, retired
  librarian running for her late husband, Anxious). `data/clients.json`.
- **All five minigames are in**: pace coaching, technique observation,
  encouragement, effort management and the check-in.
- **Save system included** (the GDD puts it in Milestone 3) because a season
  takes over an hour. Saved at the planner only; quitting mid-week replays
  that week from its start. `scripts/core/save_game.gd`.
- **No audio, tutorial or settings screen.** The title and each exercise
  card explain the controls instead.

## Readiness and results

- **Readiness is measured against each client's own goal.** The GDD weights
  (45/20/15/10/10) are kept, but each attribute counts as a share of what the
  goal needs (capped at 100 %). Using raw attributes would have had the fit
  client pass the first mini goal on day one and made the 35/60/80 thresholds
  meaningless for one of the two clients. Requirements are per client in
  `clients.json` (Jordan's sub-3:30 needs far more Endurance and Pace than
  Peg's finish). `scripts/core/readiness.gd`.
- **Readiness → finishing time:** goal time × (0.93 + 0.45 × missing
  readiness), so 100 % lands about 7 % under the goal and roughly 85 % is a
  coin flip. Race-day swing ±5 % narrows to ±2 % with Pacing Knowledge.
  Fatigue on race morning cuts readiness by up to 25 %; this is what makes
  the taper matter. `balance.json → event`, `readiness`.
- **Finish target = the 6:00 cut-off.** Finishing after it counts as a miss.
  Below 40 % race readiness the client withdraws.
- **Racing injured:** a client still injured on race day runs with a niggle
  (−15 % readiness) rather than not starting. `event_rules.gd`.
- **Finishing position** comes from a logistic curve over a 3,800-runner
  field (mean 4:32, spread 48 min).

## Sessions

- **Progress uses session performance** (the average of all minigame scores)
  as the GDD says, not per-exercise scores. The wrap-up still shows each
  exercise's coaching score and says that the average scales every
  exercise's gains.
- **The wrap-up leads with one takeaway of each kind:** "What worked" and
  "Next time". The session notes lessons as it goes (a red stop, a red push,
  the wrong encouragement for the moment, a missed check-in) with a
  priority; the report adds unsuitable exercises, weak or sharp minigames
  and arriving tired. The highest priority of each kind is shown.
  `session_takeaways.gd`.
- **The check-in does not count toward performance.** It sets starting
  energy and mood. The client's condition today (fresh, poor sleep, sore
  legs, stressed) is drawn per session with per-client weights; a hint line
  describes how they walk in. Asking the matching question cuts the energy
  penalty to 40 % and lifts mood.
- **Mood** (session only) widens or narrows target zones by 2 %.
- **Presses per minigame:** sets + 2 (4–6) for most; repeats for intervals;
  sets + 1 (max 5) for technique, where each rep is two presses (spot the
  fault, then pick the cue). Missing the fault skips the cue and scores 0.
- **Peak moments:** one on the final press of every exercise, plus one when
  energy first drops below 50 mid-exercise (not in effort management, which
  is decisions throughout). Peaks do not count toward performance; they add
  the GDD's ±% to that exercise's progress.
- **Amber depends on the block**: push in Build and Peak, hold back in Base
  and the Week 12 taper. The rule is shown in the session header.
- **Effort management** scores a full-credit call, 0.4 for the "nearly
  right" call and 0 otherwise; Continue on red adds fatigue. Correct effort
  calls also teach Pacing Knowledge (the GDD credits only pace coaching;
  without this Jordan's Pacing Knowledge stalled whenever tempo runs left
  his plan).
- **Stop ends the exercise.** The client walks it off (+15 energy) and the
  session moves on with no closing peak. Stopping on red keeps full credit:
  the skipped repeats are not scored. Stopping a client who had more in
  them scores the skipped repeats as 0. Fatigue from the exercise is charged
  only for the share of repeats done. The wrap-up says where they stopped.
  `session_sim.gd → _stop_exercise`, `balance.json → effort`.
- **Encouragement reads the moment, not just the personality.** Each press
  draws a situation: steady (use their usual approach), exhausted (calm),
  frustrated (informative) or flying (competitive; upbeat for Anxious
  clients). Red/amber energy makes exhausted likely, a poor last press or low
  mood frustrated, a perfect last press or high mood flying. The cue line
  describes the situation. Flying is only possible on a green signal, so the
  cue never contradicts the face and meter. Right approach scores as normal, their usual
  approach when the moment wanted another 0.5, anything else 0.2. Approach
  zones are shuffled each press. `encouragement.gd`,
  `lines.json → encouragement_situations`, `balance.json → encouragement`.
- **Energy** starts at 100 − fatigue (adjusted by the check-in) and drains
  each press by exercise intensity × load, eased by Endurance. Pushing at a
  peak drains more; holding back restores a little.
- **Rapport per correct peak is +2, not the GDD's +5**, and +1 per right
  encouragement, +2 per right check-in question. At +5 rapport maxed out in
  the third week.
- **Without a heart-rate monitor** the player sees the signal name, colour,
  face and body-language line, but no energy number. The monitor adds the
  exact energy and a heart rate.

## Routines

- **Suggested routines are priority lists** in `clients.json`. The first four
  exercises the gym can run are used, so buying foam rollers or a rowing
  machine changes what the advisor suggests. Each block (base, build, peak,
  taper) has its own suggestion; when a block starts the planner asks for a
  review, and the old routine stays in place until the player confirms.
- **Load tiers for weighted exercises** come from the weight relative to
  what suits the client (4 kg + 0.16 × Strength; barbell 20 kg + 3× that).
  Under 70 % is Easy, over 120 % Hard, over 150 % unsuitable.
- **Unsuitable rules** (half value, explained in the wrap-up): Hard easy
  runs or foam rolling; Hard running or skipping for a beginner; Hard long
  runs or intervals in the taper; intervals in Base for a beginner; weights
  over 150 % of a fitting load.
- **Suitability modifiers:** each exercise has a goal fit per target type
  (0.75–1.15); training an attribute under 60 % of the goal's need ×1.15;
  training one already met ×0.7; intervals in Base ×0.85 for non-beginners.
- **Exercises built**: easy run, long run, tempo run, intervals, goblet
  squat, lunges, step-ups, skipping, core circuit; unlocked by purchases:
  foam rolling (removes fatigue), rowing, barbell squat.
- Easy and long runs give a little Pace too; otherwise a "finish" client who
  never does tempo work could not reach the Pace requirement.

## Time, fatigue and motivation

- **One coached session a week for both clients** (the GDD allows 1–2). With
  one unavailable week each (Jordan's exams in week 6, Peg's grandchildren in
  week 3) blocks hold 3–4 sessions, inside the GDD's 3–5. Which weekday is
  booked is cosmetic.
- **Training alone**: Jordan 3 times a week, Peg twice, at 50 % value × 0.7
  reference performance × a motivation factor, with 25 % of the routine's
  fatigue each time.
- **Recovery** per rest day is 30 × (0.6 + Recovery/100). Rest days = 7 −
  own sessions − coached. A week with 4+ rest days also gives +1 Recovery.
- **Skipping a week** costs 6 motivation. Motivation also moves with session
  performance, mini goals and injuries.
- **Injury**: one missed week. Picked up only from pushing on red (15 %).

## Gym, money and reputation

- **Starting cash $250.** Session fees: Jordan $35, Peg $45, +10 % per
  reputation level above 1. No rent or running costs.
- **Reputation is points-based**: a passed mini goal is 1 point, a reached
  marathon goal 3 (= the GDD's +1 level), withdrawing or racing injured −3.
  Every 3 points is a level. Without mini goals counting, the Reputation-2
  items could never be bought before the race.
- **Treadmill**: removes the bad-weather penalty for runs (rain, about one
  week in five, costs outdoor runs 20 %) and widens the Perfect band in pace
  coaching by 3 %. Runs move indoors onto it in bad weather.
- **Track membership**: intervals at full value instead of 80 % on the road.
- **Heart-rate monitor uses no slot**; foam rollers do. The starting kit
  fills 4 of 6 slots, so before the shed extension only two of foam
  rollers / rowing machine / treadmill / barbell fit.
- **Only gym upgrades that pay off this season are for sale.** The shed
  extension is $700 (was $1,500) and sold for its +3 equipment slots; its +2
  client capacity is labelled as for later seasons. The small studio is
  marked `future` in `shop.json`: listed under "Later seasons", not
  buyable.
- **Race projection from week 8.** The planner shows the finishing range if
  the race were run today (today's readiness and fatigue, ± race-day luck)
  and whether the goal is on track, in reach or not yet. It uses the same
  start-line readiness as race day (`Readiness.race_readiness`), including
  the 15 % penalty for running injured.
  `Readiness.projection`, `balance.json → event.projection_from_week`.

## Balance as tuned (season_sim, 8 seeds each)

| Coach | Jordan race readiness | Jordan goals | Peg race readiness | Peg goals |
|---|---|---|---|---|
| Good (follows suggestions, reads signals) | ~89 % | 5/8 | ~96 % | 8/8 |
| Average | ~76 % | 0/8 | ~88 % | 6/8 |
| Careless (pushes every peak) | ~59 % | 0/8 | ~71 % | 0/8 |

Jordan's sub-3:30 is meant to be the hard target. Peg's requirements were
lowered (Endurance 55, Strength, Recovery and Pacing Knowledge 40) so an
ordinary first season usually gets her over the line; before that the
average coach finished 2/8. These are scripted policies, not human success
rates: review after playtesting.

## Presentation

- All art is drawn in code (figures, faces, shed, road, track); no assets
  besides the icon. Figures are built from each client's `look` in
  `clients.json`.
- The race is shown as a short running scene, not a playable race, per the
  GDD.
- The educational disclaimer is on the title screen.

## Not yet checked

- Gamepad play, the web export in a browser, and long sessions by a real
  player.
- Educational text has not been checked against public exercise guidance
  (a GDD requirement before release).
