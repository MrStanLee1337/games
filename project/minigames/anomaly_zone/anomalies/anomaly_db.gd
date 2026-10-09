class_name AnomalyDb
extends RefCounted
## Таблица аномалий забега: урон за контакт и что игрок получает взамен. Поведение аномалий
## (вспышки, разряды, притяжение) задают их сцены; здесь — только числа баланса.
## Контакт обрабатывает Player.on_anomaly_contact(): множители артефактов, неуязвимость,
## задержка повтора.
##
## Сила баффа и артефакты (PlayerStats.buff_mult по типу):
##   Жарка — Форсаж: бег × (1 + (strength − 1) · buff_mult) на duration × buff_duration_mult;
##   Трамплин — высота подброса launch × buff_mult (скорость от текущей гравитации: v = √(2·g·h)),
##     плюс Лёгкость: высота прыжка × strength;
##   Электра — +1 заряд рывка (предел — PlayerStats.max_charges), оглушение stun;
##   Воронка — Праща: на выходе из зоны притяжения скорость сохраняется до cap × бег × buff_mult,
##     overspeed_drag выключен на duration;
##   Холодец — внутри бег × min(1, run × buff_mult) и лечение heal × heal_mult HP/с.

## Одна и та же аномалия даёт бафф не чаще, чем раз в столько секунд.
const REPEAT_DELAY := 1.0

const DATA := {
	Anomaly.Type.ZHARKA: {"damage": 12.0, "buff": &"forsazh", "strength": 1.35, "duration": 3.0},
	Anomaly.Type.TRAMPLIN: {"damage": 8.0, "buff": &"legkost", "strength": 1.25, "duration": 3.0, "launch": 190.0},
	Anomaly.Type.ELECTRA: {"damage": 15.0, "stun": 0.15, "charges": 1},
	Anomaly.Type.VORONKA: {"dps": 6.0, "buff": &"prashcha", "cap": 2.0, "duration": 1.5},
	Anomaly.Type.KHOLODETS: {"damage": 0.0, "run": 0.6, "heal": 6.0},
}

## Баффы с таймером: имя, цвет и тип аномалии-источника (для иконок HUD).
const BUFFS := {
	&"forsazh": {"name": "Форсаж", "color": Color("ff8a2b"), "type": Anomaly.Type.ZHARKA},
	&"legkost": {"name": "Лёгкость", "color": Color("9be564"), "type": Anomaly.Type.TRAMPLIN},
	&"prashcha": {"name": "Праща", "color": Color("a066ff"), "type": Anomaly.Type.VORONKA},
}

const TYPE_COLORS := {
	Anomaly.Type.ZHARKA: Color("ff8a2b"),
	Anomaly.Type.ELECTRA: Color("6fd6ff"),
	Anomaly.Type.TRAMPLIN: Color("9be564"),
	Anomaly.Type.VORONKA: Color("a066ff"),
	Anomaly.Type.KHOLODETS: Color("6bff6b"),
}


static func get_data(type: Anomaly.Type) -> Dictionary:
	return DATA[type]


## Значок типа аномалии (бафф, тег артефакта, дверь развилки) примитивами; r — радиус.
static func draw_type_icon(ci: CanvasItem, type: int, c: Vector2, r: float, col: Color = Color.WHITE) -> void:
	match type:
		Anomaly.Type.ZHARKA:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.7, r * 0.6),
				c + Vector2(0, r * 0.25), c + Vector2(-r * 0.7, r * 0.6)]), col)
		Anomaly.Type.ELECTRA:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.15, -r), c + Vector2(-r * 0.55, r * 0.1),
				c + Vector2(-r * 0.05, r * 0.1), c + Vector2(-r * 0.2, r), c + Vector2(r * 0.55, -r * 0.15),
				c + Vector2(r * 0.05, -r * 0.15)]), col)
		Anomaly.Type.TRAMPLIN:
			ci.draw_line(c + Vector2(0, r * 0.8), c + Vector2(0, -r * 0.6), col, maxf(1.5, r * 0.25))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.6, -r * 0.3),
				c + Vector2(-r * 0.6, -r * 0.3)]), col)
		Anomaly.Type.VORONKA:
			var pts := PackedVector2Array()
			for i in 18:
				var a := i * 0.6
				pts.append(c + Vector2.from_angle(a) * r * (1.0 - i / 20.0))
			ci.draw_polyline(pts, col, maxf(1.5, r * 0.2))
		Anomaly.Type.KHOLODETS:
			ci.draw_circle(c + Vector2(0, r * 0.25), r * 0.65, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.55, 0),
				c + Vector2(-r * 0.55, 0)]), col)
		_:
			# Универсальный: четырёхлучевая звезда.
			var st := PackedVector2Array()
			for i in 8:
				var rr := r if i % 2 == 0 else r * 0.38
				st.append(c + Vector2.from_angle(i * TAU / 8.0 - PI / 2.0) * rr)
			ci.draw_colored_polygon(st, col)
