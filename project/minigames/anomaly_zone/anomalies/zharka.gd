@tool
class_name Zharka
extends Anomaly
## Жарка: вертикальный столб огня. Вход игрока → предупреждение → огонь с уроном → пауза.
## Начало координат — середина основания столба.

@export var size := Vector2(60.0, 160.0):
	set(v):
		size = v
		_rebuild()
@export var telegraph_time := 0.4
@export var active_time := 1.0
@export var cooldown_time := 1.5
## Периодический режим: вспыхивает сама, без провокации.
@export var periodic := false
@export var period := 3.0

var _hit_t := 0.0
## Смещение пламени по x: Воронка рядом затягивает огонь к себе (AnomalyInteractions).
var flame_offset := 0.0
var _flame_target := 0.0
var _particles: CPUParticles2D


func _init() -> void:
	anomaly_type = Type.ZHARKA


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.amount = 20
	_particles.lifetime = 0.8
	_particles.direction = Vector2.UP
	_particles.spread = 12.0
	_particles.gravity = Vector2.ZERO
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.scale_amount_min = 2.0
	_particles.scale_amount_max = 4.5
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color("ffd36b"), Color(1.0, 0.4, 0.1, 0.0)])
	_particles.color_ramp = grad
	add_child(_particles)


func _new_shape() -> Shape2D:
	return RectangleShape2D.new()


## Аура Пламени: столб на size_mult шире и выше (урон и бафф не меняет).
func _aura_k() -> float:
	return float(aura.get("size_mult", 1.0))


func set_aura(effects: Dictionary) -> void:
	var was := _aura_k()
	super.set_aura(effects)
	if not is_equal_approx(was, _aura_k()) and _shape_node:
		_apply_shape(scale_factor())


func _apply_shape(s: float) -> void:
	var sz := size * s * _aura_k()
	(_shape_node.shape as RectangleShape2D).size = sz
	_shape_node.position = Vector2(flame_offset * 0.8, -sz.y * 0.5)


func _world_rect() -> Rect2:
	var k := scale_factor() * _aura_k()
	return Rect2(global_position + Vector2(-size.x * k * 0.5 + flame_offset * 0.8, -size.y * k), size * k)


func world_bounds() -> Rect2:
	return _world_rect()


## Куда тянет пламя (px по x). Действует только пока столб горит.
func set_flame_pull(dx: float) -> void:
	_flame_target = dx


func debug_extra() -> String:
	return "пламя dx=%d" % int(flame_offset) if absf(flame_offset) > 0.5 else ""


func edge_distance(p: Vector2) -> float:
	return _rect_distance(p, _world_rect())


func visual_center() -> Vector2:
	return _world_rect().get_center()


func top_point() -> Vector2:
	return Vector2(global_position.x, _world_rect().position.y - 16.0)


func _on_state(s: State) -> void:
	if _particles == null:
		return
	_particles.emitting = s == State.ACTIVE
	if s == State.ACTIVE:
		var k := scale_factor() * _aura_k()
		_particles.amount = int(10.0 + 14.0 * current_intensity)
		_particles.position = Vector2(0.0, -6.0)
		_particles.emission_rect_extents = Vector2(size.x * k * 0.4, 4.0)
		var v := size.y * k / 0.8
		_particles.initial_velocity_min = v * 0.7
		_particles.initial_velocity_max = v


func _reset_extra() -> void:
	_hit_t = 0.0
	flame_offset = 0.0
	_flame_target = 0.0
	if _particles:
		_particles.emitting = false


func _tick(delta: float) -> void:
	var r := scale_factor()
	var want := _flame_target if state == State.ACTIVE else 0.0
	if not is_equal_approx(flame_offset, want):
		flame_offset = move_toward(flame_offset, want, 220.0 * delta)
		_shape_node.position.x = flame_offset * 0.8
		if _particles:
			_particles.gravity = Vector2(flame_offset * 4.0, 0.0)
			_particles.position.x = flame_offset * 0.4
	match state:
		State.IDLE:
			if is_asleep():
				return
			if _has_provoker() or (periodic and _state_t >= period / r):
				_set_state(State.TELEGRAPH)
		State.TELEGRAPH:
			if is_asleep():
				_set_state(State.IDLE)
			elif _state_t >= telegraph_time / r:
				_set_state(State.ACTIVE)
				_hit_t = 0.0
		State.ACTIVE:
			if is_asleep():
				_set_state(State.COOLDOWN)
				return
			_hit_t -= delta
			if _hit_t <= 0.0:
				_hit_t = 0.3
				for p in _players():
					p.on_anomaly_contact(anomaly_type, get_instance_id())
			if _state_t >= active_time:
				_set_state(State.COOLDOWN)
		State.COOLDOWN:
			if _state_t >= cooldown_time / r:
				_set_state(State.IDLE)


func _draw() -> void:
	var k := scale_factor() * _aura_k()
	var w := size.x * k
	var h := size.y * k
	var r := Rect2(-w * 0.5, -h, w, h)
	var orange := Color("ff8a2b")
	var live := not Engine.is_editor_hint()
	if live and is_asleep():
		draw_rect(r, Color(0.7, 0.7, 0.7, 0.05 + 0.03 * sin(_phase * 2.0)))
		return
	match state if live else State.IDLE:
		State.TELEGRAPH:
			var frac := clampf(_state_t / (telegraph_time / scale_factor()), 0.0, 1.0)
			var flick := 1.0 if int(_time * 24.0) % 2 == 0 else 0.35
			draw_rect(Rect2(-w * 0.5, -h * frac, w, h * frac), tint(Color(orange, 0.55 * flick)))
			draw_rect(r, tint(Color(orange, 0.5)), false, 1.5)
		State.ACTIVE:
			# Столб наклоняется к Воронке: основание смещено слабо, верх — сильно.
			var b := flame_offset * 0.4
			var t := flame_offset * 1.2
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w * 0.5 + b, 0.0), Vector2(w * 0.5 + b, 0.0),
				Vector2(w * 0.5 + t, -h), Vector2(-w * 0.5 + t, -h)]), tint(Color("ff6a00", 0.35)))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w * 0.25 + b, 0.0), Vector2(w * 0.25 + b, 0.0),
				Vector2(w * 0.25 + t * 0.9, -h * 0.9), Vector2(-w * 0.25 + t * 0.9, -h * 0.9)]), tint(Color("ffd36b", 0.5)))
			var n := 5
			for i in n:
				var x := -w * 0.5 + w * (i + 0.5) / n + b
				var top := h * (0.7 + 0.3 * sin(_phase * (9.0 + i * 1.7) + i))
				var half := w / (2.0 * n)
				var lean := (t - b) * top / h
				draw_colored_polygon(
					PackedVector2Array([Vector2(x - half, 0.0), Vector2(x + lean, -top), Vector2(x + half, 0.0)]),
					tint(Color("ff9d2e", 0.7)))
		_:
			draw_rect(r, tint(Color(orange, 0.07)))
			draw_rect(r, tint(Color(orange, 0.3)), false, 1.5)
			for i in 3:
				var ex := -w * 0.35 + w * 0.35 * i
				var ey := -fposmod(_phase * 25.0 + i * 47.0, h)
				draw_circle(Vector2(ex, ey), 2.0, tint(Color(orange, 0.6)))
