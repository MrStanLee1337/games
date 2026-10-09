@tool
class_name Trampolin
extends Anomaly
## Трамплин: пружинящая зона. Вход → подброс на заданную высоту (AnomalyDb, v = √(2·g·h)), лёгкий урон,
## бафф Лёгкость. Виден всегда, после срабатывания на секунду ярче.

@export var radius := 50.0:
	set(v):
		radius = v
		_rebuild()
@export var cooldown_time := 0.4
@export var reveal_time := 1.0

var _reveal := 0.0


func _init() -> void:
	anomaly_type = Type.TRAMPLIN


func _apply_shape(s: float) -> void:
	(_shape_node.shape as CircleShape2D).radius = radius * s


func _extent() -> float:
	return radius * scale_factor()


func _reset_extra() -> void:
	_reveal = 0.0


func _tick(delta: float) -> void:
	_reveal = maxf(0.0, _reveal - delta / reveal_time)
	var r := scale_factor()
	match state:
		State.IDLE:
			if is_asleep() or not _has_provoker():
				return
			for p in _players():
				p.on_anomaly_contact(anomaly_type, get_instance_id())
			_reveal = 1.0
			_set_state(State.COOLDOWN)
		State.COOLDOWN:
			if _state_t >= cooldown_time / r:
				_set_state(State.IDLE)


func _draw() -> void:
	var rr := radius * scale_factor()
	var live := not Engine.is_editor_hint()
	if live and is_asleep():
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 32, Color(0.7, 0.7, 0.7, 0.08), 1.0)
		return
	var col := Color("9be564")
	var a := 0.6 + 0.4 * _reveal
	draw_rect(Rect2(-rr * 0.8, rr * 0.55, rr * 1.6, 5.0), tint(Color(col, 0.9)))  # пружинящая площадка
	var ring := rr * (1.0 + 0.04 * sin(_phase * 4.0))
	draw_circle(Vector2.ZERO, rr, tint(Color(col, a * 0.25)))
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 32, tint(Color(col, a)), 2.0)
	# Стрелка направления толчка.
	var up := -1.0
	var c := tint(Color(col, a))
	draw_polyline(PackedVector2Array([
		Vector2(-10.0, -up * 4.0), Vector2(0.0, up * 8.0), Vector2(10.0, -up * 4.0)]), c, 2.0)
