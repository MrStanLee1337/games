class_name ArtifactDb
extends RefCounted
## Таблица всех предметов. Баланс правится здесь — остальной код не трогаем.
##
## Артефакт забега: у каждого плюс и минус, вместе они меняют маршрут. Все взятые действуют сразу.
##   id, name, desc, color, shape, plus, minus (текст для карты и экрана билда),
##   tag — тип аномалии для карты «под билд» (-1 — универсальный), rarity — &"common" / &"rare",
##   damage_mult / buff_mult / buff_duration_mult — {Anomaly.Type: множитель} (смысл buff_mult — AnomalyDb),
##   heal_mult (лечение Холодца), run_mult, jump_mult, gravity_mult, max_hp_add, dash_charges_max,
##   aura (только Пламя), flags — уникальные правила (hp_speed, bengal, no_stun).
## Расходник: id, name, desc, color, shape, heal.

const ANOMALY_NAMES := {
	Anomaly.Type.ZHARKA: "Жарка",
	Anomaly.Type.ELECTRA: "Электра",
	Anomaly.Type.TRAMPLIN: "Трамплин",
	Anomaly.Type.VORONKA: "Воронка",
	Anomaly.Type.KHOLODETS: "Холодец",
}

const T_ZHARKA := Anomaly.Type.ZHARKA
const T_ELECTRA := Anomaly.Type.ELECTRA
const T_TRAMPLIN := Anomaly.Type.TRAMPLIN
const T_VORONKA := Anomaly.Type.VORONKA
const T_KHOLODETS := Anomaly.Type.KHOLODETS

