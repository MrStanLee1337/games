class_name ArtifactDb
extends RefCounted
## Таблица всех предметов. Баланс правится здесь — остальной код не трогаем.
##
## Артефакт: id, name, desc, color, shape, aura. Новая таблица артефактов забега (плюс, минус,
## тег, редкость, множители) — этап 5 ТЗ «Зона: забег»; пока артефактов нет.
## Расходник: id, name, desc, color, shape, heal.

const ANOMALY_NAMES := {
	Anomaly.Type.ZHARKA: "Жарка",
	Anomaly.Type.ELECTRA: "Электра",
	Anomaly.Type.TRAMPLIN: "Трамплин",
	Anomaly.Type.VORONKA: "Воронка",
	Anomaly.Type.KHOLODETS: "Холодец",
}

const ARTIFACTS: Array[Dictionary] = []

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
	return it


static func _num(v: float) -> String:
	return ("%.2f" % v).rstrip("0").rstrip(".")
