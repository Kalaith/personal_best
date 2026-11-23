extends SceneTree
## Analytics for Hatchery Signals: data/analytics.json must read cleanly,
## every milestone name main.gd sends must be snake_case, and season reports
## from a scripted season played to the marathon (and one abandoned after a
## week) must pass the portal's shape rules (the toolkit's
## telemetry/report_rules.gd), name only catalogue ids, and survive the
## unsent-queue file's JSON round trip with their counts still integers.
## Seconds; prints FAIL lines and exits 1 on a problem.
##
## With `-- --endpoint=http://127.0.0.1:8765/events` it also sends a real batch
## through the toolkit's signals_client.gd to that address (a local server,
## never the live portal) and expects HTTP 202.
##
## Run: godot --headless --path . --script res://tools/analytics_check.gd

const Catalog = preload("res://scripts/core/catalog.gd")
const GameState = preload("res://scripts/core/game_state.gd")
const SessionSim = preload("res://scripts/core/session_sim.gd")
const SessionReport = preload("res://scripts/core/session_report.gd")
const WeekRules = preload("res://scripts/core/week_rules.gd")
const RoutineRules = preload("res://scripts/core/routine_rules.gd")
const RunReport = preload("res://scripts/ui/run_report.gd")
const SignalsClient = preload("res://addons/hatchery/telemetry/signals_client.gd")
const SignalsConfig = preload("res://addons/hatchery/telemetry/signals_config.gd")
const ReportRules = preload("res://addons/hatchery/telemetry/report_rules.gd")
const JsonIo = preload("res://addons/hatchery/core/json_io.gd")
const AtomicFile = preload("res://addons/hatchery/storage/atomic_file.gd")
const LaunchArgs = preload("res://addons/hatchery/settings/launch_args.gd")

const CONFIG := "res://data/analytics.json"
const SOURCES: Array[String] = ["res://scripts/main.gd"]
const SEND_TIMEOUT := 20.0
const IDS_FILE := "user://analytics_check_ids.json"
const QUEUE_FILE := "user://analytics_check_queue.json"

var _failures: int = 0
var _catalog := Catalog.new()
var _client: SignalsClient
var _waited: float = 0.0
var _replies: Array[int] = []
var _sent: int = 0
var _expected: int = 0


func _initialize() -> void:
	if not _catalog.load_all():
		for error in _catalog.errors:
			print("DATA  ", error)
		quit(1)
		return
	var errors: Array[String] = []
	SignalsConfig.read(CONFIG, errors)
	for error in errors:
		_check(false, "config: %s" % error)
	_check_milestones()
	var reports: Array[Dictionary] = []
	for plan in ["completed", "abandoned"]:
		var game := GameState.new(_catalog)
		game.new_game(21 + reports.size())
		game.phase = "planner"
		var started: Dictionary = RunReport.started(game)
		var results: Array = _play(game, 1 if plan == "abandoned" else 99)
		_check((plan == "completed") == (game.phase == "done"), "%s: season phase is %s" % [plan, game.phase])
		var ended: Dictionary = RunReport.ended(game, results, plan, 900)
		for report in [started, ended]:
			for problem in ReportRules.problems(report):
				_check(false, "%s: %s" % [plan, problem])
			_check_round_trip(report, plan)
		for id: Variant in ended["clients"]:
			_check(game.client(str(id)) != null, "%s: '%s' is not a client" % [plan, id])
		reports.append(ended)
	print("analytics_check: seasons %s, goals met %s" % [str(reports.map(func(r: Dictionary) -> String: return "%s wk%d" % [r.outcome, r.wave])), str(reports[0].goals_met)])
	var endpoint: String = LaunchArgs.value("endpoint")
	if endpoint.is_empty():
		_finish()
		return
	# The client's HTTPRequest needs the running tree, which starts after this.
	_send.call_deferred(endpoint, reports)


## Plays up to `weeks` weeks with the suggested routines and a coach who
## presses the middle of every bar; returns the marathon's results, if run.
func _play(game: GameState, weeks: int) -> Array:
	for week in range(weeks):
		if game.phase != "planner":
			break
		WeekRules.begin_week(game)
		for state in game.clients:
			state.routine = RoutineRules.suggested(state, game.block().id, game)
			state.routine_block = game.block().id
			for day in state.def.available_days:
				if WeekRules.book(game, state, day):
					break
		for state in WeekRules.sessions(game):
			var sim := SessionSim.new(game, state, state.booked_day)
			while not sim.done:
				sim.press(0.5, true)
			SessionReport.apply(sim)
		var summary: Dictionary = WeekRules.end_week(game)
		if not summary.marathon.is_empty():
			return summary.marathon
	return []


## Every milestone_once("...") name is snake_case; formatted ones are checked
## with a sample number.
func _check_milestones() -> void:
	var call := RegEx.create_from_string("milestone_once\\(\"([^\"]*)\"")
	var snake := RegEx.create_from_string("^[a-z][a-z0-9]*(_[a-z0-9]+)*$")
	var found: int = 0
	for path in SOURCES:
		for result in call.search_all(FileAccess.get_file_as_string(path)):
			found += 1
			var name: String = result.get_string(1).replace("%d", "3")
			_check(snake.search(name) != null, "%s: milestone '%s' is not snake_case" % [path, name])
	_check(found >= 4, "found only %d milestones in %s" % [found, ", ".join(SOURCES)])


## Through the queue file's JSON and back: same report, counts still ints.
func _check_round_trip(report: Dictionary, where: String) -> void:
	var back: Variant = JsonIo.from_bytes(JsonIo.bytes({"data": report}))
	var restored: Dictionary = JsonIo.whole_numbers(back)["data"]
	_check(JSON.stringify(restored) == JSON.stringify(report), "%s: report changed through the queue file:
  %s
  %s" % [where, JSON.stringify(report), JSON.stringify(restored)])
	_check(restored["cash"] is int, "%s: cash came back as %s" % [where, type_string(typeof(restored["cash"]))])


func _process(delta: float) -> bool:
	if _client == null:
		return false
	_waited += delta
	if _sent >= _expected or _waited > SEND_TIMEOUT:
		_check(_sent == _expected, "only %d of %d events were answered" % [_sent, _expected])
		for code in _replies:
			_check(code == 202, "local endpoint answered %d, expected 202" % code)
		print("analytics_check: sent %d events in %d batches, HTTP %s" % [_sent, _replies.size(), str(_replies)])
		# Off first, so quitting does not queue (and save) a session end.
		_client.set_enabled(false)
		AtomicFile.remove_all(IDS_FILE)
		AtomicFile.remove_all(QUEUE_FILE)
		_finish()
	return false


func _send(endpoint: String, reports: Array[Dictionary]) -> void:
	AtomicFile.remove_all(IDS_FILE)
	AtomicFile.remove_all(QUEUE_FILE)
	_client = SignalsClient.new()
	_client.ids_path = IDS_FILE
	_client.queue_path = QUEUE_FILE
	_client.endpoint_override = endpoint
	_client.batch_sent.connect(func(code: int, count: int) -> void:
		_replies.append(code)
		_sent += count)
	var ended: Array[Dictionary] = []
	for report in reports:
		if report.has("outcome"):
			ended.append(report)
	# session_started, each ended report and the once-only first_run_finished milestone.
	_expected = 2 + ended.size()
	root.add_child(_client)
	_client.start(CONFIG, true, false, false)
	_check(_client.status != "", "client should stay off until enabled")
	_client.set_enabled(true)
	for report in ended:
		_client.run_ended(report)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		print("FAIL  ", message)


func _finish() -> void:
	print("analytics_check: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)
