extends SceneTree
## Весь забег ботом с настоящей волной (скорости из сцен участков): участок 1 → развилка → 2а/2б →
## участок 3 → финиш. Запуск:
##   godot --headless --fixed-fps 60 --path project --script res://minigames/anomaly_zone/tests/run_full.gd
## Переменные окружения: BRANCH=a|b (дверь развилки), MODE=safe|fast (дорога).

const Bot := preload("res://minigames/anomaly_zone/tests/run_bot.gd")


func _init() -> void:
	var z = load("res://minigames/anomaly_zone/zone.tscn").instantiate()
	z.run_seed = 3
	root.add_child(z)
	for i in 3:
		await physics_frame
	var bot = Bot.new()
	var mode := StringName(OS.get_environment("MODE")) if OS.get_environment("MODE") != "" else &"safe"
	bot.setup(z, mode)
	bot.branch = RunManager.BRANCH_B if OS.get_environment("BRANCH") == "b" else RunManager.BRANCH_A
	var section := -1
	var log: Array[String] = []
	var t := 0
	while not z._finished and t < 60 * 260:
		if z.run.index != section or (z.level as RunSection) == null:
			section = z.run.index
			bot.setup(z, mode)
			bot.branch = RunManager.BRANCH_B if OS.get_environment("BRANCH") == "b" else RunManager.BRANCH_A
			log.append("%.1f с: %s (волна %.1f px/с), HP %d" % [z._time, z.level.title, z.level.wave_speed, int(z.player.hp)])
		if z.attempt != 1:
			log.append("%.1f с: ЗАБЕГ ПРОВАЛЕН (%s)" % [z._time, z.level.title])
			break
		bot.tick()
		await physics_frame
		t += 1
	for l in log:
		print("  ", l)
	print("итог (%s, ветка %s): %s за %.1f с, HP %d, отрыв на финише %.1f с" % [mode, bot.branch,
		"ФИНИШ" if z._finished else "не дошёл", z._time, int(z.player.hp), z.wave.gap_seconds() if z._finished else 0.0])
	quit()
