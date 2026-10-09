class_name AnomalyField
extends Area2D
## Поле аномалии: область вокруг аномального поля, внутри которой камера приближается
## (MovementConfig.zoom_field). ZoneLevel ставит поле вокруг каждой аномалии сам.
## Начало координат — левый верхний угол.

@export var size := Vector2(400.0, 400.0)


func _ready() -> void:
	add_to_group(&"anomaly_fields")
	collision_layer = 0
	collision_mask = 2
	monitoring = false
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = size * 0.5
	add_child(cs)


## Поле в глобальных координатах.
func zone_rect() -> Rect2:
	return Rect2(global_position, size)
