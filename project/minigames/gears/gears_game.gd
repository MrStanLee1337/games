extends "res://core/minigame.gd"
## Мини-игра «Шестерёнки и засовы». Всё рисуется примитивами через _draw.

const GearsLogic := preload("res://minigames/gears/gears_logic.gd")
const GearsLevels := preload("res://minigames/gears/levels.gd")

const CELL := 150.0
const TRACK_X := 340.0
const BOLT_Y0 := 130.0
const BOLT_DY := 95.0
const GEAR_Y := 560.0
const GEAR_R := 52.0
const LINK_X := 300.0
const COL_BG := Color("1b1d24")
const COL_TRACK := Color("3a3f4d")
const COL_BOLT := Color("c9ced9")
const COL_OPEN := Color("5ad17a")
const COL_MARK := Color("e0b04a")
const COL_GEAR := Color("8a93a8")

var logic: GearsLogic
var level_idx := 0
var bolt_pos: Array[float] = []
var bolt_shake: Array[float] = []
var gear_angle: Array[float] = []
var gear_shake: Array[float] = []
var busy := false

var info: Label
var title: Label
var banner: Label
var next_btn: Button


func _ready() -> void:
	_build_ui()
	load_level(0)
	start()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	title = _label(Vector2(40, 24), 28)
	info = _label(Vector2(40, 66), 18)
	banner = _label(Vector2(0, 330), 40)
	banner.size = Vector2(1280, 60)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.visible = false
	var reset := Button.new()
	reset.text = "Сброс"
	reset.position = Vector2(1100, 24)
	reset.size = Vector2(140, 44)
	reset.pressed.connect(func(): load_level(level_idx))
	add_child(reset)
	next_btn = Button.new()
	next_btn.text = "Дальше"
	next_btn.position = Vector2(570, 400)
	next_btn.size = Vector2(140, 48)
	next_btn.visible = false
	next_btn.pressed.connect(_next_level)
	add_child(next_btn)


func _label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	add_child(l)
	return l


func load_level(idx: int) -> void:
	level_idx = idx
	logic = GearsLogic.new(GearsLevels.LEVELS[idx])
	bolt_pos.clear()
	bolt_shake.clear()
	gear_angle.clear()
	gear_shake.clear()
	for b in logic.state:
		bolt_pos.append(float(b))
		bolt_shake.append(0.0)
	for g in logic.gears:
		gear_angle.append(0.0)
		gear_shake.append(0.0)
	busy = false
	banner.visible = false
	next_btn.visible = false
	_refresh_info()
	queue_redraw()


func _refresh_info() -> void:
	title.text = "Уровень %d / %d" % [level_idx + 1, GearsLevels.LEVELS.size()]
	info.text = "Ходов: %d   ЛКМ — по часовой, ПКМ — против" % logic.moves


func _gear_pos(i: int) -> Vector2:
	var n := logic.gears.size()
	return Vector2(640.0 + (i - (n - 1) * 0.5) * 220.0, GEAR_Y)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or busy:
		return
	var dir := 0
	if mb.button_index == MOUSE_BUTTON_LEFT:
		dir = 1
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		dir = -1
	if dir == 0:
		return
	for i in logic.gears.size():
		if mb.position.distance_to(_gear_pos(i)) <= GEAR_R:
			_turn(i, dir)
			return


func _turn(gear: int, dir: int) -> void:
	var blocked: Array = logic.turn(gear, dir)
	busy = true
	if blocked.is_empty():
		var tw := create_tween().set_parallel(true)
		tw.tween_method(_set_gear_angle.bind(gear), gear_angle[gear], gear_angle[gear] + dir * TAU / 8.0, 0.2)
		for bolt in logic.gears[gear]:
			tw.tween_method(_set_bolt_pos.bind(bolt), bolt_pos[bolt], float(logic.state[bolt]), 0.2)
		tw.chain().tween_callback(_after_move)
	else:
		# Клин: шестерёнка дёргается и возвращается, упёршийся засов вздрагивает.
		var seq := create_tween()
		for amp in [0.5, -0.4, 0.25, 0.0]:
			seq.tween_method(_set_gear_shake.bind(gear), gear_shake[gear], amp * dir, 0.05)
		for bolt in blocked:
			var bt := create_tween()
			for amp in [8.0, -6.0, 3.0, 0.0]:
				bt.tween_method(_set_bolt_shake.bind(bolt), bolt_shake[bolt], amp, 0.05)
		seq.tween_callback(func(): busy = false)


func _after_move() -> void:
	busy = false
	_refresh_info()
	if logic.is_solved():
		busy = true
		banner.text = "Дверь открыта!  Ходов: %d" % logic.moves
		banner.visible = true
		var last := level_idx == GearsLevels.LEVELS.size() - 1
		next_btn.visible = not last
		if last:
			finish(true, {"moves": logic.moves})


func _next_level() -> void:
	finish(true, {"moves": logic.moves, "level": level_idx})
	load_level(level_idx + 1)


func _set_gear_angle(v: float, gear: int) -> void:
	gear_angle[gear] = v
	queue_redraw()


func _set_gear_shake(v: float, gear: int) -> void:
	gear_shake[gear] = v
	queue_redraw()


func _set_bolt_pos(v: float, bolt: int) -> void:
	bolt_pos[bolt] = v
	queue_redraw()


func _set_bolt_shake(v: float, bolt: int) -> void:
	bolt_shake[bolt] = v
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), COL_BG)
	if logic == null:
		return
	var font := ThemeDB.fallback_font
	# Тяги от шестерёнок к засовам.
	for g in logic.gears.size():
		for bolt in logic.gears[g]:
			var by: float = BOLT_Y0 + bolt * BOLT_DY
			var pts := PackedVector2Array([_gear_pos(g), Vector2(LINK_X - 20 - g * 8, by + 40), Vector2(LINK_X, by)])
			draw_polyline(pts, Color(1, 1, 1, 0.25), 2.0)
	# Засовы.
	for b in logic.state.size():
		var y := BOLT_Y0 + b * BOLT_DY
		draw_rect(Rect2(TRACK_X, y - 4, CELL * 4 + 60, 8), COL_TRACK)
		for k in 5:
			draw_rect(Rect2(TRACK_X + k * CELL + 26, y - 14, 8, 28), COL_TRACK)
		var mx := TRACK_X + logic.open[b] * CELL + 30
		draw_rect(Rect2(mx - 10, y - 30, 20, 8), COL_MARK)
		var bx := TRACK_X + bolt_pos[b] * CELL + bolt_shake[b]
		var col := COL_OPEN if logic.is_open(b) else COL_BOLT
		draw_rect(Rect2(bx, y - 22, 60, 44), col)
	# Шестерёнки.
	for g in logic.gears.size():
		_draw_gear(_gear_pos(g), gear_angle[g] + gear_shake[g], font, g)


func _draw_gear(c: Vector2, ang: float, font: Font, idx: int) -> void:
	var teeth := 10
	var pts := PackedVector2Array()
	for i in teeth * 2:
		var r := GEAR_R if i % 2 == 0 else GEAR_R - 12.0
		var a := ang + i * TAU / (teeth * 2)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, COL_GEAR)
	draw_circle(c, 14.0, COL_BG)
	draw_string(font, c + Vector2(-5, 7), str(idx + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, COL_GEAR)
