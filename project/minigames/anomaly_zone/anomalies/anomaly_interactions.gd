class_name AnomalyInteractions
extends Node2D
## Взаимодействия аномалий друг с другом. Аномалии друг о друге не знают: ~10 раз в секунду
## эта система находит пары по правилам из RULES и вызывает у них методы (add_dryness,
## set_flame_pull, set_fire, electrify). Сила связи растёт с интенсивностью аномалий.
## Рисует пунктир между связанными аномалиями и вспышку тока по луже.

const RULES := {
	## Горящая Жарка сушит Холодец: в радиусе жара (reach × I Жарки) копится сухость
	## (rate × I в секунду); на 1.0 лужа высыхает насовсем.
	&"heat": {"reach": 45.0, "rate": 0.6, "color": Color("ff8a2b")},
	## Электра, касающаяся Холодца (зазор ≤ reach), пускает разряд по всей луже:
	## всем в луже — контакт с этой Электрой с уроном share × урон разряда.
	&"current": {"reach": 6.0, "share": 0.8, "color": Color("6fd6ff")},
	## Воронка затягивает пламя Жарки, если Жарка в её радиусе: столб отклоняется к ядру
	## на bend × ширину × min(1, 0.6 × I Воронки).
	## Пока Жарка горит, вокруг ядра крутится огненный смерч.
	&"draft": {"bend": 1.3, "color": Color("ff6a3d")},
}

@export var rate_hz := 10.0

var _acc := 0.0
var _t := 0.0
## {a: Anomaly, b: Anomaly, color: Color}
var _links: Array[Dictionary] = []
## {a: Anomaly, b: Anomaly, t: float}
var _flashes: Array[Dictionary] = []


func _ready() -> void:
	add_to_group(&"anomaly_interactions")
	z_index = 4


func _physics_process(delta: float) -> void:
	_acc += delta
	if _acc >= 1.0 / rate_hz:
		_update(_acc)
		_acc = 0.0


func _process(delta: float) -> void:
	_t += delta
	for i in range(_flashes.size() - 1, -1, -1):
		_flashes[i]["t"] -= delta
		if _flashes[i]["t"] <= 0.0:
			_flashes.remove_at(i)
	queue_redraw()


func _update(dt: float) -> void:
	var zharkas: Array[Zharka] = []
	var pools: Array[Kholodets] = []
	var electras: Array[Electra] = []
	var voronkas: Array[Voronka] = []
	for n in get_tree().get_nodes_in_group(&"anomalies"):
		if n is Zharka:
			zharkas.append(n as Zharka)
		elif n is Kholodets:
			pools.append(n as Kholodets)
		elif n is Electra:
			electras.append(n as Electra)
		elif n is Voronka:
			voronkas.append(n as Voronka)
	_links.clear()

	# Жар: горящая Жарка сушит лужу.
	var heat: Dictionary = RULES[&"heat"]
	for z in zharkas:
		if z.state != Anomaly.State.ACTIVE or z.is_asleep():
			continue
		var reach: float = heat["reach"] * z.current_intensity
		for k in pools:
			if k.dried or Anomaly.rect_gap(z.world_bounds(), k.world_bounds()) > reach:
				continue
			k.add_dryness(heat["rate"] * z.current_intensity * dt)
			_links.append({"a": z, "b": k, "color": heat["color"]})

	# Ток: Электра касается лужи (сам разряд — в on_discharge).
	var current: Dictionary = RULES[&"current"]
	for e in electras:
		if e.is_asleep():
			continue
		for k in pools:
			if not k.is_asleep() and Anomaly.rect_gap(e.world_bounds(), k.world_bounds()) <= current["reach"]:
				_links.append({"a": e, "b": k, "color": Color(current["color"], 0.5)})

	# Тяга: Воронка затягивает пламя Жарки.
	var draft: Dictionary = RULES[&"draft"]
	var fire: Dictionary = {}
	for z in zharkas:
		var dx := 0.0
		for v in voronkas:
			if v.is_asleep():
				continue
			if v.global_position.distance_to(z.visual_center()) > v.radius * v.scale_factor():
				continue
			var side := signf(v.global_position.x - z.global_position.x)
			dx += side * z.size.x * z.scale_factor() * draft["bend"] * minf(1.0, 0.6 * v.current_intensity)
			_links.append({"a": v, "b": z, "color": draft["color"]})
			if z.state == Anomaly.State.ACTIVE and not z.is_asleep():
				fire[v] = fire.get(v, 0.0) + z.current_intensity
		z.set_flame_pull(dx)
	for v in voronkas:
		v.set_fire(minf(2.0, fire.get(v, 0.0)))


## Электра разрядилась: если она касается лужи, ток проходит по всей луже.
func on_discharge(e: Electra) -> void:
	var current: Dictionary = RULES[&"current"]
	for n in get_tree().get_nodes_in_group(&"anomalies"):
		var k := n as Kholodets
		if k == null or k.is_asleep():
			continue
		if Anomaly.rect_gap(e.world_bounds(), k.world_bounds()) <= current["reach"]:
			k.electrify(e.get_instance_id(), current["share"])
			_flashes.append({"a": e, "b": k, "t": 0.35})


func _draw() -> void:
	for l in _links:
		if not is_instance_valid(l["a"]) or not is_instance_valid(l["b"]):
			continue
		var a := l["a"] as Anomaly
		var b := l["b"] as Anomaly
		var col: Color = l["color"]
		draw_dashed_line(a.visual_center(), b.visual_center(), Color(col, col.a * (0.45 + 0.2 * sin(_t * 6.0))), 2.0, 10.0)
	for f in _flashes:
		if not is_instance_valid(f["a"]) or not is_instance_valid(f["b"]):
			continue
		var from := (f["a"] as Anomaly).visual_center()
		var to := (f["b"] as Anomaly).visual_center()
		var pts := PackedVector2Array()
		for i in 9:
			var p := from.lerp(to, i / 8.0)
			if i > 0 and i < 8:
				p += Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
			pts.append(p)
		draw_polyline(pts, Color("e8fbff", 0.9), 2.0)
