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
		_text(font, p + Vector2(0.0, 15.0), "мод ×%.2f%s  урон ×%.2f  [%s]%s" % [
			a.mod_mult, " инв" if a.inverted else "", a.damage_mult, STATE_NAMES[a.state],
			"  форма: " + String(a.form) if a.form != &"" else ""])
		var extra := a.debug_extra()
		if extra != "":
			_text(font, p + Vector2(0.0, 30.0), extra)
	for f in get_tree().get_nodes_in_group(&"anomaly_fields"):
		draw_rect((f as AnomalyField).zone_rect(), Color(0.6, 0.8, 1.0, 0.25), false, 1.0)
	# Круг шума: последний сигнал, гаснет за 0.6 с.
	var age := (Time.get_ticks_msec() - player.last_noise_msec) / 1000.0
	if age < 0.6:
		draw_arc(player.last_noise_pos, player.last_noise_radius, 0.0, TAU, 64, Color(1.0, 0.5, 0.3, 0.7 * (1.0 - age / 0.6)), 2.0)
	var pc := player.global_position
	draw_arc(pc, player.aura_radius, 0.0, TAU, 72, Color(1, 1, 1, 0.3), 1.0)
	var belt: Array[String] = []
	for it in player.inventory.belt_artifacts():
		belt.append(it.display_name)
	var jp := player.predicted_jump()
	var lines: Array[String] = [
		"Пояс: " + (", ".join(belt) if not belt.is_empty() else "пусто"),
		"прыжок ×%.2f  грав ×%.2f  рег %.1f/с" % [player.jump_multiplier, player.gravity_multiplier, player.regen_per_sec],
		"%s%s  vx %d  vy %d" % [player.state_name(), "  ОГЛУШЁН" if player.is_stunned() else "", int(player.velocity.x), int(player.velocity.y)],
		"койот %.2f  буфер %.2f" % [maxf(0.0, player._coyote), maxf(0.0, player._buffer)],
		"расчёт прыжка: высота %d, дальность %d px" % [int(jp.x), int(jp.y)],
		"груз %.1f кг (эфф. %.1f) — %s" % [player.load_kg, player.effective_load, MovementConfig.TIER_NAMES[player.m.tier]],
		"шум %d px  зум %.2f%s%s" % [int(player.last_noise_radius), player.camera_zoom(),
			"  детектор" if player.detector_out else "", "  тихо (Ctrl)" if Input.is_action_pressed(&"az_walk") else ""],
		"последнее падение %d px (без урона до %d)" % [int(player.last_fall), int(player.m.safe_fall_height)],
	]
	for i in lines.size():
		_text(font, pc + Vector2(-70.0, -168.0 + i * 15.0), lines[i])
	for i in player.state_log.size():
		_text(font, pc + Vector2(250.0, -168.0 + i * 15.0), player.state_log[i])


func _text(font: Font, pos: Vector2, text: String) -> void:
	draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.8))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 0.8, 0.95))
