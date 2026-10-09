class_name InventoryWindow
extends Control
## Экран билда (Tab). Игра на паузе. Слева — рюкзак с расходниками (ЛКМ — переложить, ПКМ — применить)
## и итоговые статы; справа — взятые артефакты с плюсами и минусами (действуют все сразу).

const PANEL := Vector2(1120.0, 620.0)
const CELL := 60.0
const GAP := 8.0
const C_PANEL := Color("1d2027")
const C_SLOT := Color("2a2f3b")
const C_BORDER := Color("4f596e")
const C_PLUS := Color("7be08a")
const C_MINUS := Color("ef7a6c")

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
		elif not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed(&"az_exit"):
		close()
		get_viewport().set_input_as_handled()


func _origin() -> Vector2:
	return ((size - PANEL) * 0.5).max(Vector2.ZERO)


func _slot_rect(idx: int) -> Rect2:
	var o := _origin()
	var col := idx % Inventory.BACKPACK_COLS
	var row := idx / Inventory.BACKPACK_COLS
	return Rect2(o + Vector2(32.0 + col * (CELL + GAP), 104.0 + row * (CELL + GAP)), Vector2(CELL, CELL))


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
	draw_string(font, o + Vector2(32, 50), "Билд", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(font, o + Vector2(32, 90), "Рюкзак: расходники", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.7))
	for i in _inv.backpack.size():
		_draw_slot(i)
	_draw_stats(o + Vector2(32.0, 330.0))
	_draw_artifacts(o + Vector2(360.0, 90.0))
	draw_string(font, o + Vector2(32, PANEL.y - 20), "ЛКМ — переложить, ПКМ — применить расходник.   Tab / Esc — закрыть",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.5))
	_draw_tooltip(_inv.get_item(_hover))


## Итоговые статы: конфиг × артефакты (без временных баффов).
func _draw_stats(pos: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var st := _player.stats
	var cfg := _player.config
	var dz := AnomalyDb.get_data(Anomaly.Type.ZHARKA)
	var dt := AnomalyDb.get_data(Anomaly.Type.TRAMPLIN)
	var dv := AnomalyDb.get_data(Anomaly.Type.VORONKA)
	var dk := AnomalyDb.get_data(Anomaly.Type.KHOLODETS)
	var lines: Array[String] = [
		"Макс. HP %d,  зарядов рывка до %d" % [int(st.max_hp()), st.max_charges()],
		"Бег %d px/с,  прыжок ×%s,  гравитация ×%s" % [int(cfg.run_speed * st.run_mult()), _n(st.jump_mult()), _n(st.gravity_mult())],
		"Форсаж: бег ×%s на %s с" % [_n(1.0 + (dz["strength"] - 1.0) * st.buff_mult(Anomaly.Type.ZHARKA)),
			_n(dz["duration"] * st.buff_duration_mult(Anomaly.Type.ZHARKA))],
		"Трамплин: подброс %d px" % int(dt["launch"] * st.buff_mult(Anomaly.Type.TRAMPLIN)),
		"Праща: до %d px/с" % int(cfg.run_speed * dv["cap"] * st.buff_mult(Anomaly.Type.VORONKA)),
		"Холодец: +%s HP/с, бег ×%s" % [_n(dk["heal"] * st.heal_mult()), _n(minf(1.0, dk["run"] * st.buff_mult(Anomaly.Type.KHOLODETS)))],
	]
	var dmg: Array[String] = []
	for t in [Anomaly.Type.ZHARKA, Anomaly.Type.TRAMPLIN, Anomaly.Type.ELECTRA, Anomaly.Type.VORONKA]:
		var k := st.damage_mult(t)
		if not is_equal_approx(k, 1.0):
			dmg.append("%s ×%s" % [ArtifactDb.ANOMALY_NAMES[t], _n(k)])
	lines.append("Урон: " + (", ".join(dmg) if not dmg.is_empty() else "обычный"))
	if st.flag(&"no_stun") != null:
		lines.append("Электра не оглушает")
	draw_string(font, pos, "Итог", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
	for i in lines.size():
		draw_string(font, pos + Vector2(0.0, 26.0 + i * 22.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 300.0, 14, Color("d6dbe6"))


## Взятые артефакты: значок, имя (редкие — золотом), плюс, минус, тег.
func _draw_artifacts(pos: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var arts := _player.stats.artifacts
	draw_string(font, pos, "Артефакты (%d) — действуют все сразу, выбросить нельзя" % arts.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(1, 1, 1, 0.7))
	if arts.is_empty():
		draw_string(font, pos + Vector2(0.0, 34.0), "пока нет — артефакты лежат в тайниках (E)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Color(1, 1, 1, 0.45))
		return
	var y := pos.y + 24.0
	for it in arts:
		var c := Vector2(pos.x + 18.0, y + 22.0)
		draw_circle(c, 17.0, Color(0, 0, 0, 0.4))
		it.draw_icon(self, c, 24.0)
		var name_col := Color("ffd24a") if it.rarity == &"rare" else it.color.lightened(0.3)
		draw_string(font, Vector2(pos.x + 44.0, y + 14.0), "%s   · %s%s" % [it.display_name, ArtifactDb.tag_name(it.tag),
			", редкий" if it.rarity == &"rare" else ""], HORIZONTAL_ALIGNMENT_LEFT, 680.0, 16, name_col)
		draw_string(font, Vector2(pos.x + 44.0, y + 32.0), "+ " + it.plus, HORIZONTAL_ALIGNMENT_LEFT, 680.0, 13, C_PLUS)
		draw_string(font, Vector2(pos.x + 44.0, y + 48.0), "− " + it.minus, HORIZONTAL_ALIGNMENT_LEFT, 680.0, 13, C_MINUS)
		y += 60.0


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


static func _n(v: float) -> String:
	return ArtifactDb._num(snappedf(v, 0.01))
