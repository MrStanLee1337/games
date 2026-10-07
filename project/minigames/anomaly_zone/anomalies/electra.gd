@tool
class_name Electra
extends Anomaly
## Электра: сфера. Что-то вошло → почти мгновенный разряд (урон, отброс, оглушение) → ~2 с безопасна.

@export var radius := 60.0:
	set(v):
		radius = v
		_rebuild()
@export var damage := 25.0
@export var stun_time := 0.3
## Сила отброса от центра, px/с.
@export var knock_impulse := 460.0
@export var discharge_time := 0.25
@export var cooldown_time := 2.0

var _zigzags: Array[PackedVector2Array] = []
var _regen_t := 0.0
## Куда ушёл разряд в Батарейку (для вспышки) и сколько ещё её рисовать.
var _charge_to := Vector2.ZERO
var _charge_t := 0.0


func _init() -> void:
	anomaly_type = Type.ELECTRA


func _apply_shape(s: float) -> void:
	(_shape_node.shape as CircleShape2D).radius = radius * s


func _extent() -> float:
	return radius * scale_factor()


func _reset_extra() -> void:
	_zigzags.clear()


func _on_state(s: State) -> void:
	if s != State.ACTIVE:
		return
	var center := global_position
	if form == &"battery":
		_discharge_into_battery()
		_regen_bolts(7)
		return
	for p in _players():
		var away := (p.global_position - center).normalized()
		if away == Vector2.ZERO:
			away = Vector2.UP
		away.y = minf(away.y, -0.45)  # отброс слегка вверх, чтобы не «прилипать» к полу
		p.take_damage(dmg(damage), Vector2.ZERO, true)
		p.apply_impulse(away * knock_impulse, stun_time)
		p.stun(stun_time)
	for b in _bolts():
		b.linear_velocity = (b.global_position - center).normalized() * 320.0
	# Разряд может уйти в лужу Холодца, которой касается Электра.
	get_tree().call_group(&"anomaly_interactions", &"on_discharge", self)
	_regen_bolts(7)


## Форма «батарейка»: разряд никого не бьёт, а уходит в Батарейку на поясе игрока
## (если пояс достаёт до Электры); брошенная Батарейка просто поглощает разряд.
func _discharge_into_battery() -> void:
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p and p.has_belt_artifact(&"batareyka") and edge_distance(p.global_position) <= p.aura_radius:
		p.absorb_discharge()
		_charge_to = p.global_position
		_charge_t = 0.3


func _tick(delta: float) -> void:
	var r := scale_factor()
	_charge_t -= delta
	_regen_t -= delta
	match state:
		State.IDLE:
			if is_asleep():
				_zigzags.clear()
				return
			if _has_provoker():
				_set_state(State.ACTIVE)
			elif _regen_t <= 0.0:
				_regen_bolts(2)
		State.ACTIVE:
			if _regen_t <= 0.0:
				_regen_bolts(7)
			if _state_t >= discharge_time:
				_zigzags.clear()
				_set_state(State.COOLDOWN)
		State.COOLDOWN:
			if _state_t >= cooldown_time / r:
				_set_state(State.IDLE)


## Зигзаги Line2D-стиля: перегенерируются каждые несколько кадров.
func _regen_bolts(count: int) -> void:
	_regen_t = 0.07
	_zigzags.clear()
	var rr := radius * scale_factor()
	for i in count:
		var a := randf() * TAU
		var start := Vector2.from_angle(randf() * TAU) * rr * randf_range(0.0, 0.2)
		var length := rr * (randf_range(0.7, 1.0) if state == State.ACTIVE else randf_range(0.25, 0.5))
		var dir := Vector2.from_angle(a)
		var perp := dir.orthogonal()
		var pts := PackedVector2Array()
		var segs := 7
		for j in segs + 1:
			var t := float(j) / segs
			var jitter := 0.0 if j == 0 or j == segs else randf_range(-1.0, 1.0) * rr * 0.14
			pts.append(start + dir * length * t + perp * jitter)
		_zigzags.append(pts)


func _draw() -> void:
	var rr := radius * scale_factor()
	var live := not Engine.is_editor_hint()
	if live and is_asleep():
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(0.7, 0.7, 0.7, 0.12), 1.0)
		return
	var cyan := Color("6fd6ff")
	match state if live else State.IDLE:
		State.ACTIVE:
			draw_circle(Vector2.ZERO, rr, tint(Color(cyan, 0.22)))
			draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, tint(Color("e8fbff", 0.9)), 2.5)
		State.COOLDOWN:
			draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(0.55, 0.6, 0.68, 0.22), 1.5)
		_:
			var pulse := 0.5 + 0.5 * sin(_phase * 5.0)
			draw_circle(Vector2.ZERO, rr, tint(Color(cyan, 0.05 + 0.04 * pulse)))
			draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, tint(Color(cyan, 0.3 + 0.2 * pulse)), 1.5)
	var col := tint(Color("e8fbff", 0.95) if state == State.ACTIVE else Color(cyan, 0.8))
	for pts in _zigzags:
		draw_polyline(pts, col, 2.0 if state == State.ACTIVE else 1.5)
	if form == &"battery":
		draw_arc(Vector2.ZERO, rr + 4.0, 0.0, TAU, 40, Color("ffe46b", 0.6), 1.5)
		if _charge_t > 0.0:
			var to := to_local(_charge_to)
			var pts := PackedVector2Array()
			for i in 9:
				var q := Vector2.ZERO.lerp(to, i / 8.0)
				if i > 0 and i < 8:
					q += Vector2(randf_range(-7.0, 7.0), randf_range(-7.0, 7.0))
				pts.append(q)
			draw_polyline(pts, Color("ffe46b"), 2.0)
