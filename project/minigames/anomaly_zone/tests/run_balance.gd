extends SceneTree
## Баланс участков забега по ТЗ. Запуск (быстрее реального времени):
##   godot --headless --fixed-fps 60 --path project --script res://minigames/anomaly_zone/tests/run_balance.gd
## Для каждого участка:
##   1) безопасная дорога без артефактов и с выключенной волной → T_safe, скорость волны
##      v = (xБ − xА + 480) / (1.1 · T_safe), отрыв на всём пути (≥ 1 с) и на финише (8–12%);
##   2) тот же прогон с включённой волной на этой скорости — игрок доходит до Б;
##   3) скоростная дорога без артефактов — на 15–25% быстрее, стоит 25–50 HP;
##   4) безопасная дорога с крюком к редкому тайнику — 3–6 с отрыва.
## Аргумент SECTIONS (через переменную окружения) — список участков через запятую (по умолчанию все).

const Bot := preload("res://minigames/anomaly_zone/tests/run_bot.gd")
const SECTIONS := [&"s1", &"s2a", &"s2b", &"s3"]
const LIMIT := 120.0

var z: Node
var bot = Bot.new()


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	var only := OS.get_environment("SECTIONS")
	var z_scene: PackedScene = load("res://minigames/anomaly_zone/zone.tscn")
	z = z_scene.instantiate()
	z.run_seed = 1
	root.add_child(z)
	await frames(3)
	for sid in SECTIONS:
		if only != "" and not (String(sid) in only.split(",")):
			continue
		await _check(sid)
	quit()


## Загрузить участок sid с начала забега (без артефактов, полное HP).
func _load(sid: StringName) -> void:
	bot.release_all()
	z.run.new_run(1)
	match sid:
		&"s1":
			z.run.index = 0
		&"s2a":
			z.run.index = 1
			z.run.branch = RunManager.BRANCH_A
		&"s2b":
			z.run.index = 1
			z.run.branch = RunManager.BRANCH_B
		_:
			z.run.index = 2
	z._restarting = false
	z._finished = false
	z._time = 0.0
	z._load_section(true)
	await frames(2)


## Прогон ботом. Возвращает {t, hp, ok, xs: [[t, x], ...]}; волна включена, если wave_on.
func _run(sid: StringName, mode: StringName, detour: bool, wave_on: bool, v: float = 0.0) -> Dictionary:
	await _load(sid)
	if wave_on:
		z.level.wave_speed = v
		z.wave.start(z.level.start_pos.x, v, z.level.bounds)
	z.wave.enabled = wave_on
	bot.setup(z, mode, detour)
	var t0: float = z._time
	var xs: Array = []
	var start_attempt: int = z.attempt
	var hp_lost := 0.0
	var last_hp: float = z.player.hp
	while not z._in_shelter and z._time - t0 < LIMIT:
		if z.attempt != start_attempt:
			break
		bot.tick()
		await physics_frame
		var hp: float = z.player.hp
		if hp < last_hp:
			hp_lost += last_hp - hp
		last_hp = hp
		xs.append([z._time - t0, z.player.global_position.x])
	bot.release_all()
	var ok: bool = z._in_shelter and z.attempt == start_attempt
	return {"t": z._time - t0, "hp": hp_lost, "ok": ok, "xs": xs}


func _check(sid: StringName) -> void:
	var safe := await _run(sid, &"safe", false, false)
	var xa: float = z.level.start_pos.x
	var xb: float = z.level.finish_x()
	var T: float = safe["t"]
	var v := (xb - xa + BlowoutWave.START_BEHIND) / (1.1 * T)
	var min_gap := INF
	var min_at := 0.0
	for s in safe["xs"]:
		var g: float = (float(s[1]) - 12.0 - (xa - BlowoutWave.START_BEHIND + v * float(s[0]))) / v
		if g < min_gap:
			min_gap = g
			min_at = s[1]
	var fin_gap := 1.1 * T - T
	print("== %s «%s»: длина %d px" % [sid, z.level.title, int(xb - xa)])
	print("  безопасная: %s, T_safe %.1f с, урон %d → волна v = %.1f px/с; отрыв мин %.2f с (x=%d), на финише %.1f с = %d%%" % [
		"дошёл" if safe["ok"] else "НЕ ДОШЁЛ", T, int(safe["hp"]), v, min_gap, int(min_at), fin_gap, int(round(fin_gap / T * 100.0))])
	var real := await _run(sid, &"safe", false, true, v)
	print("  с волной %.1f px/с: %s за %.1f с" % [v, "дошёл" if real["ok"] else "ДОГНАЛА", real["t"]])
	var fast := await _run(sid, &"fast", false, false)
	print("  скоростная: %s, %.1f с — быстрее на %d%%, урон %d HP" % ["дошёл" if fast["ok"] else "НЕ ДОШЁЛ", fast["t"],
		int(round((T - fast["t"]) / T * 100.0)), int(fast["hp"])])
	var det := await _run(sid, &"safe", true, false)
	print("  крюк к редкому тайнику: %s, %.1f с — +%.1f с, артефактов %d" % ["дошёл" if det["ok"] else "НЕ ДОШЁЛ", det["t"],
		det["t"] - T, z.player.stats.artifacts.size()])
	z.level.wave_speed = v
