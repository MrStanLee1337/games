class_name ZoneHud
extends Control
## HUD «Зоны: забег»: полоса HP, заряды рывка, иконки баффов с круговыми таймерами, ряд артефактов,
## расходники, время и попытка, подсказка по клавишам (H), всплывающие сообщения, экран финиша.

const HINTS := "A/D ← → — бег    Пробел/W — прыжок    S — подкат/ползком/перекат    Shift — рывок (тратит заряд)    E — подобрать    Q — лечение\nTab — рюкзак    S+Пробел — спрыгнуть с платформы    R — забег заново    H — скрыть    F1 — отладка    F2 — артефакты    Esc — выход"

var _inv: Inventory
var _player: Player
var _charge := 0
var _max_charge := 2
var _hp := 100.0
var _max_hp := 100.0
var _hints: Label
var _message: Label
var _msg_tween: Tween
var _time := 0.0
var _attempt := 1
var _finish_text := ""
var _finish_lines: Array[String] = []
# Полоса пути от А до Б: координаты, отрыв от волны (с), идёт ли волна, близость волны 0..1.
var _path := {"a": 0.0, "b": 1.0, "player": 0.0, "wave": 0.0, "gap": INF, "running": false, "danger": 0.0}
var _section_label := ""


func _ready() -> void:
	# Родитель — CanvasLayer, якоря не работают: раскладываем вручную по размеру окна.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints = Label.new()
	_hints.text = HINTS
	_hints.add_theme_font_size_override("font_size", 15)
	_hints.modulate = Color(1, 1, 1, 0.6)
	_hints.add_theme_constant_override("line_spacing", 2)
	add_child(_hints)
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 24)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0
	add_child(_message)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vp := get_viewport_rect().size
	_hints.position = Vector2(24.0, vp.y - 62.0)
	_message.size = Vector2(600.0, 36.0)
	_message.position = Vector2((vp.x - 600.0) * 0.5, 70.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"az_toggle_hints"):
		_hints.visible = not _hints.visible


func set_inventory(inv: Inventory) -> void:
	_inv = inv
	_inv.changed.connect(queue_redraw)
	queue_redraw()


func set_player(p: Player) -> void:
	_player = p
	p.buffs.changed.connect(queue_redraw)
	p.stats.changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	if _player and not _player.buffs.active.is_empty():
		queue_redraw()  # круговые таймеры баффов


func set_path(a: float, b: float, player_x: float, wave_x: float, gap: float, running: bool, danger: float) -> void:
	_path = {"a": a, "b": b, "player": player_x, "wave": wave_x, "gap": gap, "running": running, "danger": danger}
	queue_redraw()


func set_section_label(text: String) -> void:
	_section_label = text
	queue_redraw()


func set_time(t: float, attempt: int) -> void:
	_time = t
	_attempt = attempt
	queue_redraw()


func show_finish(t: float, hp: float, artifacts: Array[String]) -> void:
	_finish_text = "Забег пройден"
	_finish_lines = [
		"Время: %s     HP: %d" % [_fmt_time(t), int(ceilf(hp))],
		"Артефакты: " + (", ".join(artifacts) if not artifacts.is_empty() else "нет"),
	]
	queue_redraw()


func hide_finish() -> void:
	_finish_text = ""
	_finish_lines.clear()
	queue_redraw()


static func _fmt_time(t: float) -> String:
	return "%d:%04.1f" % [floori(t / 60.0), fmod(t, 60.0)]


func set_charge(value: int, max_value: int) -> void:
	_charge = value
	_max_charge = max_value
	queue_redraw()


func set_health(hp: float, max_hp: float) -> void:
	_hp = hp
	_max_hp = max_hp
	queue_redraw()


func show_message(text: String) -> void:
	_message.text = text
	if _msg_tween:
		_msg_tween.kill()
	_message.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(1.5)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.5)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	_draw_danger()
	_draw_path()
	var pos := Vector2(24.0, 24.0)
	var w := 260.0
	draw_rect(Rect2(pos, Vector2(w, 18.0)), Color(0, 0, 0, 0.5))
	var ratio := clampf(_hp / _max_hp, 0.0, 1.0)
	var col := Color("5ad17a").lerp(Color("ef6f6c"), 1.0 - ratio)
	draw_rect(Rect2(pos, Vector2(w * ratio, 18.0)), col)
	draw_string(font, pos + Vector2(6.0, 14.0), "HP %d" % int(ceilf(_hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.85))
	# Заряды рывка: деления справа от полосы HP.
	var x0 := pos.x + w + 12.0
	for i in _max_charge:
		var cr := Rect2(Vector2(x0 + i * 14.0, pos.y - 2.0), Vector2(10.0, 22.0))
		draw_rect(cr, Color(0, 0, 0, 0.5))
		if i < _charge:
			draw_rect(cr.grow(-2.0), Color("8fd3ff"))
	draw_string(font, Vector2(x0 + _max_charge * 14.0 + 6.0, pos.y + 14.0), "рывок", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
		Color("8fd3ff") if _charge > 0 else Color(1, 1, 1, 0.35))
	if _inv:
		var n := _inv.count_consumables()
		if n > 0:
			draw_string(font, Vector2(x0 + _max_charge * 14.0 + 60.0, pos.y + 14.0), "Q — лечение (%d)" % n,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.7))
	_draw_buffs(Vector2(42.0, 74.0))
	_draw_artifacts(Vector2(36.0, 122.0))
	var vp := get_viewport_rect().size
	draw_string(font, Vector2(vp.x - 324.0, 40.0), "%s   Попытка %d" % [_fmt_time(_time), _attempt], HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 20, Color(1, 1, 1, 0.8))
	if _finish_text != "":
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(0.0, vp.y * 0.5 - 30.0), _finish_text, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 52, Color("5ad17a"))
		for i in _finish_lines.size():
			draw_string(font, Vector2(0.0, vp.y * 0.5 + 20.0 + i * 32.0), _finish_lines[i], HORIZONTAL_ALIGNMENT_CENTER, vp.x, 24, Color("e8ecf4"))
		draw_string(font, Vector2(0.0, vp.y * 0.5 + 100.0), "R — новый забег     Esc — выход", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 16, Color(1, 1, 1, 0.6))


