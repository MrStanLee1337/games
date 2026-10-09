class_name ZoneHud
extends Control
## HUD «Зоны»: полоса HP, пояс, груз с порогами и потерянными приёмами, подсказка по клавишам (H),
## всплывающие сообщения.

const HINTS := "A/D ← → — бег    Пробел/W — прыжок    Shift — рывок (Вспышка)    F — болт    E — подобрать    Q — лечение    1/2/3 — слот, G — бросить (S+G — положить)\nS — подкат/ползком/перекат    Tab — инвентарь    S+Пробел — спрыгнуть с платформы    R — чекпоинт    H — скрыть    F1 — отладка    F2 — артефакты    Esc — выход\nCtrl — тихий шаг    X — детектор в руке (Пробел убирает и прыгает)"
const SLOT := 44.0
const TIER_COLORS := [Color("5ad17a"), Color("f2c14e"), Color("ff8a2b"), Color("ef4f4f")]
const MOVE_ORDER: Array[StringName] = [&"wall_jump", &"air_dash", &"slide", &"grab", &"dash"]
const MOVE_SHORT := {
	&"wall_jump": "отскок", &"air_dash": "рывок в возд.", &"slide": "подкат", &"grab": "зацеп", &"dash": "рывок",
}
## Сколько секунд мигает иконка приёма и подпись порога после перехода.
const BLINK := 1.2

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
var _player: Player
var _lost: Array[StringName] = []
## id приёма → сколько ещё мигать (потерян — красным, вернулся — зелёным).
var _blink: Dictionary = {}
var _tier := 0
var _tier_blink := 0.0


func _ready() -> void:
	# Родитель — CanvasLayer, якоря не работают: раскладываем вручную по размеру окна.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
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
	_hints.position = Vector2(24.0, vp.y - 82.0)
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
	_tier = p.m.tier
	_lost = p.lost_moves()
	p.load_changed.connect(_on_load_changed)
	queue_redraw()


func _on_load_changed(_kg: float, _eff: float, tier: MovementConfig.Tier) -> void:
	var lost := _player.lost_moves()
	for id in lost:
		if id not in _lost:
			_blink[id] = BLINK
	for id in _lost:
		if id not in lost:
			_blink[id] = BLINK
	if tier != _tier:
		_tier_blink = BLINK
	_tier = tier
	_lost = lost
	set_process(not _blink.is_empty() or _tier_blink > 0.0)
	queue_redraw()


func _process(delta: float) -> void:
	for id in _blink.keys():
		_blink[id] -= delta
		if _blink[id] <= 0.0:
			_blink.erase(id)
	_tier_blink -= delta
	if _blink.is_empty() and _tier_blink <= 0.0:
		set_process(false)
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
	_draw_load()
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


## Полоса груза с отметками порогов; под ней — серые иконки приёмов, которые отнял груз.
func _draw_load() -> void:
	if _player == null or _player.m == null:
		return
	var m := _player.m
	var font := ThemeDB.fallback_font
	var pos := Vector2(24.0, 128.0)
	var w := 260.0
	var h := 8.0
	var max_kg := m.load_over * 1.25
	var col: Color = TIER_COLORS[m.tier]
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(pos, Vector2(w * clampf(_player.effective_load / max_kg, 0.0, 1.0), h)), col)
	for kg in [m.load_medium, m.load_heavy, m.load_over]:
		var x: float = pos.x + w * kg / max_kg
		draw_line(Vector2(x, pos.y - 3.0), Vector2(x, pos.y + h + 3.0), Color(1, 1, 1, 0.7), 1.5)
	var text := "Груз %s кг — %s" % [ArtifactDb._num(snappedf(_player.load_kg, 0.1)), MovementConfig.TIER_NAMES[m.tier]]
	if not is_equal_approx(_player.effective_load, _player.load_kg):
		text += " (ощущается %s)" % ArtifactDb._num(snappedf(_player.effective_load, 0.1))
	var tcol := col
	if _tier_blink > 0.0 and int(_tier_blink * 8.0) % 2 == 0:
		tcol = Color.WHITE
	draw_string(font, pos + Vector2(0.0, h + 17.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tcol)
	var x0 := pos.x + 15.0
	for id in MOVE_ORDER:
		var lost := id in _lost
		if not lost and not _blink.has(id):
			continue
		var c := Vector2(x0, pos.y + 48.0)
		var icol := Color(1, 1, 1, 0.4)
		if _blink.has(id) and int(_blink[id] * 8.0) % 2 == 0:
			icol = Color("ef6f6c") if lost else Color("5ad17a")
		draw_rect(Rect2(c - Vector2(15.0, 15.0), Vector2(30.0, 30.0)), Color(0, 0, 0, 0.5))
		_draw_move_icon(id, c, icol)
		if lost:
			draw_line(c + Vector2(-13.0, 13.0), c + Vector2(13.0, -13.0), Color("ef6f6c", 0.8), 2.0)
		draw_string(font, c + Vector2(-15.0, 28.0), MOVE_SHORT[id], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, icol)
		x0 += 84.0


## Пиктограммы приёмов примитивами (поперечник ~20 px).
func _draw_move_icon(id: StringName, c: Vector2, col: Color) -> void:
	match id:
		&"wall_jump":
			draw_line(c + Vector2(-9.0, -10.0), c + Vector2(-9.0, 10.0), col, 3.0)
			_arrow(c + Vector2(-5.0, 7.0), c + Vector2(8.0, -7.0), col)
		&"air_dash":
			_arrow(c + Vector2(-9.0, -3.0), c + Vector2(9.0, -3.0), col)
			for k in 3:
				draw_line(c + Vector2(-9.0 + k * 7.0, 8.0), c + Vector2(-6.0 + k * 7.0, 8.0), col, 1.5)
		&"slide":
			draw_rect(Rect2(c + Vector2(-4.0, 1.0), Vector2(13.0, 6.0)), col)
			draw_line(c + Vector2(-10.0, 2.0), c + Vector2(-6.0, 2.0), col, 1.5)
			draw_line(c + Vector2(-10.0, 6.0), c + Vector2(-6.0, 6.0), col, 1.5)
			draw_line(c + Vector2(-10.0, 9.0), c + Vector2(10.0, 9.0), col, 1.5)
		&"grab":
			draw_line(c + Vector2(-1.0, -4.0), c + Vector2(10.0, -4.0), col, 2.5)
			draw_line(c + Vector2(-1.0, -4.0), c + Vector2(-1.0, 10.0), col, 2.5)
			draw_circle(c + Vector2(-5.0, -6.0), 3.5, col)
			draw_line(c + Vector2(-5.0, -3.0), c + Vector2(-6.0, 8.0), col, 2.0)
		&"dash":
			_arrow(c + Vector2(-9.0, 0.0), c + Vector2(9.0, 0.0), col)
			draw_line(c + Vector2(-10.0, 9.0), c + Vector2(10.0, 9.0), col, 1.5)


func _arrow(a: Vector2, b: Vector2, col: Color) -> void:
	draw_line(a, b, col, 2.5)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([b + d * 3.0, b - d * 5.0 + n * 4.5, b - d * 5.0 - n * 4.5]), col)
