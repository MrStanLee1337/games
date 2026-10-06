class_name FinishSign
extends Area2D
## Финишная табличка: касание игроком завершает прототип.

signal reached

var _t := 0.0
var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80.0, 140.0)
	cs.shape = rect
	cs.position = Vector2(0.0, -70.0)
	add_child(cs)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _done:
		_done = true
		reached.emit()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_circle(Vector2(0.0, -80.0), 70.0 + 6.0 * pulse, Color(0.36, 0.82, 0.48, 0.07))
	draw_line(Vector2(-30.0, 0.0), Vector2(-30.0, -90.0), Color("aab1c2"), 4.0)
	draw_line(Vector2(30.0, 0.0), Vector2(30.0, -90.0), Color("aab1c2"), 4.0)
	var r := Rect2(Vector2(-90.0, -150.0), Vector2(180.0, 64.0))
	draw_rect(r, Color("1d2027"))
	draw_rect(r, Color("5ad17a"), false, 2.5)
	draw_string(font, r.position + Vector2(0.0, 26.0), "ПРОТОТИП", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Color("e8ecf4"))
	draw_string(font, r.position + Vector2(0.0, 50.0), "ПРОЙДЕН", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Color("5ad17a"))
