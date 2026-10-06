class_name InventoryWindow
extends Control
## Окно инвентаря (Tab). Игра на паузе. Предметы переносятся кликом:
## ЛКМ — выбрать, затем ЛКМ по слоту — переложить/поменять местами; ПКМ — применить расходник
## или перекинуть артефакт между рюкзаком и поясом.

const PANEL := Vector2(800.0, 440.0)
const CELL := 72.0
const GAP := 8.0
const BELT_CELL := 84.0
const BELT_GAP := 12.0
const C_PANEL := Color("1d2027")
const C_SLOT := Color("2a2f3b")
const C_BORDER := Color("4f596e")

var _inv: Inventory
var _player: Player
var _hover := Vector2i(-1, -1)
var _sel := Vector2i(-1, -1)
var _note := ""
var _note_t := 0.0


func setup(inv: Inventory, player: Player) -> void:
	_inv = inv
	_player = player
	_inv.changed.connect(queue_redraw)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # работает, пока игра на паузе
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func open() -> void:
	_sel = Vector2i(-1, -1)
	_hover = Vector2i(-1, -1)
	_note = ""
	_layout()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"az_inventory"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"az_exit"):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _note_t > 0.0:
		_note_t -= delta
		if _note_t <= 0.0:
			_note = ""
		queue_redraw()


# --- Геометрия -------------------------------------------------------------

func _origin() -> Vector2:
	return (size - PANEL) * 0.5


func _slot_rect(zone: int, idx: int) -> Rect2:
	var o := _origin()
	if zone == Inventory.Zone.BELT:
		var bx := o.x + 440.0 + idx * (BELT_CELL + BELT_GAP)
		return Rect2(Vector2(bx, o.y + 130.0), Vector2(BELT_CELL, BELT_CELL))
	var col := idx % Inventory.BACKPACK_COLS
	var row := idx / Inventory.BACKPACK_COLS
	return Rect2(o + Vector2(40.0 + col * (CELL + GAP), 130.0 + row * (CELL + GAP)), Vector2(CELL, CELL))


func _slot_at(pos: Vector2) -> Vector2i:
	for zone in [Inventory.Zone.BACKPACK, Inventory.Zone.BELT]:
		for i in _inv.slots(zone).size():
			if _slot_rect(zone, i).has_point(pos):
				return Vector2i(zone, i)
	return Vector2i(-1, -1)


func _item_at(s: Vector2i) -> ItemData:
	if s.x < 0:
		return null
	return _inv.get_item(s.x as Inventory.Zone, s.y)


# --- Ввод ------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm:
		var h := _slot_at(mm.position)
		_hover = h
		queue_redraw()  # подсказка следует за курсором
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var s := _slot_at(mb.position)
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_left_click(s)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_right_click(s)
	queue_redraw()


func _left_click(s: Vector2i) -> void:
	if s.x < 0:
		_sel = Vector2i(-1, -1)
	elif _sel.x < 0:
		if _item_at(s) != null:
			_sel = s
	elif s == _sel:
		_sel = Vector2i(-1, -1)
	else:
		if not _inv.swap(_sel.x as Inventory.Zone, _sel.y, s.x as Inventory.Zone, s.y):
			_flash("На пояс можно класть только артефакты")
		_sel = Vector2i(-1, -1)


func _right_click(s: Vector2i) -> void:
	var it := _item_at(s)
	if it == null:
		return
	_sel = Vector2i(-1, -1)
	if it.kind == ItemData.Kind.CONSUMABLE:
		_player.use_item(s.x as Inventory.Zone, s.y)
	elif not _inv.quick_move(s.x as Inventory.Zone, s.y):
		_flash("Нет свободного места")


func _flash(text: String) -> void:
	_note = text
	_note_t = 1.8


# --- Отрисовка -------------------------------------------------------------

func _draw() -> void:
	if _inv == null or not visible:
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var o := _origin()
	draw_rect(Rect2(o, PANEL), C_PANEL)
	draw_rect(Rect2(o, PANEL), C_BORDER, false, 2.0)
	draw_string(font, o + Vector2(40, 48), "Инвентарь", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(font, o + Vector2(40, 112), "Рюкзак", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))
	draw_string(font, o + Vector2(440, 112), "Пояс — действуют только артефакты отсюда", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))
	for zone in [Inventory.Zone.BACKPACK, Inventory.Zone.BELT]:
		var cell := BELT_CELL if zone == Inventory.Zone.BELT else CELL
		for i in _inv.slots(zone).size():
			_draw_slot(zone, i, cell)
	draw_multiline_string(font, o + Vector2(440, 252), "ЛКМ — выбрать, затем кликнуть в слот: переложить или поменять местами.", HORIZONTAL_ALIGNMENT_LEFT, 330, 14, -1, Color(1, 1, 1, 0.55))
	draw_multiline_string(font, o + Vector2(440, 304), "ПКМ — применить расходник или перекинуть артефакт между рюкзаком и поясом.", HORIZONTAL_ALIGNMENT_LEFT, 330, 14, -1, Color(1, 1, 1, 0.55))
	draw_string(font, o + Vector2(40, PANEL.y - 24), "Tab / Esc — закрыть", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.55))
	if _note != "":
		draw_string(font, o + Vector2(440, PANEL.y - 24), _note, HORIZONTAL_ALIGNMENT_LEFT, 330, 15, Color("ef6f6c"))
	_draw_tooltip(_item_at(_hover))


func _draw_slot(zone: int, idx: int, cell: float) -> void:
	var r := _slot_rect(zone, idx)
	var s := Vector2i(zone, idx)
	draw_rect(r, C_SLOT)
	var border := C_BORDER
	if s == _sel:
		border = Color("f2c14e")
	elif s == _hover:
		border = Color("aab1c2")
	draw_rect(r, border, false, 3.0 if s == _sel else 2.0)
	var it := _inv.get_item(zone as Inventory.Zone, idx)
	if it:
		it.draw_icon(self, r.get_center(), cell * 0.5)


func _draw_tooltip(it: ItemData) -> void:
	if it == null:
		return
	var font := ThemeDB.fallback_font
	var w := 280.0
	var pad := 12.0
	var lines: Array[String] = []
	if it.kind == ItemData.Kind.ARTIFACT:
		lines = ArtifactDb.describe(it)
	var desc_h := font.get_multiline_string_size(it.description, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, 14).y
	var h := pad * 2.0 + 24.0 + desc_h + lines.size() * 20.0 + (8.0 if not lines.is_empty() else 0.0)
	var pos := get_local_mouse_position() + Vector2(18.0, 18.0)
	pos.x = minf(pos.x, size.x - w - 8.0)
	pos.y = minf(pos.y, size.y - h - 8.0)
	draw_rect(Rect2(pos, Vector2(w, h)), Color("12141a"))
	draw_rect(Rect2(pos, Vector2(w, h)), it.color, false, 2.0)
	var y := pos.y + pad + 16.0
	draw_string(font, Vector2(pos.x + pad, y), it.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, it.color.lightened(0.3))
	y += 8.0
	draw_multiline_string(font, Vector2(pos.x + pad, y + 14.0), it.description, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, 14, -1, Color(1, 1, 1, 0.85))
	y += desc_h + 8.0
	for l in lines:
		y += 20.0
		draw_string(font, Vector2(pos.x + pad, y), l, HORIZONTAL_ALIGNMENT_LEFT, w - pad * 2.0, 14, Color("e8ecf4"))
