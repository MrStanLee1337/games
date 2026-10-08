class_name ArtifactDb
extends RefCounted
## Таблица всех предметов и синергий. Баланс правится здесь — остальной код не трогаем.
##
## Артефакт:
##   id, name, desc, color, shape
##   effects:  [{type, mult, inverted, damage_mult}]  — как артефакт меняет аномалии в ауре.
##             mult — множитель интенсивности (по умолчанию 1), inverted — инверсия силы,
##             damage_mult — отдельный множитель урона (по умолчанию 1),
##             form — качественное превращение аномалии (см. FORM_NAMES), а не просто множитель.
##   passives: {jump_mult, gravity_mult, regen, grants_dash} — пассивные эффекты игроку.
##             jump_mult — множитель высоты прыжка; gravity_mult — гравитации при той же высоте
##             (прыжок дольше и дальше); grants_dash — даёт рывок (Shift).
## Расходник: id, name, desc, color, shape, heal.

const ANOMALY_NAMES := {
	Anomaly.Type.ZHARKA: "Жарка",
	Anomaly.Type.ELECTRA: "Электра",
	Anomaly.Type.TRAMPLIN: "Трамплин",
	Anomaly.Type.VORONKA: "Воронка",
	Anomaly.Type.KHOLODETS: "Холодец",
}

## Качественные превращения аномалий: аномалия получает form и меняет поведение и вид.
const FORM_NAMES := {
	&"steam": "столб пара — поднимает вверх",
	&"battery": "разряды копятся в заряд",
	&"jelly": "желе — пружинит",
	&"float": "поле парения",
}

const ARTIFACTS: Array[Dictionary] = [
	{
		"id": &"kaplya", "name": "Капля",
		"desc": "Холодная капля. Огонь рядом с ней превращается в пар, но вода хорошо проводит ток.",
		"color": Color("5aa9ef"), "shape": ItemData.Shape.DROP,
		"effects": [
			{"type": Anomaly.Type.ZHARKA, "form": &"steam"},
			{"type": Anomaly.Type.ELECTRA, "mult": 1.6},
		],
	},
	{
		"id": &"batareyka", "name": "Батарейка",
		"desc": "Забирает разряды Электр в заряд. Shift с зарядом — усиленный рывок.
Четвёртый заряд — перегрузка.",
		"color": Color("f2c14e"), "shape": ItemData.Shape.SQUARE,
		"effects": [
			{"type": Anomaly.Type.ELECTRA, "form": &"battery"},
		],
	},
	{
		"id": &"pruzhina", "name": "Пружина",
		"desc": "Заставляет трамплины подбрасывать намного выше.",
		"color": Color("9be564"), "shape": ItemData.Shape.DIAMOND,
		"effects": [
			{"type": Anomaly.Type.TRAMPLIN, "mult": 2.0},
		],
		"passives": {"jump_mult": 1.3},
	},
	{
		"id": &"gravi", "name": "Грави",
		"desc": "Выворачивает притяжение наизнанку, а трамплины превращает в поле парения.",
		"color": Color("a066ff"), "shape": ItemData.Shape.CIRCLE,
		"effects": [
			{"type": Anomaly.Type.VORONKA, "inverted": true},
			{"type": Anomaly.Type.TRAMPLIN, "form": &"float"},
		],
		"passives": {"gravity_mult": 0.75},
	},
	{
		"id": &"vspyshka", "name": "Вспышка",
		"desc": "Рождается в Электре. Даёт рывок (Shift), но Электры рядом злее.",
		"color": Color("8fd3ff"), "shape": ItemData.Shape.BOLT,
		"effects": [
			{"type": Anomaly.Type.ELECTRA, "mult": 1.4},
		],
		"passives": {"grants_dash": true},
	},
	{
		"id": &"meduza", "name": "Медуза",
		"desc": "Холодец застывает в упругое желе: не жжёт и не липнет, а пружинит.",
		"color": Color("ff7ad9"), "shape": ItemData.Shape.HEXAGON,
		"effects": [
			{"type": Anomaly.Type.KHOLODETS, "form": &"jelly"},
		],
		"passives": {"regen": 1.0},
	},
	{
		"id": &"plamya", "name": "Пламя",
		"desc": "Высушивает лужи, но раздувает огонь.",
		"color": Color("ff8a2b"), "shape": ItemData.Shape.TRIANGLE,
		"effects": [
			{"type": Anomaly.Type.KHOLODETS, "mult": 0.0},
			{"type": Anomaly.Type.ZHARKA, "mult": 1.8},
		],
	},
]

const CONSUMABLES: Array[Dictionary] = [
	{
		"id": &"aptechka", "name": "Аптечка",
		"desc": "Восстанавливает 50 HP.",
		"color": Color("ef4f4f"), "shape": ItemData.Shape.CROSS, "heal": 50.0,
	},
	{
		"id": &"bint", "name": "Бинт",
		"desc": "Восстанавливает 20 HP.",
		"color": Color("5aa9ef"), "shape": ItemData.Shape.BAR, "heal": 20.0,
	},
]


## Создаёт новый экземпляр предмета по id; null, если такого нет.
static func make(id: StringName) -> ItemData:
	for d in ARTIFACTS:
		if d["id"] == id:
			return _build(d, ItemData.Kind.ARTIFACT)
	for d in CONSUMABLES:
		if d["id"] == id:
			return _build(d, ItemData.Kind.CONSUMABLE)
	push_warning("ArtifactDb: нет предмета «%s»" % id)
	return null


static func artifact_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for d in ARTIFACTS:
		out.append(d["id"])
	return out


## Текстовое описание синергий для подсказки.
static func describe(item: ItemData) -> Array[String]:
	var lines: Array[String] = []
	for e in item.effects:
		var parts: Array[String] = []
		var mult: float = e.get("mult", 1.0)
		if e.has("form"):
			parts.append(FORM_NAMES.get(e["form"], String(e["form"])))
		if e.get("inverted", false):
			parts.append("инверсия")
		if not is_equal_approx(mult, 1.0):
			parts.append("×%s %s" % [_num(mult), "▲" if mult > 1.0 else "▼"])
		var dm: float = e.get("damage_mult", 1.0)
		if not is_equal_approx(dm, 1.0):
			parts.append("урон ×%s" % _num(dm))
		lines.append("%s: %s" % [ANOMALY_NAMES[e["type"]], ", ".join(parts)])
	var jm: float = item.passives.get("jump_mult", 1.0)
	if not is_equal_approx(jm, 1.0):
		lines.append("Высота прыжка ×%s" % _num(jm))
	var gm: float = item.passives.get("gravity_mult", 1.0)
	if not is_equal_approx(gm, 1.0):
		lines.append("Гравитация ×%s" % _num(gm))
	if item.passives.get("grants_dash", false):
		lines.append("Рывок (Shift)")
	var rg: float = item.passives.get("regen", 0.0)
	if rg > 0.0:
		lines.append("Регенерация %s HP/с" % _num(rg))
	return lines


static func _build(d: Dictionary, kind: ItemData.Kind) -> ItemData:
	var it := ItemData.new()
	it.id = d["id"]
	it.display_name = d["name"]
	it.description = d["desc"]
	it.kind = kind
	it.color = d["color"]
	it.shape = d["shape"]
	it.heal = d.get("heal", 0.0)
	it.effects.assign(d.get("effects", []))
	it.passives = d.get("passives", {})
	return it


static func _num(v: float) -> String:
	return ("%.2f" % v).rstrip("0").rstrip(".")
