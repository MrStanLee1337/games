class_name Shelter
extends Area2D
## Укрытие в конце участка (точка Б участка): вошёл — волна останавливается. На последнем
## участке это финиш забега, после участка 1 внутри стоят двери развилки.
## Начало координат — вход в укрытие на уровне пола.

signal reached

## Последний участок: табличка финиша вместо укрытия.
@export var final := false
@export var width := 700.0

var _done := false
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40.0, 200.0)
	cs.shape = rect
	cs.position = Vector2(20.0, -100.0)
	add_child(cs)
	body_entered.connect(_on_body_entered)
	z_index = -1


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	# Игрок действительно у входа (а не устаревшее касание при загрузке участка).
	if body is Player and not _done and absf(body.global_position.x - global_position.x) < 80.0:
		_done = true
		reached.emit()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if final:
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		draw_circle(Vector2(60.0, -80.0), 70.0 + 6.0 * pulse, Color(0.36, 0.82, 0.48, 0.07))
		draw_line(Vector2(20.0, 0.0), Vector2(20.0, -110.0), Color("aab1c2"), 4.0)
		draw_line(Vector2(100.0, 0.0), Vector2(100.0, -110.0), Color("aab1c2"), 4.0)
		var r := Rect2(Vector2(-30.0, -170.0), Vector2(180.0, 64.0))
		draw_rect(r, Color("1d2027"))
		draw_rect(r, Color("5ad17a"), false, 2.5)
		draw_string(font, r.position + Vector2(0.0, 28.0), "Б — ФИНИШ", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Color("e8ecf4"))
		draw_string(font, r.position + Vector2(0.0, 52.0), "ВЫБРОС ПОЗАДИ", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color("5ad17a"))
		return
	# Бункер: бетонная коробка с крышей, вход слева.
	var h := 230.0
	draw_rect(Rect2(Vector2(0.0, -h), Vector2(width, h)), Color(0.16, 0.18, 0.22, 0.85))
	draw_rect(Rect2(Vector2(-20.0, -h - 26.0), Vector2(width + 40.0, 26.0)), Color("4f596e"))
	draw_rect(Rect2(Vector2(0.0, -h), Vector2(width, h)), Color("6b7489"), false, 2.0)
	draw_string(font, Vector2(0.0, -h - 36.0), "УКРЫТИЕ", HORIZONTAL_ALIGNMENT_CENTER, width, 20, Color("e8ecf4"))
