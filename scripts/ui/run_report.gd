extends RefCounted
## The run reports sent to Hatchery Signals (the toolkit's
## telemetry/signals_client.gd, started in main.gd): one season, twelve weeks
## to the marathon, is a run. What it started with and how it ended, as
## catalogue ids, counts and flags only (the portal rejects free text, so
## the clients' names and goal wording never go out). Pure: same season and
## results, same report.

const GameState = preload("res://scripts/core/game_state.gd")


## Sent when a new season begins.
static func started(game: GameState) -> Dictionary:
	var ids: Array = []
	for state in game.clients:
		ids.append(state.id)
	return {"mode": "season", "clients": ids, "cash": game.cash, "reputation": game.reputation()}


## Sent when a season ends: `outcome` is "completed" (the marathon was run)
## or "abandoned" (a new season replaced it). `results` are the marathon's
## (EventRules.run), empty for an abandoned season. `seconds` is active play.
static func ended(game: GameState, results: Array, outcome: String, seconds: int) -> Dictionary:
	var report: Dictionary = started(game)
	report["outcome"] = outcome
	report["wave"] = game.week
	report["seconds"] = maxi(seconds, 0)
	report["owned"] = game.owned.size()
	var sessions: int = 0
	var injured: int = 0
	for state in game.clients:
		sessions += state.sessions_done
		if state.injured_weeks > 0 or state.new_injury:
			injured += 1
	report["sessions"] = sessions
	report["injured"] = injured
	var met: int = 0
	for result in results:
		var id: String = str(result.client)
		var achieved: bool = bool(result.achieved)
		met += 1 if achieved else 0
		report[id + "_goal_met"] = achieved
		report[id + "_finished"] = bool(result.finished)
		report[id + "_seconds"] = roundi(float(result.minutes) * 60.0) if bool(result.finished) else 0
		report[id + "_niggle"] = bool(result.niggle)
	report["goals_met"] = met
	return report
