extends Control
## The equipment catalogue. Purchases are paid now and delivered at the
## start of next week; each piece of equipment takes one of the shed's slots.
const Style = preload("res://scripts/ui/style.gd")
const ShopRules = preload("res://scripts/core/shop_rules.gd")

signal buy(id: String)
signal closed

var game: RefCounted


func setup(owner: RefCounted) -> void:
	game = owner


func _ready() -> void:
	var column: VBoxContainer = Style.screen(self, 10, 28)
	var header: HBoxContainer = Style.ui.hbox(20)
	column.add_child(header)
	header.add_child(Style.ui.heading("Equipment catalogue", 30))
	header.add_child(Style.ui.spacer())
	header.add_child(Style.ui.utility("$%d" % game.cash, 22, Style.GREEN))
	header.add_child(Style.ui.label("Slots %d/%d  ·  Reputation %d" % [game.slots_used(), game.slots_total(), game.reputation()], 16))
	column.add_child(Style.ui.wrapped("Orders arrive at the start of next week. In the shed now: " + ", ".join(game.owned.map(func(id: String) -> String: return game.catalog.equipment_name(id))) + ".", 14))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list: VBoxContainer = Style.ui.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var first: Button = null
	for id in game.catalog.shop_order:
		var row: Array = _item_row(id)
		list.add_child(row[0])
		if first == null and row[1] != null and not row[1].disabled:
			first = row[1]
	var back: Button = Style.ui.button("Back to the planner", func() -> void: closed.emit(), first == null)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(back)
	(first if first != null else back).grab_focus.call_deferred()


## [panel, buy button or null]
func _item_row(id: String) -> Array:
	var item: Dictionary = game.catalog.shop_items[id]
	var panel: PanelContainer = Style.ui.panel(0.95, 10)
	var row: HBoxContainer = Style.ui.hbox(14)
	panel.add_child(row)
	var text: VBoxContainer = Style.ui.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var needs: String = "" if int(item.reputation) <= 1 else "  ·  needs reputation %d" % int(item.reputation)
	var slots: String = "  ·  uses a slot" if int(item.slots) > 0 else ""
	text.add_child(Style.ui.label("%s  —  $%d%s%s" % [item.name, int(item.cost), needs, slots], 17))
	text.add_child(Style.ui.wrapped(item.about, 14))
	if game.owns(id):
		row.add_child(Style.ui.label("In the shed", 15, Style.GREEN))
		return [panel, null]
	if game.pending.has(id):
		row.add_child(Style.ui.label("Arriving next week", 15, Style.ACCENT))
		return [panel, null]
	var problem: String = ShopRules.problem(game, id)
	if not problem.is_empty():
		row.add_child(Style.ui.label(problem, 14, Style.MUTED))
	var button: Button = Style.ui.button("Buy", func() -> void: buy.emit(id), problem.is_empty(), 16)
	button.disabled = not problem.is_empty()
	button.custom_minimum_size.x = 90
	row.add_child(button)
	return [panel, button]
