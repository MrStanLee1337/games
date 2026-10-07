@tool
class_name Voronka
extends Anomaly
## Воронка: большой радиус притяжения (слабее к краю) и маленькое ядро с постоянным уроном.
## При инверсии (артефакт Грави) притяжение превращается в отталкивание.

@export var radius := 200.0:
	set(v):
		radius = v
		_rebuild()
@export var core_radius := 22.0:
	set(v):
		core_radius = v
		_rebuild()
## Сила притяжения у самого ядра, px/с².
@export var pull := 4000.0
## Урон ядра, HP в секунду.
@export var core_dps := 25.0
## Огненный смерч: урон в кольце вокруг ядра, HP/с при fire = 1.
@export var fire_dps := 18.0

## 0..2: сколько горящих Жарок затягивает Воронка (AnomalyInteractions).
var fire := 0.0
var _fire_target := 0.0


func _init() -> void:
	anomaly_type = Type.VORONKA


func _apply_shape(s: float) -> void:
	(_shape_node.shape as CircleShape2D).radius = radius * s


func _extent() -> float:
	return radius * scale_factor()


## Стрелку рисуем у ядра, а не на краю огромной зоны.
func top_point() -> Vector2:
	return global_position + Vector2(0.0, -core_radius * scale_factor() - 18.0)


func set_fire(v: float) -> void:
	_fire_target = v


## Кольцо огненного смерча: от ... до ... (px от центра).
func fire_ring() -> Vector2:
	var core := core_radius * scale_factor()
	return Vector2(core * 1.6, core * 5.0)


func debug_extra() -> String:
	return "огонь %.2f" % fire if fire > 0.01 else ""


func _reset_extra() -> void:
	fire = 0.0
	_fire_target = 0.0


func _tick(delta: float) -> void:
	fire = move_toward(fire, 0.0 if is_asleep() else _fire_target, 1.5 * delta)
	if is_asleep():
		return
	if fire > 0.01:
		var ring := fire_ring()
		for p in _players():
			var d := p.global_position.distance_to(global_position)
			if d >= ring.x and d <= ring.y:
				p.damage_over_time(dmg(fire_dps) * fire * delta)
	var rr := radius * scale_factor()
	var core := core_radius * scale_factor()
	var sign_f := -1.0 if inverted else 1.0
	for body in _bodies:
		var offset := global_position - body.global_position
		var d := offset.length()
		if d < 0.001:
			continue
		var dir := offset / d
		var f := pull * current_intensity * clampf(1.0 - d / rr, 0.0, 1.0) * sign_f
		if body is Player:
			var p := body as Player
			p.add_external_force(dir * f)
			if d < core:
				p.damage_over_time(dmg(core_dps) * delta)
		elif body is Bolt:
			var b := body as Bolt
			b.apply_central_force(dir * f * b.mass)
			if d < core and not inverted:
				b.absorb()
		elif body is WorldArtifact:
			var wa := body as WorldArtifact
			if inverted:
				wa.release(-dir * 260.0)  # Грави выталкивает артефакт с орбиты
				wa.apply_central_force(dir * f * wa.mass)
			else:
				wa.capture(self, clampf(d, core * 3.0, rr * 0.45))


func _draw() -> void:
	var rr := radius * scale_factor()
	var core := core_radius * scale_factor()
	var live := not Engine.is_editor_hint()
	if live and is_asleep():
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 48, Color(0.7, 0.7, 0.7, 0.07), 1.0)
		draw_circle(Vector2.ZERO, core * 0.6, Color(0.4, 0.4, 0.4, 0.15))
		return
	var purple := Color("a066ff")
	draw_arc(Vector2.ZERO, rr, 0.0, TAU, 48, tint(Color(purple, 0.18)), 1.0)
	draw_circle(Vector2.ZERO, core, tint(Color("1b0f2e", 0.95)))
	draw_arc(Vector2.ZERO, core, 0.0, TAU, 24, tint(Color(purple, 0.9)), 2.0)
	# Спиральные «частицы» движутся к ядру (от ядра — при инверсии).
	var flow := -1.0 if inverted else 1.0
	var arms := 5
	var dots := 9
	for k in arms:
		for j in dots:
			var u := fposmod(float(j) / dots - _phase * 0.3 * flow, 1.0)
			var rad := lerpf(core, rr, u)
			var ang := k * TAU / arms + (1.0 - u) * 2.5 + _phase * 0.8 * flow
			var pos := Vector2.from_angle(ang) * rad
			var near := 1.0 - u
			draw_circle(pos, 1.5 + 2.0 * near, tint(Color(purple, 0.25 + 0.65 * near)))
	if fire > 0.01:
		# Огненный смерч: оранжевые языки кружат вокруг ядра.
		var ring := fire_ring()
		draw_arc(Vector2.ZERO, (ring.x + ring.y) * 0.5, 0.0, TAU, 48, Color(1.0, 0.45, 0.1, 0.07 * fire), ring.y - ring.x)
		for k in 14:
			var u := fposmod(k / 14.0 + _phase * 0.5 * flow, 1.0)
			var rad := lerpf(ring.x, ring.y, fposmod(k * 0.37, 1.0))
			var pos := Vector2.from_angle(u * TAU + _phase * 2.0 * flow) * rad
			draw_circle(pos, 2.5 + 2.0 * fire, Color(1.0, 0.6 + 0.3 * fposmod(k * 0.5, 1.0), 0.15, 0.85))
