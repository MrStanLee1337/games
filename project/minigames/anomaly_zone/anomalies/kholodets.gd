@tool
class_name Kholodets
extends Anomaly
## Холодец: лужа на полу. Замедляет игрока, наносит урон со временем, болты тонут.
## Начало координат — середина нижнего края лужи (на уровне пола).

@export var size := Vector2(200.0, 18.0):
	set(v):
		size = v
		_rebuild()
## Урон, HP в секунду.
@export var dps := 6.0


func _init() -> void:
	anomaly_type = Type.KHOLODETS


func _apply_shape(s: float) -> void:
	var sz := Vector2(size.x * s, size.y)
	(_shape_node.shape as RectangleShape2D).size = sz
	_shape_node.position = Vector2(0.0, -sz.y * 0.5)


func _new_shape() -> Shape2D:
	return RectangleShape2D.new()


func _tick(delta: float) -> void:
	if is_asleep():
		return
	# Замедление зависит только от интенсивности, урон — ещё и от damage_mult (Медуза).
	var slow := clampf(1.0 - 0.5 * current_intensity, 0.2, 1.0)
	for p in _players():
		p.set_move_multiplier(slow)
		p.damage_over_time(dmg(dps) * delta)
	for b in _bolts():
		b.sink()


func _draw() -> void:
	var w := size.x * scale_factor()
	var h := size.y
	var live := not Engine.is_editor_hint()
	if live and is_asleep():
		draw_rect(Rect2(-w * 0.5, -3.0, w, 3.0), Color(0.5, 0.45, 0.35, 0.3))  # высохла
		return
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var x := -w * 0.5 + w * i / n
		pts.append(Vector2(x, -h + 2.5 * sin(_phase * 2.0 + x * 0.06)))
	pts.append(Vector2(w * 0.5, 0.0))
	pts.append(Vector2(-w * 0.5, 0.0))
	draw_colored_polygon(pts, tint(Color("6bff6b", 0.42)))
	draw_polyline(pts.slice(0, n + 1), tint(Color("b6ffb6", 0.8)), 1.5)
	for i in 4:
		var bx := -w * 0.5 + w * fposmod(i * 0.37 + 0.13, 1.0)
		var by := -h * fposmod(_phase * 0.4 + i * 0.25, 1.0)
		draw_arc(Vector2(bx, by), 2.5, 0.0, TAU, 10, tint(Color("e8ffe8", 0.7)), 1.0)
