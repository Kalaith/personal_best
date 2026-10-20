extends RefCounted
## The whole campaign: the calendar, the money, the gym and the clients.
## Rules modules change it; screens only read it and call those rules.
const Balance = preload("res://addons/hatchery/core/balance.gd")
const ClientState = preload("res://scripts/core/client_state.gd")
const Catalog = preload("res://scripts/core/catalog.gd")

## "intake" while clients are walking in, "planner" for the 12 weeks,
## "done" once the marathon has been run.
var phase: String = "intake"
var week: int = 1
var cash: int = 0
var rep_points: int = 0
var campaign_seed: int = 0
## Equipment and memberships the gym has, starting kit included.
var owned: Array = []
## Purchases arriving at the start of next week.
var pending: Array = []
var weather: String = "sunny"
var clients: Array[ClientState] = []
## How many clients have finished their intake.
var intake_done: int = 0
## Short notes from finished weeks, newest last, for the planner's log.
var notes: Array = []
var catalog: Catalog


func _init(source: Catalog) -> void:
	catalog = source


func new_game(seed_value: int) -> void:
	phase = "intake"
	week = 1
	cash = Balance.integer("campaign.start_cash")
	rep_points = 0
	campaign_seed = seed_value
	owned = catalog.starting_equipment.map(func(item: Dictionary) -> String: return item.id)
	pending = []
	notes = []
	intake_done = 0
	clients.clear()
	for entry in catalog.clients:
		var state := ClientState.new()
		state.setup(entry)
		clients.append(state)


func client(id: String) -> ClientState:
	for state in clients:
		if state.id == id:
			return state
	return null


func reputation() -> int:
	var level: int = 1 + int(floor(float(maxi(rep_points, 0)) / Balance.number("income.rep_points_per_level")))
	return mini(level, Balance.integer("income.max_reputation"))


func has_effect(effect: String) -> bool:
	for id in owned:
		if catalog.shop_items.has(id) and (catalog.shop_items[id].effects as Array).has(effect):
			return true
	return false


func owns(id: String) -> bool:
	return owned.has(id)


func capacity() -> int:
	var total: int = Balance.integer("gym.base_capacity")
	for id in owned:
		if catalog.shop_items.has(id):
			total += int(catalog.shop_items[id].get("clients", 0))
	return total


func slots_total() -> int:
	var total: int = Balance.integer("gym.base_slots")
	for id in owned:
		if catalog.shop_items.has(id):
			total += int(catalog.shop_items[id].get("extra_slots", 0))
	return total


func slots_used() -> int:
	var used: int = 0
	for id in owned + pending:
		used += _slots_of(id)
	return used


func _slots_of(id: String) -> int:
	if catalog.shop_items.has(id):
		return int(catalog.shop_items[id].slots)
	for item in catalog.starting_equipment:
		if item.id == id:
			return int(item.slots)
	return 0


## The training block a week belongs to: {id, name, first_week, last_week, push_on_amber}.
func block_for(week_number: int) -> Dictionary:
	for block in Balance.list("campaign.blocks"):
		if week_number >= int(block.first_week) and week_number <= int(block.last_week):
			return block
	return Balance.list("campaign.blocks").back()


func block() -> Dictionary:
	return block_for(week)


func weather_kind() -> Dictionary:
	for kind in Balance.list("weather.kinds"):
		if kind.id == weather:
			return kind
	return {}


func bad_weather() -> bool:
	return bool(weather_kind().get("bad", false))


## The mini goal that ends `week_number`, or {}.
func milestone_for(week_number: int) -> Dictionary:
	for milestone in Balance.list("milestones"):
		if int(milestone.week) == week_number:
			return milestone
	return {}


func next_milestone() -> Dictionary:
	for milestone in Balance.list("milestones"):
		if int(milestone.week) >= week:
			return milestone
	return {}


func session_fee(state: ClientState) -> int:
	var step: float = Balance.number("income.reputation_fee_step")
	return int(round(float(state.def.fee) * (1.0 + step * float(reputation() - 1))))


## The generator for one named stream of one week, so replaying a week from a
## save gives the same rolls and adding draws elsewhere does not shift them.
func rng_for(stream: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([campaign_seed, week, stream])
	return rng


func to_dict() -> Dictionary:
	return {
		"phase": phase,
		"week": week,
		"cash": cash,
		"rep_points": rep_points,
		"seed": campaign_seed,
		"owned": owned.duplicate(),
		"pending": pending.duplicate(),
		"weather": weather,
		"intake_done": intake_done,
		"notes": notes.duplicate(),
		"clients": clients.map(func(state: ClientState) -> Dictionary: return state.to_dict()),
	}


func restore(data: Dictionary) -> void:
	phase = data.phase
	week = int(data.week)
	cash = int(data.cash)
	rep_points = int(data.rep_points)
	campaign_seed = int(data.seed)
	owned = (data.owned as Array).duplicate()
	pending = (data.pending as Array).duplicate()
	weather = data.weather
	intake_done = int(data.intake_done)
	notes = (data.notes as Array).duplicate()
	clients.clear()
	for entry in data.clients:
		var state := ClientState.new()
		state.restore(entry, catalog.client(entry.id))
		clients.append(state)
