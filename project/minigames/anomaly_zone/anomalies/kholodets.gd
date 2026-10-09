@tool
class_name Kholodets
extends Anomaly
## Холодец: лужа на полу. Замедляет игрока, наносит урон со временем.
## Начало координат — середина нижнего края лужи (на уровне пола).

@export var size := Vector2(200.0, 18.0):
	set(v):
		size = v
		_rebuild()
## Урон, HP в секунду.
@export var dps := 6.0

## Сухость от жара Жарки: при 1 лужа высыхает насовсем (до сброса аномалий при смерти).
var dryness := 0.0
var dried := false
var _shock_t := 0.0
var _shock_pts: Array[PackedVector2Array] = []


func _init() -> void:
	anomaly_type = Type.KHOLODETS


func _apply_shape(s: float) -> void:
	var sz := Vector2(size.x * s, size.y)
	(_shape_node.shape as RectangleShape2D).size = sz
	_shape_node.position = Vector2(0.0, -sz.y * 0.5)


func _new_shape() -> Shape2D:
	return RectangleShape2D.new()


func target_intensity() -> float:
	return 0.0 if dried else super.target_intensity()


func world_bounds() -> Rect2:
	return _world_rect()


func add_dryness(v: float) -> void:
	if dried:
		return
	dryness = minf(1.0, dryness + v)
	if dryness >= 1.0:
		dried = true


## Разряд Электры, касающейся лужи, проходит по всей луже.
func electrify(damage: float, stun_time: float) -> void:
	for p in _players():
		p.take_damage(damage, Vector2(0.0, -1.0), true)
		p.stun(stun_time)
	_shock_t = 0.35
	_make_shock()


func debug_extra() -> String:
	if dried:
		return "высохла"
	return "сухость %.2f" % dryness if dryness > 0.0 else ""


func _reset_extra() -> void:
	dryness = 0.0
	dried = false
	_shock_t = 0.0


func _make_shock() -> void:
	_shock_pts.clear()
	var w := size.x * scale_factor()
	for k in 3:
		var pts := PackedVector2Array()
		var segs := 16
		for i in segs + 1:
			pts.append(Vector2(-w * 0.5 + w * i / segs, -size.y * randf_range(0.2, 1.1)))
		_shock_pts.append(pts)


func _world_rect() -> Rect2:
	var w := size.x * scale_factor()
	return Rect2(global_position + Vector2(-w * 0.5, -size.y), Vector2(w, size.y))


func edge_distance(p: Vector2) -> float:
	return _rect_distance(p, _world_rect())


func top_point() -> Vector2:
	return Vector2(global_position.x, global_position.y - size.y - 16.0)


func _tick(delta: float) -> void:
	if _shock_t > 0.0:
		_shock_t -= delta
		if int(_shock_t * 30.0) % 2 == 0:
			_make_shock()
	if is_asleep():
		return
	var slow := clampf(1.0 - 0.5 * current_intensity, 0.2, 1.0)
	for p in _players():
		p.set_move_multiplier(slow)
		p.damage_over_time(dmg(dps) * delta)


func _draw() -> void:
	var w := size.x * scale_factor()
	var h := size.y
	var live := not Engine.is_editor_hint()
	if live and dryness > 0.0 and not dried:
		var bw := minf(80.0, w * 0.6)
		draw_rect(Rect2(-bw * 0.5, -h - 14.0, bw, 5.0), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-bw * 0.5, -h - 14.0, bw * dryness, 5.0), Color("ff8a2b"))
	if live and dried:
		# Высохла насовсем: потрескавшаяся корка.
		draw_rect(Rect2(-w * 0.5, -4.0, w, 4.0), Color(0.45, 0.38, 0.28, 0.75))
		var x := -w * 0.5 + 10.0
		while x < w * 0.5 - 10.0:
			draw_line(Vector2(x, -4.0), Vector2(x + 6.0, 0.0), Color(0.2, 0.17, 0.12, 0.9), 1.0)
			x += 23.0
		return
	if live and is_asleep():
		draw_rect(Rect2(-w * 0.5, -3.0, w, 3.0), Color(0.5, 0.45, 0.35, 0.3))
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
	if _shock_t > 0.0:
		for sp in _shock_pts:
			draw_polyline(sp, Color("e8fbff", 0.9), 1.5)
