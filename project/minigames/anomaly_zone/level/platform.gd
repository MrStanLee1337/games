@tool
class_name Platform
extends StaticBody2D
## Платформа. Начало координат — левый верхний угол; размер задаётся в инспекторе.

@export var size := Vector2(200.0, 24.0):
	set(v):
		size = v
		_rebuild()
## Односторонняя: можно запрыгнуть снизу, проваливаться нельзя.
@export var one_way := false:
	set(v):
		one_way = v
		_rebuild()

var _shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
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
	_shape.one_way_collision = one_way
	queue_redraw()


func _draw() -> void:
	if one_way:
		draw_rect(Rect2(Vector2.ZERO, size), Color("34425c"))
		var x := 0.0
		while x < size.x:
			draw_rect(Rect2(Vector2(x, 0.0), Vector2(minf(12.0, size.x - x), 3.0)), Color("6f86b0"))
			x += 20.0
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("2a2f3b"))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, 3.0)), Color("4f596e"))
