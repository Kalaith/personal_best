# Personal Best

Game design document — draft 0.3  
Date: 20 October 2026  
Title: Personal Best

## 1. Concept

The player is a personal trainer who helps clients prepare for meaningful fitness goals while building and managing a gym.

Clients arrive with a goal and their own starting circumstances. The player creates a routine, coaches them through training sessions, helps them reach smaller milestones, and prepares them for a major event.

The main activity is being with the client during a gym session. Coaching minigames focus on encouragement, support, and judging when to push or hold back. Gym management provides the facilities and equipment needed to train different clients.

This is also a learning game. It should explain how training choices support particular goals and help players understand why a routine succeeds or struggles.

## 2. Status of this document

**Confirmed** means the user explicitly chose or described the direction. **Placeholder** means a working answer chosen so the design has no open questions; it is the current build target and may be revised after playtesting. All numbers marked as placeholders are tuning values.

Summary of the platform and production decisions:

| Area | Decision | Status |
|---|---|---|
| Engine | Godot 4, 2D | Confirmed |
| Platform | Windows desktop first; web (HTML5) export as a secondary target | Placeholder |
| Controls | Mouse for menus; Space, left click, or gamepad A for the sliding bar | Placeholder |
| Art style | Flat, warm 2D illustration; side-on gym view with client portrait close-ups during coaching | Placeholder |
| Exercise model | Five simplified attributes on a 0–100 scale (section 9) | Placeholder |
| Production schedule | Three milestones (section 12) | Placeholder |

## 3. Confirmed design direction

- The player takes the role of a personal trainer.
- New clients arrive with goals. The player creates routines to help achieve them.
- The primary gameplay happens during training sessions with the client at the gym.
- Sessions contain coaching minigames involving encouragement and support.
- Knowing when to push and when to hold back is central to coaching.
- A client has 3–5 sessions before a mini goal, then progresses toward a major goal.
- Gym management includes buying facilities and equipment to help train clients.
- Clients have different goals and are at different stages of life.
- Clients can share a goal while having very different starting circumstances.
- The game teaches which exercises help achieve particular goals.
- The initial activity should focus on marathon preparation, with other activities added later.
- Most coaching minigames initially use a sliding bar with timed input in a target zone, including peak moments for coaching.
- Routine creation is simple: exercise, sets, and weight.
- The starting gym operates out of a shed.
- The initial active-client limit is five.
- Clients receive progress at the end of each session, and the player gets paid.
- Achieving a client goal awards a bonus; missing a goal results in less money.
- The game uses Godot and is 2D.
- Client preparation runs as three training blocks over 12 in-game weeks.

## 4. Player experience

The player should feel that they are getting to know each client and making useful coaching decisions. Progress comes from choosing suitable training and responding to the person during the session.

The intended appeal combines:

- **Client progress:** see a person move toward a goal that matters to them.
- **Coaching judgment:** read a session and decide what support is appropriate.
- **Learning:** understand the connection between exercise choices and outcomes.
- **Gym growth:** buy equipment and facilities that create more training options.

## 5. Core loop

1. **Meet a new client.** Learn their goal, target, and starting circumstances.
2. **Create a routine.** Choose training that supports the goal using available facilities.
3. **Coach a training session.** Play minigames and respond to how the client is coping.
4. **Review progress and get paid.** The client receives progress at the end of the session, and the player receives the session payment.
5. **Complete a mini goal.** At the end of each training block, test progress toward the larger goal.
6. **Continue preparation.** Adjust the routine and train toward the major goal.
7. **Receive the event result.** See the outcome and what contributed to it. Goal achievement awards a bonus; missing the goal means less money.
8. **Develop the gym.** Buy equipment and facilities to support future training.

**Gym purchases (placeholder):** the shop is available from the weekly planner at any time between sessions. Purchases are delivered at the start of the next in-game week, so the player must plan ahead.

## 6. Client progression

### Structure

`New client → routine → three training blocks with mini goals → major goal`

