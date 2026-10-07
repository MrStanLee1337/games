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


func _init() -> void:
	anomaly_type = Type.VORONKA


func _apply_shape(s: float) -> void:
	(_shape_node.shape as CircleShape2D).radius = radius * s


func _extent() -> float:
	return radius * scale_factor()


## Стрелку рисуем у ядра, а не на краю огромной зоны.
func top_point() -> Vector2:
	return global_position + Vector2(0.0, -core_radius * scale_factor() - 18.0)


func _tick(delta: float) -> void:
	if is_asleep():
		return
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
