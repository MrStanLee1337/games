class_name ZoneHud
extends Control
## HUD «Зоны». Пока: полоса HP, подсказка по клавишам (H), всплывающие сообщения.

const HINTS := "A/D ← → — бег    Пробел/W — прыжок    Shift — рывок    R — к чекпоинту    H — скрыть подсказку    Esc — выход"

var _hp := 100.0
var _max_hp := 100.0
var _hints: Label
var _message: Label
var _msg_tween: Tween


func _ready() -> void:
	# Родитель — CanvasLayer, якоря не работают: раскладываем вручную по размеру окна.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints = Label.new()
	_hints.text = HINTS
	_hints.add_theme_font_size_override("font_size", 15)
	_hints.modulate = Color(1, 1, 1, 0.6)
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
	_hints.position = Vector2(24.0, vp.y - 40.0)
	_message.size = Vector2(600.0, 36.0)
	_message.position = Vector2((vp.x - 600.0) * 0.5, 70.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"az_toggle_hints"):
		_hints.visible = not _hints.visible


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