| Block | Weeks | Coached sessions | Ends with |
|---|---|---|---|
| 1 — Base | 1–4 | 3–5 | Mini goal 1 (end of week 4) |
| 2 — Build | 5–8 | 3–5 | Mini goal 2 (end of week 8) |
| 3 — Peak and taper | 9–12 | 3–5 | Mini goal 3 (end of week 11), marathon (end of week 12) |

Each client receives 9–15 coached sessions before the major goal. The number of sessions in a block is set by the client's weekly availability (section 8). The third mini goal is a "dress rehearsal" held one week before the event, leaving week 12 as a taper.

### Time model (placeholder)

- The game advances one in-game week at a time from a **weekly planner** screen.
- Each week runs Monday to Friday. Each active client can be booked for at most one session per day, and only on days they are available.
- A playable session represents a key coached appointment. Training the client does on their own between appointments is simulated in the background from their routine, at 50% of the progress value of a coached session, reduced further if the client's motivation is low.
- Ending the week resolves background training, recovery, and any purchases.

### Milestones (placeholder)

Mini goals are set as a percentage of the client's marathon readiness, expressed as an achievable run test:

| Mini goal | Test | Pass condition |
|---|---|---|
| 1 | 30-minute continuous effort (run or run-walk) | Readiness ≥ 35 |
| 2 | Half-marathon distance | Readiness ≥ 60 |
| 3 | 30 km dress rehearsal | Readiness ≥ 80 |

The test is presented the same way as the major event: a short fade to black and a result screen. A failed mini goal does not end the programme; the player receives guidance and continues to the next block.

### Major goal (placeholder)

Each client has a marathon target set at intake, based on their starting assessment:

- **Finish** — complete the course within the 6-hour cut-off (default for beginners).
- **Target time** — finish under a personal target time (for experienced runners).
- **Podium or win** — reserved for elite clients in later content; not in the first version.

Client A (fit 20-year-old) targets a sub-3:30 finish. Client B (overweight 60-year-old) targets finishing within the cut-off.

## 7. Training session gameplay

### Focus

Training sessions use a set of minigames for encouragement and support. The player decides when the client should push and when they should hold back. Most minigames use one shared sliding-bar interaction.

### Session structure (placeholder)

1. **Client check-in** — sets the starting energy and mood for the session.
2. **Exercise minigames** — one per routine exercise, up to four.
3. **Wrap-up** — the progress and payment screen.

A session takes roughly three to five minutes of play.

### Sliding bar (placeholder)

- A marker moves back and forth along a horizontal bar.
- **Input:** a single press (Space, left click, or gamepad A).
- **Speed:** one full pass takes 1.6 seconds at baseline. Speed rises by up to 40% with exercise intensity and client fatigue.
- **Target zone:** 20% of the bar width, with a 6% **Perfect** core in its centre. Zone width grows by up to 5% with client rapport and shrinks by up to 5% when the client is fatigued.
- **Scoring:** Perfect = 1.0, Good (inside the zone) = 0.7, Miss = 0.0. Each minigame contains 4–6 presses. The minigame score is the average.
- **Session performance** is the average of all minigame scores (0.0–1.0).

### Peak moments and push or hold back (placeholder)

Each exercise minigame contains one or two **peak moments**, triggered on the final set or when the client's energy crosses a threshold. At a peak moment:

1. The client shows a **signal**: an energy meter colour, plus a matching portrait and body-language cue.
2. The bar splits into two zones: **Push** (orange, right) and **Hold back** (blue, left).
3. The player chooses by stopping the marker in a zone. Hitting neither counts as a missed cue.

| Signal | Cues | Correct response | Wrong response consequence |
|---|---|---|---|
| Green — Fresh | Steady breathing, good form, smiling | Push | Holding back: −20% progress from this exercise |
| Amber — Working | Heavy breathing, focused face | Push if the routine is a build/peak session, otherwise hold back | −10% progress, or +10 fatigue |
| Red — Overreaching | Form breaking down, grimace, slowing | Hold back | Pushing: +25 fatigue and a 15% chance of a minor injury (one missed session) |

A correct response gives +15% progress for that exercise and +5 rapport. Session feedback explains each peak-moment outcome.

### Minigames

All five use the sliding bar; they differ in what the zones represent and the signals shown.