const ARTIFACTS: Array[Dictionary] = [
	{
		"id": &"pruzhina", "name": "Пружина", "desc": "Трамплины мягче и подбрасывают выше, но ноги вязнут.",
		"color": Color("9be564"), "shape": ItemData.Shape.DIAMOND, "tag": T_TRAMPLIN, "rarity": &"common",
		"plus": "Трамплин: урон ×0.25, подброс ×1.4 (266 px)", "minus": "Обычный прыжок ×0.9",
		"damage_mult": {T_TRAMPLIN: 0.25}, "buff_mult": {T_TRAMPLIN: 1.4}, "jump_mult": 0.9,
	},
	{
		"id": &"plamya", "name": "Пламя", "desc": "Раздувает огонь вокруг и разгоняет того, кто в нём горит.",
		"color": Color("ff8a2b"), "shape": ItemData.Shape.TRIANGLE, "tag": T_ZHARKA, "rarity": &"common",
		"plus": "Форсаж вдвое сильнее: бег ×1.7; Жарки в 160 px на 30% шире и выше", "minus": "Урон Жарки ×1.5",
		"buff_mult": {T_ZHARKA: 2.0}, "damage_mult": {T_ZHARKA: 1.5},
		"aura": {"type": T_ZHARKA, "radius": 160.0, "size_mult": 1.3},
	},
	{
		"id": &"kaplya", "name": "Капля", "desc": "Холодная капля: огонь не обжигает, но и разгоняет недолго.",
		"color": Color("5aa9ef"), "shape": ItemData.Shape.DROP, "tag": T_ZHARKA, "rarity": &"common",
		"plus": "Жарка не ранит", "minus": "Форсаж длится 1.5 с вместо 3",
		"damage_mult": {T_ZHARKA: 0.0}, "buff_duration_mult": {T_ZHARKA: 0.5},
	},
	{
		"id": &"batareyka", "name": "Батарейка", "desc": "Принимает разряды Электр без оглушения.",
		"color": Color("f2c14e"), "shape": ItemData.Shape.SQUARE, "tag": T_ELECTRA, "rarity": &"common",
		"plus": "Электра не оглушает, зарядов рывка до 3", "minus": "Макс. HP −15",
		"flags": {&"no_stun": true}, "dash_charges_max": 3, "max_hp_add": -15.0,
	},
	{
		"id": &"meduza", "name": "Медуза", "desc": "Холодец для неё — родная стихия, а огонь и ток — враги.",
		"color": Color("ff7ad9"), "shape": ItemData.Shape.HEXAGON, "tag": T_KHOLODETS, "rarity": &"common",
		"plus": "Холодец лечит 12 HP/с, бег в нём ×0.9", "minus": "Урон Жарки и Электры ×1.2",
		"heal_mult": 2.0, "buff_mult": {T_KHOLODETS: 1.5}, "damage_mult": {T_ZHARKA: 1.2, T_ELECTRA: 1.2},
	},
	{
		"id": &"gravi", "name": "Грави", "desc": "Облегчает шаг и усиливает Пращу, но гасит Трамплины.",
		"color": Color("a066ff"), "shape": ItemData.Shape.CIRCLE, "tag": T_VORONKA, "rarity": &"rare",
		"plus": "Гравитация ×0.8, предел Пращи ×1.3 (728 px/с)", "minus": "Подброс Трамплина ×0.7",
		"gravity_mult": 0.8, "buff_mult": {T_VORONKA: 1.3, T_TRAMPLIN: 0.7},
	},
	{
		"id": &"kolyuchka", "name": "Колючка", "desc": "Чем больнее, тем быстрее ноги.",
		"color": Color("d8584a"), "shape": ItemData.Shape.SPIKE, "tag": -1, "rarity": &"rare",
		"plus": "Бег ×(1 + 0.4 · (1 − HP/HPмакс)): чем меньше HP, тем быстрее", "minus": "Холодец лечит вдвое слабее",
		"flags": {&"hp_speed": 0.4}, "heal_mult": 0.5,
	},
	{
		"id": &"bengal", "name": "Бенгальский огонь", "desc": "Искрит, пока аномалии идут одна за другой.",
		"color": Color("ffd24a"), "shape": ItemData.Shape.SPARK, "tag": -1, "rarity": &"rare",
		"plus": "Аномалия в течение 1.5 с после предыдущей продлевает все активные баффы на 1 с", "minus": "—",
		"flags": {&"bengal": {"window": 1.5, "extend": 1.0}},
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


## Строки для подсказки предмета.
static func describe(item: ItemData) -> Array[String]:
	var lines: Array[String] = []
	if item.kind == ItemData.Kind.CONSUMABLE:
		lines.append("+%d HP (Q или ПКМ)" % int(item.heal))
		return lines
	lines.append("+ " + item.plus)
	lines.append("− " + item.minus)
	lines.append("Тег: %s%s" % [tag_name(item.tag), ", редкий" if item.rarity == &"rare" else ""])
	return lines


static func tag_name(tag: int) -> String:
	return ANOMALY_NAMES.get(tag, "универсальный")


static func data(id: StringName) -> Dictionary:
	for d in ARTIFACTS:
		if d["id"] == id:
			return d
	return {}


static func _build(d: Dictionary, kind: ItemData.Kind) -> ItemData:
	var it := ItemData.new()
	it.id = d["id"]
	it.display_name = d["name"]
	it.description = d["desc"]
	it.kind = kind
	it.color = d["color"]
	it.shape = d["shape"]
	it.heal = d.get("heal", 0.0)
	it.aura = d.get("aura", {})
	it.plus = d.get("plus", "")
	it.minus = d.get("minus", "")
	it.tag = d.get("tag", -1)
	it.rarity = d.get("rarity", &"common")
	it.damage_mult = d.get("damage_mult", {})
	it.buff_mult = d.get("buff_mult", {})
	it.buff_duration_mult = d.get("buff_duration_mult", {})
	it.heal_mult = d.get("heal_mult", 1.0)
	it.run_mult = d.get("run_mult", 1.0)
	it.jump_mult = d.get("jump_mult", 1.0)
	it.gravity_mult = d.get("gravity_mult", 1.0)
	it.max_hp_add = d.get("max_hp_add", 0.0)
	it.dash_charges_max = d.get("dash_charges_max", 0)
	it.flags = d.get("flags", {})
	return it


static func _num(v: float) -> String:
	return ("%.2f" % v).rstrip("0").rstrip(".")