## Активные баффы: значок типа аномалии в круге, по краю — оставшееся время.
func _draw_buffs(start: Vector2) -> void:
	if _player == null:
		return
	var font := ThemeDB.fallback_font
	var c := start
	for id in _player.buffs.active:
		var info: Dictionary = AnomalyDb.BUFFS.get(id, {})
		var col: Color = info.get("color", Color.WHITE)
		draw_circle(c, 17.0, Color(0, 0, 0, 0.55))
		AnomalyDb.draw_type_icon(self, info.get("type", -1), c, 9.0, col)
		var frac := _player.buffs.fraction(id)
		draw_arc(c, 19.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, col, 3.0)
		draw_string(font, c + Vector2(-32.0, 34.0), String(info.get("name", String(id))),
			HORIZONTAL_ALIGNMENT_CENTER, 64.0, 11, Color(col, 0.9))
		c.x += 64.0


## Ряд иконок взятых артефактов (подробности — Tab).
func _draw_artifacts(start: Vector2) -> void:
	if _player == null or _player.stats.artifacts.is_empty():
		return
	var c := start
	for it in _player.stats.artifacts:
		draw_circle(c, 13.0, Color(0, 0, 0, 0.5))
		it.draw_icon(self, c, 18.0)
		c.x += 30.0
	draw_string(ThemeDB.fallback_font, Vector2(c.x - 4.0, start.y + 5.0), "Tab — билд", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(1, 1, 1, 0.45))


## Волна ближе ширины экрана — левый край краснеет, чем ближе, тем сильнее.
func _draw_danger() -> void:
	var d: float = _path["danger"]
	if d <= 0.0:
		return
	var vp := get_viewport_rect().size
	var w := 60.0 + 260.0 * d
	var cols := PackedColorArray([Color(0.8, 0.05, 0.05, 0.75 * d), Color(0.8, 0.05, 0.05, 0.0),
		Color(0.8, 0.05, 0.05, 0.0), Color(0.8, 0.05, 0.05, 0.75 * d)])
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0.0), Vector2(w, vp.y), Vector2(0.0, vp.y)]), cols)


## Полоса пути от А до Б сверху по центру: маркеры игрока и волны, отрыв в секундах.
func _draw_path() -> void:
	var font := ThemeDB.fallback_font
	var vp := get_viewport_rect().size
	var w := 420.0
	var x0 := (vp.x - w) * 0.5
	var y := 30.0
	var a: float = _path["a"]
	var b: float = maxf(_path["b"], a + 1.0)
	draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(1, 1, 1, 0.35), 4.0)
	draw_string(font, Vector2(x0 - 22.0, y + 5.0), "А", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
	draw_string(font, Vector2(x0 + w + 8.0, y + 5.0), "Б", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
	var px := x0 + w * clampf((_path["player"] - a) / (b - a), 0.0, 1.0)
	if _path["running"]:
		var wx := x0 + w * clampf((_path["wave"] - a) / (b - a), 0.0, 1.0)
		draw_line(Vector2(x0, y), Vector2(wx, y), Color(0.85, 0.15, 0.1, 0.9), 4.0)
		draw_colored_polygon(PackedVector2Array([Vector2(wx, y - 9.0), Vector2(wx + 6.0, y), Vector2(wx, y + 9.0),
			Vector2(wx - 4.0, y)]), Color("ff4a3a"))
	draw_colored_polygon(PackedVector2Array([Vector2(px - 6.0, y - 12.0), Vector2(px + 6.0, y - 12.0), Vector2(px, y - 3.0)]),
		Color.WHITE)
	var txt := _section_label
	if _path["running"]:
		var gap: float = _path["gap"]
		txt += ("   " if txt != "" else "") + "отрыв %.1f с" % gap
	if txt != "":
		var col := Color(1, 1, 1, 0.75) if _path["gap"] > 3.0 or not _path["running"] else Color("ff7a6a")
		draw_string(font, Vector2(x0, y + 24.0), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 14, col)
