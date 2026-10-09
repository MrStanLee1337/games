@tool
class_name Ladder
extends Area2D
## Лестница или верёвка. Начало координат — левый верхний угол; размер — в инспекторе.
## Игрок цепляется W / S внутри зоны (в воздухе — автоматически с зажатым W), Пробел — спрыгнуть.
## Верёвка в этой итерации ведёт себя как вертикальная лестница.

@export var size := Vector2(28.0, 200.0):
	set(v):
		size = v
		_rebuild()
## Наверху площадка: на ней можно стоять, снизу проходишь насквозь.
@export var one_way_top := true:
	set(v):
		one_way_top = v
		_rebuild()
## Рисовать верёвкой.
@export var rope := false:
	set(v):
		rope = v
		queue_redraw()

## Верхняя площадка (односторонняя Platform) или null.
var top_platform: Platform
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group(&"ladders")
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.shape = RectangleShape2D.new()
		add_child(_shape)
	(_shape.shape as RectangleShape2D).size = size
	_shape.position = size * 0.5
	if one_way_top and top_platform == null:
		top_platform = Platform.new()
		top_platform.one_way = true
		add_child(top_platform)
	elif not one_way_top and top_platform:
		top_platform.queue_free()
		top_platform = null
	if top_platform:
		top_platform.size = Vector2(size.x, 6.0)
	queue_redraw()


## Зона лестницы в глобальных координатах.
func zone_rect() -> Rect2:
	return Rect2(global_position, size)


func _draw() -> void:
	if rope:
		var cx := size.x * 0.5
		draw_line(Vector2(cx, 0.0), Vector2(cx, size.y), Color("a08a5c"), 3.0)
		var y := 20.0
		while y < size.y:
			draw_circle(Vector2(cx, y), 3.0, Color("7d6a44"))
			y += 28.0
		return
	var rail := Color("8a7350")
	draw_rect(Rect2(Vector2(2.0, 0.0), Vector2(3.0, size.y)), rail)
	draw_rect(Rect2(Vector2(size.x - 5.0, 0.0), Vector2(3.0, size.y)), rail)
	var ry := 10.0
	while ry < size.y:
		draw_rect(Rect2(Vector2(2.0, ry), Vector2(size.x - 4.0, 3.0)), Color("a68c62"))
		ry += 16.0
