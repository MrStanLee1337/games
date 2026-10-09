class_name ZoneHud
extends Control
## HUD «Зоны». Пока: полоса HP, подсказка по клавишам (H), всплывающие сообщения.

const HINTS := "A/D ← → — бег    Пробел/W — прыжок    Shift — рывок (Вспышка)    F — болт    E — подобрать    Q — лечение    1/2/3 — слот, G — бросить (S+G — положить)\nS — подкат/ползком/перекат    Tab — инвентарь    S+Пробел — спрыгнуть с платформы    R — чекпоинт    H — скрыть    F1 — отладка    F2 — артефакты    Esc — выход"
const SLOT := 44.0

var _inv: Inventory
var _selected := 0
var _charge := 0
var _max_charge := 3
var _hp := 100.0
var _max_hp := 100.0
var _hints: Label
var _message: Label
var _msg_tween: Tween
var _time := 0.0
var _deaths := 0
var _finish_text := ""
var _finish_sub := ""


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


func set_time(t: float, deaths: int) -> void:
	_time = t
	_deaths = deaths
	queue_redraw()


func show_finish(t: float, deaths: int) -> void:
	_finish_text = "Прототип пройден"
	_finish_sub = "Время: %s     Смертей: %d" % [_fmt_time(t), deaths]
	queue_redraw()


static func _fmt_time(t: float) -> String:
	return "%d:%04.1f" % [floori(t / 60.0), fmod(t, 60.0)]


func set_charge(value: int, max_value: int) -> void:
	_charge = value
	_max_charge = max_value
	queue_redraw()


func set_selected(idx: int) -> void:
	_selected = idx
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
	var pos := Vector2(24.0, 24.0)
	var w := 260.0
	draw_rect(Rect2(pos, Vector2(w, 18.0)), Color(0, 0, 0, 0.5))
	var ratio := clampf(_hp / _max_hp, 0.0, 1.0)
	var col := Color("5ad17a").lerp(Color("ef6f6c"), 1.0 - ratio)
	draw_rect(Rect2(pos, Vector2(w * ratio, 18.0)), col)
	draw_string(ThemeDB.fallback_font, pos + Vector2(6.0, 14.0), "HP %d" % int(ceilf(_hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.85))
	_draw_belt()
	var font := ThemeDB.fallback_font
	var vp := get_viewport_rect().size
	draw_string(font, Vector2(vp.x - 324.0, 40.0), "%s   Смертей: %d" % [_fmt_time(_time), _deaths], HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 20, Color(1, 1, 1, 0.8))
	if _finish_text != "":
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.55))
		draw_string(font, Vector2(0.0, vp.y * 0.5 - 20.0), _finish_text, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 52, Color("5ad17a"))
		draw_string(font, Vector2(0.0, vp.y * 0.5 + 30.0), _finish_sub, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 26, Color("e8ecf4"))
		draw_string(font, Vector2(0.0, vp.y * 0.5 + 76.0), "R — вернуться на чекпоинт     Esc — выход", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 16, Color(1, 1, 1, 0.6))


func _draw_belt() -> void:
	if _inv == null:
		return
	var font := ThemeDB.fallback_font
	for i in _inv.belt.size():
		var r := Rect2(Vector2(24.0 + i * (SLOT + 8.0), 52.0), Vector2(SLOT, SLOT))
		draw_rect(r, Color(0, 0, 0, 0.5))
		if i == _selected:
			draw_rect(r, Color("f2c14e"), false, 2.5)
		else:
			draw_rect(r, Color(1, 1, 1, 0.25), false, 2.0)
		draw_string(font, r.position + Vector2(3.0, 12.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))
		var it := _inv.belt[i]
		if it:
			it.draw_icon(self, r.get_center(), SLOT * 0.55)
	# Заряд Батарейки: деления справа от пояса.
	if _charge > 0:
		var x0 := 24.0 + _inv.belt.size() * (SLOT + 8.0) + 4.0
		for i in _max_charge:
			var cr := Rect2(Vector2(x0 + i * 14.0, 58.0), Vector2(10.0, 32.0))
			draw_rect(cr, Color(0, 0, 0, 0.5))
			if i < _charge:
				draw_rect(cr.grow(-2.0), Color("ffe46b"))
		draw_string(font, Vector2(x0, 52.0 + SLOT + 20.0), "заряд: Shift", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffe46b"))
	var n := _inv.count_consumables()
	if n > 0:
		draw_string(font, Vector2(24.0, 52.0 + SLOT + 20.0), "Q — лечение (%d)" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
