extends RefCounted
## Buying equipment and memberships. Purchases are paid at once and arrive
## at the start of next week, so the player has to plan ahead.


## "" when `id` can be bought now, otherwise the reason it can't.
static func problem(game: RefCounted, id: String) -> String:
	if not game.catalog.shop_items.has(id):
		return "Not for sale."
	var item: Dictionary = game.catalog.shop_items[id]
	if game.owns(id):
		return "Already in the gym."
	if game.pending.has(id):
		return "Arriving next week."
	if game.reputation() < int(item.reputation):
		return "Needs reputation %d." % int(item.reputation)
	if game.cash < int(item.cost):
		return "Not enough money."
	if game.slots_used() + int(item.slots) > game.slots_total():
		return "No free equipment slot."
	return ""


static func buy(game: RefCounted, id: String) -> bool:
	if not problem(game, id).is_empty():
		return false
	game.cash -= int(game.catalog.shop_items[id].cost)
	game.pending.append(id)
	return true


## Undoes `buy` when the purchase could not be saved.
static func refund(game: RefCounted, id: String) -> void:
	if game.pending.has(id):
		game.pending.erase(id)
		game.cash += int(game.catalog.shop_items[id].cost)
