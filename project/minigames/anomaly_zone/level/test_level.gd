class_name TestLevel
extends Node2D
## Временный тестовый уровень для обкатки управления (на этапе 6 заменяется демо-уровнем).

const FLOOR_Y := 600.0

var bounds := Rect2(-200.0, -300.0, 3700.0, 1300.0)
var fall_y := 960.0
var checkpoints: Array[Checkpoint] = []


func _ready() -> void:
	# Пол с пропастями: широкие 230 px — перепрыгиваются только с рывком.
	_plat(-200.0, FLOOR_Y, 1100.0, 300.0)
	_plat(1130.0, FLOOR_Y, 820.0, 300.0)
	_plat(2180.0, FLOOR_Y, 1320.0, 300.0)
	# Лесенка вверх.
	_plat(300.0, 520.0, 160.0, 20.0)
	_plat(520.0, 440.0, 160.0, 20.0)
	_plat(740.0, 360.0, 160.0, 20.0, true)
	# Уступы во второй секции.
	_plat(1300.0, 520.0, 200.0, 20.0)
	_plat(1560.0, 440.0, 200.0, 20.0, true)
	# Невысокая стенка.
	_plat(2700.0, 520.0, 40.0, 80.0)
	_checkpoint(80.0)
	_checkpoint(1180.0)
	_checkpoint(2230.0)


func _plat(x: float, y: float, w: float, h: float, one_way: bool = false) -> void:
	var p := Platform.new()
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.one_way = one_way
	add_child(p)


func _checkpoint(x: float) -> void:
	var c := Checkpoint.new()
	c.position = Vector2(x, FLOOR_Y)
	add_child(c)
	checkpoints.append(c)


func _draw() -> void:
	# Точечная сетка — чтобы глазом ловить скорость и расстояния.
	for x in range(int(bounds.position.x), int(bounds.end.x), 100):
		for y in range(int(bounds.position.y), int(bounds.end.y), 100):
			draw_circle(Vector2(x, y), 2.0, Color(1, 1, 1, 0.07))
