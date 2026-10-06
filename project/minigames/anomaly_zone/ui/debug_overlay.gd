class_name DebugOverlay
extends Node2D
## Отладочный оверлей (F1): у каждой аномалии — интенсивность, модификаторы, состояние и зона;
## у игрока — радиус ауры и пояс. Живёт в мировых координатах (родитель — World).

const STATE_NAMES := ["idle", "telegraph", "active", "cooldown"]

var player: Player


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var font := ThemeDB.fallback_font
	for node in get_tree().get_nodes_in_group(&"anomalies"):
		var a := node as Anomaly
		var col := Color(1.0, 0.95, 0.3, 0.8) if not a.is_asleep() else Color(1, 1, 1, 0.35)
		var sn := a.get_shape_node()
		if sn and sn.shape is CircleShape2D:
			draw_arc(sn.global_position, (sn.shape as CircleShape2D).radius, 0.0, TAU, 48, col, 1.5)
		elif sn and sn.shape is RectangleShape2D:
			var sz := (sn.shape as RectangleShape2D).size
			draw_rect(Rect2(sn.global_position - sz * 0.5, sz), col, false, 1.5)
		var p := a.top_point() + Vector2(-70.0, -46.0)
		var title := String(ArtifactDb.ANOMALY_NAMES[a.anomaly_type])
		_text(font, p, "%s  I=%.2f (база %.2f)" % [title, a.current_intensity, a.base_intensity])
		_text(font, p + Vector2(0.0, 15.0), "мод ×%.2f%s  урон ×%.2f  [%s]" % [
			a.mod_mult, " инв" if a.inverted else "", a.damage_mult, STATE_NAMES[a.state]])
	var pc := player.global_position
	draw_arc(pc, player.aura_radius, 0.0, TAU, 72, Color(1, 1, 1, 0.3), 1.0)
	var belt: Array[String] = []
	for it in player.inventory.belt_artifacts():
		belt.append(it.display_name)
	_text(font, pc + Vector2(-70.0, -78.0), "Пояс: " + (", ".join(belt) if not belt.is_empty() else "пусто"))
	_text(font, pc + Vector2(-70.0, -63.0), "прыжок ×%.2f  грав ×%.2f  рег %.1f/с" % [player.jump_multiplier, player.gravity_multiplier, player.regen_per_sec])


func _text(font: Font, pos: Vector2, text: String) -> void:
	draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.8))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 0.8, 0.95))
