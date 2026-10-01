extends "res://core/minigame.gd"
## Мини-игра «Шестерёнки и засовы». Всё рисуется примитивами через _draw.

const GearsLogic := preload("res://minigames/gears/gears_logic.gd")
const GearsLevels := preload("res://minigames/gears/levels.gd")

const CELL := 150.0
const TRACK_X := 340.0
const BOLT_Y0 := 150.0
const BOLT_DY := 95.0
const GEAR_Y := 540.0
const GEAR_R := 64.0
const COL_BG := Color("15171c")
const COL_PANEL := Color("1d2027")
const COL_TRACK := Color("2d313c")
const COL_NOTCH := Color("3b4050")
const COL_BOLT := Color("c9ced9")
const COL_OPEN := Color("5ad17a")
const COL_GEAR := Color("7d869b")
const COL_GEAR_HOT := Color("a3adc4")
const COL_GEAR_IN := Color("23262f")
const COL_LABEL := Color("8b92a3")
const BOLT_COLORS: Array[Color] = [Color("ef6f6c"), Color("5aa9ef"), Color("f2c14e"), Color("b57bee")]

var logic: GearsLogic
var level_idx := 0
var bolt_pos: Array[float] = []
var bolt_shake: Array[float] = []
var gear_angle: Array[float] = []
var gear_shake: Array[float] = []
var busy := false
var hover := -1

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
	if event is InputEventMouseMotion:
		var h := -1
		for i in logic.gears.size():
			if event.position.distance_to(_gear_pos(i)) <= GEAR_R:
				h = i
		if h != hover:
			hover = h
			queue_redraw()
		return
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


func _rrect(rect: Rect2, fill: Color, radius: int, border := Color(0, 0, 0, 0), bw := 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.anti_aliasing = true
	draw_style_box(sb, rect)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), COL_BG)
	if logic == null:
		return
	var font := ThemeDB.fallback_font
	var linked: Dictionary = {} if hover < 0 else logic.gears[hover]
	# Панель двери.
	_rrect(Rect2(60, BOLT_Y0 - 50, 1160, (logic.state.size() - 1) * BOLT_DY + 100), COL_PANEL, 18, COL_TRACK, 2)
	# Засовы.
	for b in logic.state.size():
		var y := BOLT_Y0 + b * BOLT_DY
		var col: Color = BOLT_COLORS[b % BOLT_COLORS.size()]
		if linked.has(b):
			_rrect(Rect2(80, y - 36, 1120, 72), Color(col, 0.16), 12, Color(col, 0.7), 2)
		# Метка-цвет засова.
		_rrect(Rect2(100, y - 24, 56, 48), col, 10)
		draw_string(font, Vector2(100, y + 8), str(b + 1), HORIZONTAL_ALIGNMENT_CENTER, 56, 24, COL_BG)
		# Шкала с делениями.
		_rrect(Rect2(TRACK_X - 10, y - 6, CELL * 4 + 80, 12), COL_TRACK, 6)
		for k in 5:
			_rrect(Rect2(TRACK_X + k * CELL + 26, y - 14, 8, 28), COL_NOTCH, 3)
		# Целевая ячейка «открыто».
		var tx := TRACK_X + logic.open[b] * CELL
		_rrect(Rect2(tx - 4, y - 30, 68, 60), Color(COL_OPEN, 0.10), 14, Color(COL_OPEN, 0.8), 2)
		# Сам засов.
		var bx := TRACK_X + bolt_pos[b] * CELL + bolt_shake[b]
		var body: Color = COL_OPEN if logic.is_open(b) else COL_BOLT
		_rrect(Rect2(bx, y - 22, 60, 44), body, 10)
		_rrect(Rect2(bx + 6, y - 16, 8, 32), Color(col, 0.9), 4)
	# Шестерёнки.
	for g in logic.gears.size():
		_draw_gear(_gear_pos(g), gear_angle[g] + gear_shake[g], font, g)


func _draw_gear(c: Vector2, ang: float, font: Font, idx: int) -> void:
	var teeth := 10
	var pts := PackedVector2Array()
	var hot := idx == hover
	var r_out := GEAR_R + (4.0 if hot else 0.0)
	for i in teeth * 4:
		var r := r_out if (i / 2) % 2 == 0 else r_out - 14.0
		var a := ang + i * TAU / (teeth * 4)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_circle(c + Vector2(0, 5), r_out, Color(0, 0, 0, 0.3))
	draw_colored_polygon(pts, COL_GEAR_HOT if hot else COL_GEAR)
	draw_circle(c, 42.0, COL_GEAR_IN)
	# Точки цветов засовов, которыми управляет шестерёнка.
	var keys: Array = logic.gears[idx].keys()
	var n := keys.size()
	for j in n:
		var a := -PI / 2.0 + (j - (n - 1) * 0.5) * 0.8
		var p := c + Vector2(cos(a), sin(a)) * 27.0
		draw_circle(p, 9.0, BOLT_COLORS[int(keys[j]) % BOLT_COLORS.size()])
	draw_string(font, c + Vector2(-60, 100), "шестерёнка %d" % (idx + 1), HORIZONTAL_ALIGNMENT_CENTER, 120, 14, COL_LABEL)
