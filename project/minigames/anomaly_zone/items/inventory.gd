class_name Inventory
extends RefCounted
## Рюкзак (4×3) для расходников и список взятых артефактов. Без UI: об изменениях сообщает сигналами.
## Пояса и слотов для артефактов нет: все взятые артефакты действуют сразу, выбросить их нельзя.

signal changed
signal item_added(item: ItemData)

const BACKPACK_COLS := 4
const BACKPACK_ROWS := 3

var backpack: Array[ItemData] = []
var artifacts: Array[ItemData] = []


func setup() -> void:
	backpack.clear()
	backpack.resize(BACKPACK_COLS * BACKPACK_ROWS)
	artifacts.clear()
	changed.emit()


func get_item(idx: int) -> ItemData:
	return backpack[idx] if idx >= 0 and idx < backpack.size() else null


## Артефакт — в список (без ограничения), расходник — в свободную клетку рюкзака.
func add_item(item: ItemData) -> bool:
	if item.kind == ItemData.Kind.ARTIFACT:
		artifacts.append(item)
	else:
		var i := backpack.find(null)
		if i < 0:
			return false
		backpack[i] = item
	item_added.emit(item)
	changed.emit()
	return true


## Обмен содержимого двух клеток рюкзака (пустая клетка — просто перенос).
func swap(a: int, b: int) -> void:
	var t := backpack[a]
	backpack[a] = backpack[b]
	backpack[b] = t
	changed.emit()


## Убирает расходник из клетки и возвращает его (применяет вызывающий).
func consume(idx: int) -> ItemData:
	var item := get_item(idx)
	if item == null or item.kind != ItemData.Kind.CONSUMABLE:
		return null
	backpack[idx] = null
	changed.emit()
	return item


## Клетка расходника, лучше всего подходящего под недостающее здоровье; -1, если нет.
func best_heal_slot(missing: float) -> int:
	var best := -1
	var best_diff := INF
	for i in backpack.size():
		var it := backpack[i]
		if it == null or it.kind != ItemData.Kind.CONSUMABLE:
			continue
		var diff := absf(it.heal - missing)
		if diff < best_diff:
			best_diff = diff
			best = i
	return best


func has_id(id: StringName) -> bool:
	for it in artifacts:
		if it.id == id:
			return true
	for it in backpack:
		if it != null and it.id == id:
			return true
	return false


func count_consumables() -> int:
	var n := 0
	for it in backpack:
		if it != null and it.kind == ItemData.Kind.CONSUMABLE:
			n += 1
	return n
