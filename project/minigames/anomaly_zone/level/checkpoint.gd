class_name Checkpoint
extends Area2D
## Флажок-чекпоинт. Начало координат — основание древка (уровень пола).

signal activated(checkpoint: Checkpoint)

var active := false:
	set(v):
		active = v
		queue_redraw()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60.0, 100.0)
	cs.shape = rect
	cs.position = Vector2(0.0, -50.0)
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		activated.emit(self)


func _draw() -> void:
	var col := Color("5ad17a") if active else Color("6b7285")
	draw_line(Vector2.ZERO, Vector2(0.0, -80.0), Color("aab1c2"), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, -80.0), Vector2(32.0, -68.0), Vector2(0.0, -56.0)]), col)
