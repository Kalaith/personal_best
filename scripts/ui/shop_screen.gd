extends Control
## The equipment catalogue. Purchases are paid now and delivered at the
## start of next week; each piece of equipment takes one of the shed's slots.
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const ShopRules = preload("res://scripts/core/shop_rules.gd")

signal buy(id: String)
signal closed

var game: RefCounted


func setup(owner: RefCounted) -> void:
	game = owner


func _ready() -> void:
	var column: VBoxContainer = Style.screen(self, 12, 22)
	var header: HBoxContainer = Style.ui.hbox(20)
	column.add_child(header)
	header.add_child(Style.ui.heading("Equipment catalogue", 30))
	header.add_child(Style.ui.spacer())
	header.add_child(Widgets.resource_value("Budget", "$%d" % game.cash, Style.GREEN))
	header.add_child(Widgets.resource_value("Reputation", str(game.reputation())))
	var overview: HBoxContainer = Style.ui.hbox(20)
	overview.add_child(Style.ui.label("Delivery · start of next week", 15, Style.MUTED))
	overview.add_child(Style.ui.spacer())
	var inventory: HBoxContainer = Widgets.resource_value("Kit slots", "%d / %d" % [game.slots_used(), game.slots_total()])
	inventory.tooltip_text = "In the shed: " + ", ".join(game.owned.map(func(id: String) -> String: return game.catalog.equipment_name(id)))
	inventory.mouse_filter = Control.MOUSE_FILTER_PASS
	overview.add_child(inventory)
	column.add_child(overview)
	column.add_child(Widgets.section_label("Equipment & upgrades"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list: VBoxContainer = Style.ui.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var first: Button = null
	var later: Array = []
	for id in game.catalog.shop_order:
		if ShopRules.is_future(game, id):
			later.append(id)
			continue
		var row: Array = _item_row(id)
		list.add_child(row[0])
		if first == null and row[1] != null and not row[1].disabled:
			first = row[1]
	if not later.is_empty():
		list.add_child(Widgets.section_label("Later seasons"))
		for id in later:
			list.add_child(_item_row(id)[0])
	var back: Button = Style.ui.button("Back to the planner", func() -> void: closed.emit(), first == null)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(back)
	(first if first != null else back).grab_focus.call_deferred()


## [panel, buy button or null]
func _item_row(id: String) -> Array:
	var item: Dictionary = game.catalog.shop_items[id]
	var panel: PanelContainer = Style.ui.panel(0.95, 14)
	var row: HBoxContainer = Style.ui.hbox(24)
	panel.add_child(row)
	var text: VBoxContainer = Style.ui.vbox(6)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title: HBoxContainer = Style.ui.hbox(14)
	title.add_child(Style.ui.label(item.name, 18))
	var requirements: String = "%d slot%s" % [int(item.slots), "" if int(item.slots) == 1 else "s"] if int(item.slots) > 0 else "No kit slot"
	if int(item.reputation) > 1:
		requirements += " · Rep %d" % int(item.reputation)
	title.add_child(Style.ui.label(requirements, 14, Style.MUTED))
	text.add_child(title)
	text.add_child(Style.ui.wrapped(item.about, 14))
	var action: VBoxContainer = Style.ui.vbox(4)
	action.custom_minimum_size.x = 220
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(action)
	if game.owns(id):
		action.add_child(_status("✓ In the shed", Style.GREEN))
		return [panel, null]
	if game.pending.has(id):
		action.add_child(_status("Arriving next week", Style.ACCENT))
		return [panel, null]
	if ShopRules.is_future(game, id):
		action.add_child(_status("Coming later", Style.MUTED))
		return [panel, null]
	var problem: String = ShopRules.problem(game, id)
	var button: Button = Style.ui.button("Buy · $%d" % int(item.cost), func() -> void: buy.emit(id), problem.is_empty(), 16)
	button.disabled = not problem.is_empty()
	button.tooltip_text = problem if not problem.is_empty() else "Order %s for delivery next week" % item.name
	action.add_child(button)
	if not problem.is_empty():
		action.add_child(_status(problem, Style.MUTED))
	return [panel, button]


func _status(value: String, colour: Color) -> Label:
	var label: Label = Style.ui.wrapped(value, 14, colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
