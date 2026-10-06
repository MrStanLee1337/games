class_name BeltAura
extends Node2D
## Аура артефактов на поясе. ~14 раз в секунду собирает аномалии в радиусе и передаёт каждой
## итоговый модификатор. Аномалия вне ауры возвращается к базовой интенсивности.
## Также рисует обратную связь (круг, линии, стрелки) и применяет пассивные эффекты игроку.

@export var radius := 160.0
@export var rate_hz := 14.0

const UP_COLOR := Color("ff8a5a")
const DOWN_COLOR := Color("6fd6ff")

var _player: Player
var _acc := 0.0
var _t := 0.0
var _aura_color := Color.WHITE
var _has_belt := false
## Anomaly -> {colors: Array[Color], trend: int, inverted: bool}
var _info: Dictionary = {}


func _ready() -> void:
	_player = get_parent() as Player
	z_index = 5
	_player.inventory.changed.connect(_on_inventory_changed)
	_on_inventory_changed()


func _physics_process(delta: float) -> void:
	_acc += delta
	if _acc >= 1.0 / rate_hz:
		_acc = 0.0
		_update()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_inventory_changed() -> void:
	var arts := _player.inventory.belt_artifacts()
	_has_belt = not arts.is_empty()
	var jump := 1.0
	var grav := 1.0
	var regen := 0.0
	var sum := Color(0, 0, 0, 0)
	for art in arts:
		jump *= art.passives.get("jump_mult", 1.0)
		grav *= art.passives.get("gravity_mult", 1.0)
		regen += art.passives.get("regen", 0.0)
		sum += art.color
	_player.jump_multiplier = jump
	_player.gravity_multiplier = grav
	_player.regen_per_sec = regen
	if _has_belt:
		_aura_color = Color(sum.r / arts.size(), sum.g / arts.size(), sum.b / arts.size(), 1.0)
	_update()


func _update() -> void:
	var arts := _player.inventory.belt_artifacts()
	_info.clear()
	for node in get_tree().get_nodes_in_group(&"anomalies"):
		var a := node as Anomaly
		if a == null:
			continue
		if arts.is_empty() or a.edge_distance(_player.global_position) > radius:
			a.clear_modifier()
			continue
		var mult := 1.0
		var inv := false
		var dmg := 1.0
		var cols: Array[Color] = []
		for art in arts:
			var hit := false
			for e in art.effects:
				if e["type"] != a.anomaly_type:
					continue
				hit = true
				mult *= e.get("mult", 1.0)
				if e.get("inverted", false):
					inv = not inv  # две инверсии гасят друг друга
				dmg *= e.get("damage_mult", 1.0)
			if hit:
				cols.append(art.color)
		if cols.is_empty():
			a.clear_modifier()
			continue
		a.set_modifier(mult, inv, dmg)
		var trend := 0
		if mult > 1.001:
			trend = 1
		elif mult < 0.999:
			trend = -1
		elif dmg < 0.999:
			trend = -1
		elif dmg > 1.001:
			trend = 1
		_info[a] = {"colors": cols, "trend": trend, "inverted": inv}


func _draw() -> void:
	if not _has_belt:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	draw_circle(Vector2.ZERO, radius, Color(_aura_color, 0.025))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(_aura_color, 0.12 + 0.06 * pulse), 1.5)
	for key in _info:
		if not is_instance_valid(key):
			continue
		var a := key as Anomaly
		var info: Dictionary = _info[a]
		var cols: Array[Color] = info["colors"]
		var target := to_local(a.visual_center())
		var dir := target.normalized()
		var perp := dir.orthogonal()
		for i in cols.size():
			var off := perp * (float(i) - (cols.size() - 1) * 0.5) * 3.0
			draw_line(off, target + off, Color(cols[i], 0.6), 1.5)
			draw_circle(target + off, 3.0, Color(cols[i], 0.8))
		_draw_marks(to_local(a.top_point()), info["trend"], info["inverted"])


## Над аномалией: ▲ — разгорается, ▼ — затухает; пара ▲▼ — сила инвертирована.
func _draw_marks(p: Vector2, trend: int, inverted: bool) -> void:
	var bob := Vector2(0.0, sin(_t * 5.0) * 1.5)
	var pos := p + bob
	if inverted:
		_arrow(pos + Vector2(-7.0, 0.0), true, Color("e8ecf4"), 5.0)
		_arrow(pos + Vector2(7.0, 0.0), false, Color("e8ecf4"), 5.0)
		pos += Vector2(0.0, -14.0)
	if trend != 0:
		_arrow(pos, trend > 0, UP_COLOR if trend > 0 else DOWN_COLOR, 8.0)


func _arrow(c: Vector2, up: bool, col: Color, s: float) -> void:
	var d := 1.0 if up else -1.0
	var pts := PackedVector2Array([c + Vector2(0.0, -s * d), c + Vector2(-s * 0.85, s * 0.6 * d), c + Vector2(s * 0.85, s * 0.6 * d)])
	draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	var inner := PackedVector2Array([c + Vector2(0.0, -s * 0.7 * d), c + Vector2(-s * 0.6, s * 0.45 * d), c + Vector2(s * 0.6, s * 0.45 * d)])
	draw_colored_polygon(inner, col)
