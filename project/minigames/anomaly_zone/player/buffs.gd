class_name Buffs
extends RefCounted
## Активные баффы игрока с таймерами. Повторный бафф того же типа обновляет длительность,
## но не усиливает; разные баффы действуют одновременно. Числа баффов — в AnomalyDb.

signal buff_added(id: StringName)
signal buff_expired(id: StringName)
## Любое изменение набора или силы (для пересчёта движения и HUD).
signal changed

## id -> {"strength": float, "time": float, "total": float}
var active: Dictionary = {}


func add(id: StringName, strength: float, duration: float) -> void:
	if active.has(id):
		var b: Dictionary = active[id]
		b["time"] = maxf(b["time"], duration)
		b["total"] = maxf(duration, b["time"])
		return
	active[id] = {"strength": strength, "time": duration, "total": duration}
	buff_added.emit(id)
	changed.emit()


## Продлить все активные баффы (Бенгальский огонь).
func extend_all(seconds: float) -> void:
	for b in active.values():
		b["time"] += seconds
		b["total"] = maxf(b["total"], b["time"])


func tick(delta: float) -> void:
	var gone: Array[StringName] = []
	for id in active:
		active[id]["time"] -= delta
		if active[id]["time"] <= 0.0:
			gone.append(id)
	for id in gone:
		active.erase(id)
		buff_expired.emit(id)
	if not gone.is_empty():
		changed.emit()


func has(id: StringName) -> bool:
	return active.has(id)


func strength(id: StringName, default: float = 1.0) -> float:
	return active[id]["strength"] if active.has(id) else default


func time_left(id: StringName) -> float:
	return active[id]["time"] if active.has(id) else 0.0


## Доля оставшегося времени 0..1 (для кругового таймера в HUD).
func fraction(id: StringName) -> float:
	if not active.has(id):
		return 0.0
	return clampf(active[id]["time"] / maxf(0.001, active[id]["total"]), 0.0, 1.0)


func clear() -> void:
	var ids := active.keys()
	active.clear()
	for id in ids:
		buff_expired.emit(id)
	changed.emit()
