class_name ZoneHud
extends Control
## HUD «Зоны: забег»: полоса HP, заряды рывка, расходники, время и попытка, подсказка по клавишам (H),
## всплывающие сообщения, экран финиша.

const HINTS := "A/D ← → — бег    Пробел/W — прыжок    S — подкат/ползком/перекат    Shift — рывок (тратит заряд)    E — подобрать    Q — лечение\nTab — рюкзак    S+Пробел — спрыгнуть с платформы    R — забег заново    H — скрыть    F1 — отладка    F2 — артефакты    Esc — выход"

var _inv: Inventory
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
			draw_string(font, pos + Vector2(0.0, 40.0), "Q — лечение (%d)" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
	var vp := get_viewport_rect().size
	draw_string(font, Vector2(vp.x - 324.0, 40.0), "%s   Попытка %d" % [_fmt_time(_time), _attempt], HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 20, Color(1, 1, 1, 0.8))
	if _finish_text != "":
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(0.0, vp.y * 0.5 - 30.0), _finish_text, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 52, Color("5ad17a"))
		for i in _finish_lines.size():
			draw_string(font, Vector2(0.0, vp.y * 0.5 + 20.0 + i * 32.0), _finish_lines[i], HORIZONTAL_ALIGNMENT_CENTER, vp.x, 24, Color("e8ecf4"))
		draw_string(font, Vector2(0.0, vp.y * 0.5 + 100.0), "R — новый забег     Esc — выход", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 16, Color(1, 1, 1, 0.6))
