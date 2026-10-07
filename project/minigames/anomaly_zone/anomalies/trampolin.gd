@tool
class_name Trampolin
extends Anomaly
## Трамплин: почти невидимая зона. Вход → импульс от центра (в основном вверх), лёгкий урон.
## После срабатывания на секунду проявляется.

@export var radius := 50.0:
	set(v):
		radius = v
		_rebuild()
@export var impulse := 640.0
@export var damage := 4.0
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


## Сила растёт слабее, чем интенсивность: I^0.7 — иначе ×2 даёт запредельную высоту.
func _strength() -> float:
	return impulse * pow(current_intensity, 0.7)


func _launch_dir(from: Vector2) -> Vector2:
	var side := clampf((from.x - global_position.x) / (radius * scale_factor()), -1.0, 1.0) * 0.45
	var d := Vector2(side, -1.0).normalized()
	return Vector2(d.x, -d.y) if inverted else d


func _tick(delta: float) -> void:
	_reveal = maxf(0.0, _reveal - delta / reveal_time)
	var r := scale_factor()
	match state:
		State.IDLE:
			if is_asleep() or (not _has_provoker() and _world_artifacts().is_empty()):
				return
			for p in _players():
				p.take_damage(dmg(damage))
				p.apply_impulse(_launch_dir(p.global_position) * _strength(), 0.15)
			for b in _bolts():
				b.linear_velocity = _launch_dir(b.global_position) * _strength() * 0.8
			for wa in _world_artifacts():
				if not wa.is_orbiting():
					wa.linear_velocity = _launch_dir(wa.global_position) * _strength() * 0.8
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
	var a := 0.15 + 0.75 * _reveal
	var ring := rr * (1.0 + 0.04 * sin(_phase * 4.0))
	draw_circle(Vector2.ZERO, rr, tint(Color(col, a * 0.25)))
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 32, tint(Color(col, a)), 2.0)
	# Стрелка направления толчка.
	var up := 1.0 if inverted else -1.0
	var c := tint(Color(col, a))
	draw_polyline(PackedVector2Array([
		Vector2(-10.0, -up * 4.0), Vector2(0.0, up * 8.0), Vector2(10.0, -up * 4.0)]), c, 2.0)
