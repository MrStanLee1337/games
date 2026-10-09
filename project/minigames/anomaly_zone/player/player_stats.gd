class_name PlayerStats
extends RefCounted
## Статы забега: взятые артефакты и их суммарные эффекты, счётчик баффов по типам аномалий
## (для карты «под билд» в тайниках). HP и заряды хранит игрок, их пределы считаются здесь.
## Множители нескольких артефактов перемножаются, фиксированные величины (макс. HP) складываются.
## Уникальные правила артефактов — флаги (flags) с обработкой у игрока: Колючка (hp_speed),
## Бенгальский огонь (bengal), Батарейка (no_stun).

signal changed

const BASE_MAX_HP := 100.0
const BASE_CHARGES := 2

var artifacts: Array[ItemData] = []
## Anomaly.Type -> сколько баффов получено от аномалий этого типа за забег.
var buff_counts: Dictionary = {}


func reset() -> void:
	artifacts.clear()
	buff_counts.clear()
	changed.emit()


func add_artifact(it: ItemData) -> void:
	artifacts.append(it)
	changed.emit()


func has_artifact(id: StringName) -> bool:
	for it in artifacts:
		if it.id == id:
			return true
	return false


func artifact_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for it in artifacts:
		out.append(it.id)
	return out


func count_buff(type: Anomaly.Type) -> void:
	buff_counts[type] = int(buff_counts.get(type, 0)) + 1


## Тип аномалий, от которых получено больше всего баффов; -1, если баффов ещё не было.
func favorite_type() -> int:
	var best := -1
	var best_n := 0
	for t in buff_counts:
		if buff_counts[t] > best_n:
			best_n = buff_counts[t]
			best = t
	return best


func max_hp() -> float:
	var v := BASE_MAX_HP
	for it in artifacts:
		v += it.max_hp_add
	return maxf(1.0, v)


func max_charges() -> int:
	var v := BASE_CHARGES
	for it in artifacts:
		v = maxi(v, it.dash_charges_max)
	return v


func run_mult() -> float:
	return _product(&"run_mult")


func jump_mult() -> float:
	return _product(&"jump_mult")


func gravity_mult() -> float:
	return _product(&"gravity_mult")


## Множитель лечения Холодца.
func heal_mult() -> float:
	return _product(&"heal_mult")


func damage_mult(type: Anomaly.Type) -> float:
	return _product_by_type(&"damage_mult", type)


## Сила баффа аномалии (что именно усиливается — см. AnomalyDb).
func buff_mult(type: Anomaly.Type) -> float:
	return _product_by_type(&"buff_mult", type)


func buff_duration_mult(type: Anomaly.Type) -> float:
	return _product_by_type(&"buff_duration_mult", type)


## Значение флага уникального правила (первый артефакт с этим флагом) или default.
func flag(name: StringName, default: Variant = null) -> Variant:
	for it in artifacts:
		if it.flags.has(name):
			return it.flags[name]
	return default


func _product(field: StringName) -> float:
	var v := 1.0
	for it in artifacts:
		v *= float(it.get(field))
	return v


func _product_by_type(field: StringName, type: Anomaly.Type) -> float:
	var v := 1.0
	for it in artifacts:
		var d: Dictionary = it.get(field)
		v *= float(d.get(type, 1.0))
	return v