| Minigame | Player activity | Intended decision |
|---|---|---|
| Pace coaching | Hit the zone matching the effort the client should hold | What effort can this client sustain today? |
| Technique observation | Stop the marker when the form fault appears, then choose a cue zone | What feedback would help now? |
| Encouragement | Zones represent approaches (calm, upbeat, competitive, informative) | What support will help this person? |
| Effort management | Peak-moment heavy: continue, reduce, or stop | Is pushing further useful at this point? |
| Client check-in | Zones represent questions; the answer sets starting energy and mood | How should their feedback change the session? |

### Feedback rules

- Pushing harder does not always produce the best outcome.
- Holding back is a successful decision in appropriate situations.
- Clients provide readable signals so decisions can be learned.
- Session feedback explains the effect of the player's choices.
- Coaching accounts for the client's routine, current condition, and individual needs.

## 8. Clients and individual differences

### Examples

Two clients may both want to run a marathon:

| Example client | Starting description | Marathon target |
|---|---|---|
| Client A | A 20-year-old man in good physical fitness | Sub-3:30 |
| Client B | A 60-year-old woman who is overweight | Finish within the cut-off |

The game should support many combinations of goals, life stages, and starting circumstances.

### Client data (placeholder)

| Field | Values |
|---|---|
| Goal and target | Activity, target type, and target value |
| Starting attributes | Endurance, Pace, Strength, Recovery, Pacing Knowledge (0–100) |
| Training experience | None, Some, Experienced |
| Availability | 1–2 coached sessions per week, on specific days |
| Fatigue | 0–100; recovers 30 per rest day |
| Motivation | 0–100; affects background training |
| Personality | One trait: Competitive, Anxious, Social, or Analytical. It sets which encouragement approach works best. |
| Rapport | 0–100; grows with correct coaching and widens target zones |
| Session fee | Set by the client (section 10) |

Age, gender, and body size are never used alone to assign ability. All starting attributes come from an in-game intake assessment shown to the player.

## 9. Routines and learning

### Routine creation

The player builds a routine from up to four entries. Each entry has three fields: **exercise**, **sets**, and **weight**. The game suggests exercises that support the client's goal and explains why they are useful. Repetition counts are not a field.

**Running in the routine (placeholder):** running exercises use the same three fields:

- **Exercise** — the run type: easy run, tempo run, intervals, or long run.
- **Sets** — the number of efforts. Continuous runs use 1; intervals use 4–8.
- **Weight** — relabelled **Load** for running. It is chosen from Easy, Moderate, or Hard instead of kilograms.

### Training attributes (placeholder)

| Attribute | Improved by | Marathon role |
|---|---|---|
| Endurance | Easy and long runs | Main contributor to readiness |
| Pace | Tempo runs and intervals | Faster finish times |
| Strength | Weighted exercises (squats, lunges, step-ups) | Injury resistance, late-race form |
| Recovery | Rest days, mobility, foam rolling | Faster fatigue recovery |
| Pacing Knowledge | Correct pace-coaching responses | Reduces event randomness |

**Readiness** for the marathon is a weighted score: 45% Endurance, 20% Pace, 15% Strength, 10% Recovery, 10% Pacing Knowledge.

### Routine rules (placeholder)

- **Suggestions:** a new client starts with a suggested routine. The player can accept it or edit any entry.
- **Changes:** the routine is fixed for the session. It can be changed between sessions. Intensity within a session is adjusted through push and hold-back decisions.
- **Unsuitable choices:** an advisor note warns about poorly matched entries before the player confirms. Unsuitable entries give reduced progress (×0.5), and the post-session screen explains why.
- **Simulation depth:** progress is calculated per session as:  
  `routine value × suitability (0.5–1.2) × session performance (0–1) × fatigue modifier (0.6–1.0) × peak-moment bonuses`

### Educational basis (placeholder)

Exercise effects use simplified game values, not a real training programme. Before release, in-game explanations are checked against established public exercise guidance, and the game shows a short note that it is not medical or training advice.

## 10. Gym management and access

### Starting gym

The player starts with a gym operating out of a shed. They can initially coach up to five active clients.

