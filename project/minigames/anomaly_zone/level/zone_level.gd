class_name ZoneLevel
extends Node2D
## База уровней «Зоны»: общие поля для zone.gd и помощники сборки уровня кодом.
## Наследник переопределяет _build().

const FLOOR_Y := 600.0
## Поле аномалии (камера приближается) — габариты аномалии плюс этот отступ.
const FIELD_MARGIN := 120.0

var bounds := Rect2(-200.0, -300.0, 8600.0, 1300.0)
var fall_y := 960.0
## Точка А: старт забега (на полу, ноги игрока).
var start_pos := Vector2.ZERO
var finish_sign: FinishSign


func _ready() -> void:
	_build()
	_add_anomaly_fields()


## Вокруг каждой аномалии — AnomalyField: внутри камера приближается.
func _add_anomaly_fields() -> void:
	for c in get_children():
		if c is Anomaly:
			var r := (c as Anomaly).world_bounds().grow(FIELD_MARGIN)
			var f := AnomalyField.new()
			f.size = r.size
			add_child(f)
			f.global_position = r.position


func _build() -> void:
	pass


func _finish_at(x: float) -> void:
	finish_sign = FinishSign.new()
	finish_sign.position = Vector2(x, FLOOR_Y)
	add_child(finish_sign)


# --- Помощники -------------------------------------------------------------

func _floor(x1: float, x2: float) -> void:
	_plat(x1, FLOOR_Y, x2 - x1, 300.0)


func _plat(x: float, y: float, w: float, h: float, one_way: bool = false) -> Platform:
	var p := Platform.new()
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.one_way = one_way
	add_child(p)
	return p


## Лестница (или верёвка без площадки): x — левый край, от y_top до y_bottom.
func _ladder(x: float, y_top: float, y_bottom: float, one_way_top: bool = true) -> Ladder:
	var l := Ladder.new()
	l.position = Vector2(x, y_top)
	l.size = Vector2(28.0, y_bottom - y_top)
	l.one_way_top = one_way_top
	add_child(l)
	return l


func _anomaly(a: Anomaly, pos: Vector2) -> void:
	a.position = pos
	add_child(a)


func _pickup(id: StringName, x: float, y: float = FLOOR_Y) -> void:
	var p := Pickup.new()
	p.item_id = id
	p.position = Vector2(x, y)
	add_child(p)


## Точка А — старт забега.
func _start(x: float, y: float = FLOOR_Y) -> void:
	start_pos = Vector2(x, y)


func _sign(x: float, text: String, w: float = 320.0, y: float = FLOOR_Y) -> void:
	var s := SignPost.new()
	s.position = Vector2(x, y)
	s.text = text
	s.width = w
	add_child(s)


func _draw() -> void:
	# Точечная сетка — чтобы глазом ловить скорость и расстояния.
	for x in range(int(bounds.position.x), int(bounds.end.x), 100):
		for y in range(int(bounds.position.y), int(bounds.end.y), 100):
			draw_circle(Vector2(x, y), 2.0, Color(1, 1, 1, 0.07))
