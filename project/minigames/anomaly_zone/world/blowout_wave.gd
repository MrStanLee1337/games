class_name BlowoutWave
extends Node2D
## Волна Выброса: вертикальная стена на всю высоту уровня, едет по x с постоянной скоростью от А к Б.
## Касание — смерть сразу, без учёта HP. Скорость своя у каждого участка (ZoneLevel.wave_speed);
## стартует в xА − START_BEHIND в момент старта участка. На паузе (выбор в тайнике) стоит вместе с игрой.

signal caught

## Насколько левее точки А волна стартует (за левым краем экрана).
const START_BEHIND := 480.0

var speed := 0.0
## Передний (правый) край волны, px.
var x := 0.0
var active := false
## F3 выключает волну (для тестов).
var enabled := true
var player: Player
var _top := -400.0
var _bottom := 1400.0
var _t := 0.0


func _ready() -> void:
	z_index = 40


## Запуск на участке: от start_x (точка А) − START_BEHIND со скоростью v по высоте уровня bounds.
func start(start_x: float, v: float, bounds: Rect2) -> void:
	x = start_x - START_BEHIND
	speed = v
	_top = bounds.position.y - 400.0
	_bottom = bounds.end.y + 400.0
	active = v > 0.0


func stop() -> void:
	active = false


func is_running() -> bool:
	return active and enabled


## Отрыв игрока от волны в секундах (сколько волне ехать до игрока).
func gap_seconds() -> float:
	if player == null or speed <= 0.0:
		return INF
	return (player.global_position.x - player.body_size.x * 0.5 - x) / speed


func _physics_process(delta: float) -> void:
	if not is_running():
		return
	x += speed * delta
	if player and not player.is_dead() and player.global_position.x - player.body_size.x * 0.5 <= x:
		caught.emit()


func _process(delta: float) -> void:
	_t += delta
	if active:
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	# Красная стена с рваным краем: зубцы бегут вдоль кромки.
	var pts := PackedVector2Array()
	var y := _top
	var i := 0
	while y <= _bottom:
		var jag := 14.0 * sin(y * 0.045 + _t * 7.0) + 9.0 * sin(y * 0.13 - _t * 11.0) + (10.0 if i % 2 == 0 else -6.0)
		pts.append(Vector2(x + jag, y))
		y += 22.0
		i += 1
	pts.append(Vector2(x - 2400.0, _bottom))
	pts.append(Vector2(x - 2400.0, _top))
	var col := Color(0.70, 0.08, 0.06, 0.82) if enabled else Color(0.5, 0.5, 0.5, 0.3)
	draw_colored_polygon(pts, col)
	draw_polyline(pts.slice(0, pts.size() - 2), Color(1.0, 0.45, 0.3, 0.9), 3.0)
	# Светящиеся полосы внутри стены.
	for k in 6:
		var sx := x - 60.0 - k * 70.0 - fposmod(_t * 120.0, 70.0)
		draw_line(Vector2(sx, _top), Vector2(sx - 40.0, _bottom), Color(1.0, 0.3, 0.2, 0.12), 6.0)
