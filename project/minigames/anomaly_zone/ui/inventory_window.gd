class_name InventoryWindow
extends Control
## Окно рюкзака (Tab). Игра на паузе. ЛКМ — выбрать расходник, затем ЛКМ по клетке — переложить;
## ПКМ — применить расходник. Справа — взятые артефакты (действуют все сразу, выбросить нельзя).

const PANEL := Vector2(800.0, 440.0)
const CELL := 72.0
const GAP := 8.0
const C_PANEL := Color("1d2027")
const C_SLOT := Color("2a2f3b")
const C_BORDER := Color("4f596e")

var _inv: Inventory
var _player: Player
var _hover := -1
var _sel := -1


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
	_sel = -1
	_hover = -1
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


func _origin() -> Vector2:
	return (size - PANEL) * 0.5


func _slot_rect(idx: int) -> Rect2:
	var o := _origin()
	var col := idx % Inventory.BACKPACK_COLS
	var row := idx / Inventory.BACKPACK_COLS
	return Rect2(o + Vector2(40.0 + col * (CELL + GAP), 130.0 + row * (CELL + GAP)), Vector2(CELL, CELL))


func _slot_at(pos: Vector2) -> int:
	for i in _inv.backpack.size():
		if _slot_rect(i).has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	var mm := event as InputEventMouseMotion
	if mm:
		_hover = _slot_at(mm.position)
		queue_redraw()  # подсказка следует за курсором
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var s := _slot_at(mb.position)
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if s < 0 or s == _sel:
			_sel = -1
		elif _sel < 0:
			if _inv.get_item(s) != null:
				_sel = s
		else:
			_inv.swap(_sel, s)
			_sel = -1
	elif mb.button_index == MOUSE_BUTTON_RIGHT and s >= 0:
		_sel = -1
		_player.use_item(s)
	queue_redraw()


func _draw() -> void:
	if _inv == null or not visible:
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var o := _origin()
	draw_rect(Rect2(o, PANEL), C_PANEL)
	draw_rect(Rect2(o, PANEL), C_BORDER, false, 2.0)
	draw_string(font, o + Vector2(40, 48), "Рюкзак", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(font, o + Vector2(40, 112), "Расходники", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))
	draw_string(font, o + Vector2(440, 112), "Артефакты — действуют все сразу", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))
	for i in _inv.backpack.size():
		_draw_slot(i)
	var arts := _player.stats.artifacts
	if arts.is_empty():
		draw_string(font, o + Vector2(440, 150), "пока нет", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.45))
	for i in arts.size():
		var it := arts[i]
		var c := o + Vector2(460.0, 150.0 + i * 36.0)
		it.draw_icon(self, c, 24.0)
		draw_string(font, c + Vector2(24.0, 6.0), it.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, it.color.lightened(0.3))
	draw_multiline_string(font, o + Vector2(40, 390), "ЛКМ — выбрать и переложить, ПКМ — применить расходник.", HORIZONTAL_ALIGNMENT_LEFT, 330, 14, -1, Color(1, 1, 1, 0.55))
	draw_string(font, o + Vector2(440, PANEL.y - 24), "Tab / Esc — закрыть", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.55))
	_draw_tooltip(_inv.get_item(_hover))


func _draw_slot(idx: int) -> void:
	var r := _slot_rect(idx)
	draw_rect(r, C_SLOT)
	var border := C_BORDER
	if idx == _sel:
		border = Color("f2c14e")
	elif idx == _hover:
		border = Color("aab1c2")
	draw_rect(r, border, false, 3.0 if idx == _sel else 2.0)
	var it := _inv.get_item(idx)
	if it:
		it.draw_icon(self, r.get_center(), CELL * 0.5)


func _draw_tooltip(it: ItemData) -> void:
	if it == null:
		return
	var font := ThemeDB.fallback_font
	var w := 280.0
	var pad := 12.0
	var lines := ArtifactDb.describe(it)
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
