class_name DebugOverlay
extends Node2D
## Отладочный оверлей (F1): у каждой аномалии — интенсивность, модификаторы, состояние и зона;
## у игрока — артефакты, состояние и прыжок. Живёт в мировых координатах (родитель — World).

const STATE_NAMES := ["idle", "telegraph", "active", "cooldown"]

var player: Player
## Корень «Зоны» (для отрыва от волны).
var zone: Node


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
		_text(font, p + Vector2(0.0, 15.0), "[%s]%s" % [STATE_NAMES[a.state], "  аура" if not a.aura.is_empty() else ""])
		var extra := a.debug_extra()
		if extra != "":
			_text(font, p + Vector2(0.0, 30.0), extra)
	for f in get_tree().get_nodes_in_group(&"anomaly_fields"):
		draw_rect((f as AnomalyField).zone_rect(), Color(0.6, 0.8, 1.0, 0.25), false, 1.0)
	var pc := player.global_position
	var arts: Array[String] = []
	for it in player.stats.artifacts:
		arts.append(it.display_name)
	var jp := player.predicted_jump()
	var lines: Array[String] = [
		"Артефакты: " + (", ".join(arts) if not arts.is_empty() else "нет"),
		"прыжок ×%.2f  грав ×%.2f  заряды %d/%d" % [player.jump_multiplier, player.gravity_multiplier, player.charge, player.max_charge],
		"%s%s  vx %d  vy %d" % [player.state_name(), "  ОГЛУШЁН" if player.is_stunned() else "", int(player.velocity.x), int(player.velocity.y)],
		"койот %.2f  буфер %.2f" % [maxf(0.0, player._coyote), maxf(0.0, player._buffer)],
		"расчёт прыжка: высота %d, дальность %d px" % [int(jp.x), int(jp.y)],
		"зум %.2f" % player.camera_zoom(),
		"последнее падение %d px (без урона до %d)" % [int(player.last_fall), int(player.m.safe_fall_height)],
		"бег %d  макс. HP %d  баффы: %s" % [int(player.m.run_speed), int(player.max_hp), _buffs_text()],
		"баффов по типам: %s" % _counts_text(),
		"отрыв от волны %.1f с" % zone.wave.gap_seconds() if zone and zone.wave.is_running() else "волна стоит",
	]
	for i in lines.size():
		_text(font, pc + Vector2(-70.0, -198.0 + i * 15.0), lines[i])
	for i in player.state_log.size():
		_text(font, pc + Vector2(250.0, -198.0 + i * 15.0), player.state_log[i])


func _buffs_text() -> String:
	var parts: Array[String] = []
	for id in player.buffs.active:
		parts.append("%s ×%.2f %.1f с" % [AnomalyDb.BUFFS[id]["name"], player.buffs.strength(id), player.buffs.time_left(id)])
	return ", ".join(parts) if not parts.is_empty() else "нет"


func _counts_text() -> String:
	var parts: Array[String] = []
	for t in player.stats.buff_counts:
		parts.append("%s %d" % [ArtifactDb.ANOMALY_NAMES[t], player.stats.buff_counts[t]])
	return ", ".join(parts) if not parts.is_empty() else "нет"


func _text(font: Font, pos: Vector2, text: String) -> void:
	draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.8))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 0.8, 0.95))
