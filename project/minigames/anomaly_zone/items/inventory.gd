class_name Inventory
extends RefCounted
## Логика рюкзака (4×3) и пояса артефактов. Без UI: об изменениях сообщает сигналами.

signal changed
signal item_added(item: ItemData, in_belt: bool)

enum Zone { BACKPACK, BELT }

const BACKPACK_COLS := 4
const BACKPACK_ROWS := 3

var backpack: Array[ItemData] = []
var belt: Array[ItemData] = []


func setup(belt_slots: int) -> void:
	backpack.clear()
	backpack.resize(BACKPACK_COLS * BACKPACK_ROWS)
	belt.clear()
	belt.resize(belt_slots)
	changed.emit()


func slots(zone: Zone) -> Array[ItemData]:
	return belt if zone == Zone.BELT else backpack


func get_item(zone: Zone, idx: int) -> ItemData:
	var s := slots(zone)
	return s[idx] if idx >= 0 and idx < s.size() else null


## Артефакт идёт в свободный слот пояса, иначе в рюкзак. Расходники — в рюкзак.
func add_item(item: ItemData) -> bool:
	if item.kind == ItemData.Kind.ARTIFACT:
		var b := belt.find(null)
		if b >= 0:
			belt[b] = item
			item_added.emit(item, true)
			changed.emit()
			return true
	var i := backpack.find(null)
	if i < 0:
		return false
	backpack[i] = item
	item_added.emit(item, false)
	changed.emit()
	return true


## На пояс можно класть только артефакты.
func can_place(zone: Zone, item: ItemData) -> bool:
	return zone != Zone.BELT or item == null or item.kind == ItemData.Kind.ARTIFACT


## Обмен содержимого двух слотов (пустой слот — просто перенос).
func swap(za: Zone, ia: int, zb: Zone, ib: int) -> bool:
	var a := get_item(za, ia)
	var b := get_item(zb, ib)
	if not can_place(zb, a) or not can_place(za, b):
		return false
	slots(za)[ia] = b
	slots(zb)[ib] = a
	changed.emit()
	return true


## ПКМ по артефакту: между рюкзаком и поясом.
func quick_move(zone: Zone, idx: int) -> bool:
	var item := get_item(zone, idx)
	if item == null or item.kind != ItemData.Kind.ARTIFACT:
		return false
	var target := Zone.BACKPACK if zone == Zone.BELT else Zone.BELT
	var free := slots(target).find(null)
	if free < 0:
		return false
	return swap(zone, idx, target, free)


## Убирает расходник из слота и возвращает его (применяет вызывающий).
func consume(zone: Zone, idx: int) -> ItemData:
	var item := get_item(zone, idx)
	if item == null or item.kind != ItemData.Kind.CONSUMABLE:
		return null
	slots(zone)[idx] = null
	changed.emit()
	return item


## Слот расходника, лучше всего подходящий под недостающее здоровье; (-1, -1), если нет.
func best_heal_slot(missing: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_diff := INF
	for i in backpack.size():
		var it := backpack[i]
		if it == null or it.kind != ItemData.Kind.CONSUMABLE:
			continue
		var diff := absf(it.heal - missing)
		if diff < best_diff:
			best_diff = diff
			best = Vector2i(Zone.BACKPACK, i)
	return best


func has_id(id: StringName) -> bool:
	for it in belt:
		if it != null and it.id == id:
			return true
	for it in backpack:
		if it != null and it.id == id:
			return true
	return false


func belt_artifacts() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for it in belt:
		if it != null:
			out.append(it)
	return out


func count_consumables() -> int:
	var n := 0
	for it in backpack:
		if it != null and it.kind == ItemData.Kind.CONSUMABLE:
			n += 1
	return n
