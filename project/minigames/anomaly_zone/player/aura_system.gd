class_name AuraSystem
extends Node2D
## Общая система аур. ~14 раз в секунду собирает источники ауры (группа aura_sources: пояс игрока,
## артефакты, лежащие в мире) и для каждой аномалии перемножает модификаторы всех источников,
## которые до неё достают. Аномалия вне всех аур возвращается к базовой интенсивности.
## Рисует линии от источника к аномалии и стрелки ▲/▼ над аномалией (в мировых координатах).
##
## Источник ауры — любой узел в группе aura_sources с методами:
##   aura_origin() -> Vector2, aura_items() -> Array[ItemData], aura_radius() -> float

@export var rate_hz := 14.0

const UP_COLOR := Color("ff8a5a")
const DOWN_COLOR := Color("6fd6ff")

var _acc := 0.0
var _t := 0.0
## Anomaly -> {links: Array[Dictionary{source, color}], trend: int, inverted: bool}
var _info: Dictionary = {}


func _ready() -> void:
	add_to_group(&"aura_system")
	z_index = 5


func _physics_process(delta: float) -> void:
	_acc += delta
	if _acc >= 1.0 / rate_hz:
		_acc = 0.0
		refresh()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Немедленный пересчёт (например, после смены пояса).
func refresh() -> void:
	var sources := get_tree().get_nodes_in_group(&"aura_sources")
	_info.clear()
	for node in get_tree().get_nodes_in_group(&"anomalies"):
		var a := node as Anomaly
		if a == null:
			continue
		var mult := 1.0
		var inv := false
		var dmg := 1.0
		var new_form: StringName = &""
		var links: Array[Dictionary] = []
		for s in sources:
			var items: Array[ItemData] = s.call(&"aura_items")
			if items.is_empty():
				continue
			var origin: Vector2 = s.call(&"aura_origin")
			var r: float = s.call(&"aura_radius")
			if a.edge_distance(origin) > r:
				continue
			for art in items:
				var hit := false
				for e in art.effects:
					if e["type"] != a.anomaly_type:
						continue
					hit = true
					mult *= e.get("mult", 1.0)
					if e.get("inverted", false):
						inv = not inv  # две инверсии гасят друг друга
					dmg *= e.get("damage_mult", 1.0)
					if e.has("form"):
						new_form = e["form"]
				if hit:
					links.append({"source": s, "color": art.color})
		if links.is_empty():
			a.clear_modifier()
			continue
		a.set_modifier(mult, inv, dmg, new_form)
		var trend := 0
		if mult > 1.001:
			trend = 1
		elif mult < 0.999:
			trend = -1
		elif dmg < 0.999:
			trend = -1
		elif dmg > 1.001:
			trend = 1
		_info[a] = {"links": links, "trend": trend, "inverted": inv, "form": new_form}


## Круг ауры источника — общий вид для пояса и брошенных артефактов.
static func draw_ring(ci: CanvasItem, radius: float, col: Color, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	ci.draw_circle(Vector2.ZERO, radius, Color(col, 0.025))
	ci.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(col, 0.12 + 0.06 * pulse), 1.5)


func _draw() -> void:
	for key in _info:
		if not is_instance_valid(key):
			continue
		var a := key as Anomaly
		var info: Dictionary = _info[a]
		var target := a.visual_center()
		# Если один источник даёт несколько линий, разводим их на пару пикселей.
		var per_source: Dictionary = {}
		var links: Array[Dictionary] = info["links"]
		for link in links:
			if not is_instance_valid(link["source"]):
				continue  # источник подобрали или удалили между пересчётами
			var s: Object = link["source"]
			var origin: Vector2 = s.call(&"aura_origin")
			var idx: int = per_source.get(s, 0)
			per_source[s] = idx + 1
			var perp := (target - origin).normalized().orthogonal()
			var off := perp * idx * 3.0
			var col: Color = link["color"]
			draw_line(origin + off, target + off, Color(col, 0.6), 1.5)
			draw_circle(target + off, 3.0, Color(col, 0.8))
		_draw_marks(a.top_point(), info["trend"], info["inverted"], info["form"] != &"")


## Над аномалией: ▲ — разгорается, ▼ — затухает; пара ▲▼ — сила инвертирована;
## четырёхлучевая звезда — аномалия превращена во что-то другое (form).
func _draw_marks(p: Vector2, trend: int, inverted: bool, formed: bool) -> void:
	var pos := p + Vector2(0.0, sin(_t * 5.0) * 1.5)
	if formed:
		_star(pos, 8.0 + sin(_t * 4.0))
		pos += Vector2(0.0, -18.0)
	if inverted:
		_arrow(pos + Vector2(-7.0, 0.0), true, Color("e8ecf4"), 5.0)
		_arrow(pos + Vector2(7.0, 0.0), false, Color("e8ecf4"), 5.0)
		pos += Vector2(0.0, -14.0)
	if trend != 0:
		_arrow(pos, trend > 0, UP_COLOR if trend > 0 else DOWN_COLOR, 8.0)


func _star(c: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var r := s if i % 2 == 0 else s * 0.35
		pts.append(c + Vector2.from_angle(i * TAU / 8.0 - PI / 2.0) * r)
	draw_colored_polygon(pts, Color("f5f0ff"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.5), 1.0)


func _arrow(c: Vector2, up: bool, col: Color, s: float) -> void:
	var d := 1.0 if up else -1.0
	var pts := PackedVector2Array([c + Vector2(0.0, -s * d), c + Vector2(-s * 0.85, s * 0.6 * d), c + Vector2(s * 0.85, s * 0.6 * d)])
	draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	var inner := PackedVector2Array([c + Vector2(0.0, -s * 0.7 * d), c + Vector2(-s * 0.6, s * 0.45 * d), c + Vector2(s * 0.6, s * 0.45 * d)])
	draw_colored_polygon(inner, col)
