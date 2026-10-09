class_name AuraSystem
extends Node2D
## Общая система аур. ~14 раз в секунду собирает источники (группа aura_sources) и каждой аномалии,
## до которой достаёт хотя бы одна аура, передаёт словарь её эффектов (Anomaly.set_aura).
## Аномалия вне всех аур получает пустой словарь. Что значат поля ауры, решает сама аномалия.
##
## Источник ауры — любой узел в группе aura_sources с методами:
##   aura_origin() -> Vector2, aura_items() -> Array[ItemData], aura_radius() -> float
## Аура предмета — ItemData.aura: {type: Anomaly.Type, radius, ...эффекты}.

@export var rate_hz := 14.0

var _acc := 0.0


func _ready() -> void:
	add_to_group(&"aura_system")


func _physics_process(delta: float) -> void:
	_acc += delta
	if _acc >= 1.0 / rate_hz:
		_acc = 0.0
		refresh()


## Немедленный пересчёт (например, после нового артефакта).
func refresh() -> void:
	var sources := get_tree().get_nodes_in_group(&"aura_sources")
	for node in get_tree().get_nodes_in_group(&"anomalies"):
		var a := node as Anomaly
		if a == null:
			continue
		var merged := {}
		for s in sources:
			var items: Array[ItemData] = s.call(&"aura_items")
			if items.is_empty():
				continue
			var origin: Vector2 = s.call(&"aura_origin")
			var r: float = s.call(&"aura_radius")
			if a.edge_distance(origin) > r:
				continue
			for it in items:
				if it.aura.get("type", -1) == a.anomaly_type:
					merged.merge(it.aura, true)
		a.set_aura(merged)