**Starting equipment (placeholder):** floor mats, a dumbbell set (2–20 kg), skipping ropes, a step box, and access to the local road loop for outdoor runs.

### Income (placeholder values)

| Event | Payment |
|---|---|
| Completed session | Client fee: $30–$60, based on client tier and gym reputation |
| Mini goal passed | $50 bonus |
| Mini goal missed | No bonus |
| Major goal achieved | $500 bonus, plus +1 reputation |
| Major goal missed | Bonus forfeited; session fees are unaffected; −1 reputation if the client is injured or drops out |

Missing a goal means less money through the lost bonus. Session payments are never reduced, so the player is not punished twice.

### Reputation and access (placeholder)

Reputation runs from level 1 to 5. It rises with achieved goals and gates facilities and new client types.

| Purchase | Cost | Requires | Effect |
|---|---|---|---|
| Foam rollers | $60 | — | Unlocks mobility work (Recovery) |
| Heart-rate monitor | $150 | — | Shows the exact energy value during sessions |
| Rowing machine | $350 | — | Low-impact Endurance work |
| Treadmill | $400 | — | Runs in any weather; precise pace work |
| Barbell and rack | $600 | Reputation 2 | Heavier Strength exercises |
| Running track membership | $800 | Reputation 2 | Unlocks interval sessions at full value |
| Shed extension | $1,500 | Reputation 2 | +2 client capacity, +3 equipment slots |
| Small studio | $5,000 | Reputation 4 | +3 client capacity, +6 equipment slots |

### Capacity and space (placeholder)

- **Client capacity:** Shed 5 → Extended shed 7 → Small studio 10.
- **Equipment slots:** Shed 6 → Extended shed 9 → Small studio 15. Each equipment item uses one slot; memberships use none.
- **Maintenance and staffing:** not included in the first version.

## 11. Major events and results

### Resolution

The event is resolved with a fade to black followed by a result. There is no playable race.

**Outcome calculation (placeholder):**

- The client's readiness on event day is converted to a predicted finish time.
- A random variation of ±5% is applied. High Pacing Knowledge narrows this to ±2%.
- Two or three event moments are drawn from the client's weakest attributes (for example, "hit the wall at 32 km") to explain the result.

### Results screen

- Whether the client's goal was achieved.
- Finishing time and position.
- A short account of important event moments.
- An explanation of how preparation affected the result.
- Payment and bonus summary.
- Feedback for future clients with similar goals.

### After the event (placeholder)

The client leaves the active roster, which frees a slot. A client who achieves their goal may return later with a new goal. A client who misses it may sign up again for another attempt.

## 12. First playable scope and production plan

The first activity is marathon preparation.

### Milestone 1 — Prototype (placeholder: 4 weeks)

- One shed gym and a small equipment shop.
- Two clients (Client A and Client B) with the same marathon goal and different starting circumstances.
- One training block per client, with 3–5 sessions and a mini goal.
- The sliding bar used for pace coaching, technique observation, and encouragement, including peak moments.
- Routine creation, progress feedback, session payment, and a mini-goal result screen.

**Success test:** playtesters can describe how the two clients needed different coaching.

### Milestone 2 — Full marathon loop (placeholder: 8 weeks)

- All three training blocks over 12 in-game weeks, the weekly planner, and the major event result.
- All five minigames, goal bonuses, reputation, the full shop, and capacity upgrades.
- Up to five active clients, drawn from a pool of eight authored marathon clients.

### Milestone 3 — Polish and release (placeholder: 6 weeks)

- Art, audio, tutorial, balance tuning, educational text review, save system, and Windows and web builds.

## 13. Future expansion

Adding activities beyond marathon preparation is part of the intended direction.

The reusable structure is:

`Client goal → suitable routine → coached sessions → mini goals → major event result`

New activities change the relevant exercises, facilities, milestones, and measures of success while keeping the client coaching structure.

**Planned additional activities (placeholder, in order):**

1. **Powerlifting meet** — strength-focused routines that use the weight field fully.
2. **Charity mountain hike** — endurance and hill work for mixed-ability groups.
3. **Return from injury** — rehabilitation clients for whom holding back is often correct.
4. **Triathlon** — needs pool and cycling facilities.
