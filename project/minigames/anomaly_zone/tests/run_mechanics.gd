extends SceneTree
## Механики забега по таблице проверки ТЗ (ровный пол песочницы). Запуск:
##   godot --headless --fixed-fps 60 --path project --script res://minigames/anomaly_zone/tests/run_mechanics.gd
## Баланс участков — tests/run_balance.gd.

var z: Node
var p: Player
var lvl: Node
var nodes: Array[Node] = []
var fails := 0


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func rel() -> void:
	for a in ["az_right", "az_left", "az_jump", "az_up", "az_down", "az_dash", "az_interact"]:
		Input.action_release(a)


func put(a: Node2D, pos: Vector2) -> Node2D:
	a.position = pos
	lvl.add_child(a)
	nodes.append(a)
	return a


func clear() -> void:
	for n in nodes:
		n.queue_free()
	nodes.clear()
	await frames(3)


## Игрок в x без вещей и с артефактами arts; аномалии ставить ПОСЛЕ place (иначе сработают на старом месте).
func place(x: float, arts: Array = [], hp: float = -1.0) -> void:
	rel()
	p.reset_run(Vector2(x, 576))
	await frames(3)
	for id in arts:
		p.stats.add_artifact(ArtifactDb.make(id))
	await frames(2)
	if hp > 0.0:
		p.hp = hp
	p._invuln = 0.0
	await frames(10)


func speed(n: int) -> float:
	var x0 := p.global_position.x
	await frames(n)
	return (p.global_position.x - x0) * 60.0 / n


func row(name: String, ok: bool, got: String, want: String) -> void:
	if not ok:
		fails += 1
	print(("OK   " if ok else "FAIL "), name, ": ", got, "   (ТЗ ", want, ")")


func near(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _init() -> void:
	z = load("res://minigames/anomaly_zone/sandbox.tscn").instantiate()
	root.add_child(z)
	await frames(3)
	p = z.player
	lvl = z.level
	z.wave.enabled = false
	for g in ["anomalies", "pickups"]:
		for n in get_nodes_in_group(g):
			n.queue_free()
	await frames(3)
	var F := ZoneLevel.FLOOR_Y

	# Форсаж / с Пламенем
	for arts in [[], [&"plamya"]]:
		await place(1000, arts)
		var zh := Zharka.new()
		zh.size = Vector2(200, 160)
		put(zh, Vector2(1300, F))
		Input.action_press("az_right")
		var t := 0
		while not p.buffs.has(&"forsazh") and t < 120:
			await physics_frame
			t += 1
		var dur := p.buffs.time_left(&"forsazh")
		await frames(20)
		var s := await speed(30)
		rel()
		await clear()
		var want := 476.0 if not arts.is_empty() else 378.0
		row("Форсаж" + (" с Пламенем" if not arts.is_empty() else ""), near(s, want, 5.0) and near(dur, 3.0, 0.05),
			"бег %d px/с, %.1f с" % [int(round(s)), dur], "%d ± 5, 3 с" % int(want))

	# Подброс Трамплина / с Пружиной / с Грави
	var launches: Array[float] = []
	for arts in [[], [&"pruzhina"], [&"gravi"]]:
		await place(1180, arts)
		put(Trampolin.new(), Vector2(1300, F - 20))
		Input.action_press("az_right")
		await frames(16)
		rel()
		var y0 := 0.0
		var top := 9999.0
		var launched := false
		for i in 120:
			var yp := p.global_position.y
			await physics_frame
			if not launched and p.velocity.y < -400.0:
				launched = true
				y0 = yp
			if launched:
				top = minf(top, p.global_position.y)
			if launched and p.velocity.y > 0.0:
				break
		launches.append(y0 - top)
		await clear()
	row("Подброс Трамплина / с Пружиной / с Грави", near(launches[0], 190, 8) and near(launches[1], 266, 8) and near(launches[2], 133, 8),
		"%d / %d / %d px" % [int(launches[0]), int(launches[1]), int(launches[2])], "190 / 266 / 133 ± 8")

	# Лёгкость: прыжок 140 ± 5 в течение 3 с
	await place(1000)
	p.buffs.add(&"legkost", AnomalyDb.DATA[Anomaly.Type.TRAMPLIN]["strength"], 3.0)
	await frames(2)
	var jy := p.global_position.y
	var jtop := jy
	Input.action_press("az_jump")
	for i in 70:
		await physics_frame
		jtop = minf(jtop, p.global_position.y)
	rel()
	await frames(150)
	row("Лёгкость", near(jy - jtop, 140, 5) and not p.buffs.has(&"legkost"), "прыжок %d px, через 3 с бафф снят" % int(jy - jtop),
		"140 ± 5 в течение 3 с")

	# Электра: 15 урона, +1 заряд; третья без Батарейки — всё ещё 2
	await place(1000)
	for x in [1300.0, 1500.0, 1700.0]:
		put(Electra.new(), Vector2(x, F - 40))
	var hits: Array[String] = []
	var last := p.hp
	Input.action_press("az_right")
	for i in 220:
		await physics_frame
		if p.hp < last - 0.1:
			hits.append("−%d→%d" % [int(round(last - p.hp)), p.charge])
			last = p.hp
	rel()
	await clear()
	row("Электра", hits == ["−15→1", "−15→2", "−15→2"], ", ".join(hits), "15 урона, +1 заряд; третья — всё ещё 2")

	# Праща Воронки, с Грави
	var sling: Array[float] = []
	for arts in [[], [&"gravi"]]:
		await place(1000, arts)
		var v := Voronka.new()
		v.radius = 360.0
		v.pull = 6000.0
		put(v, Vector2(1600, 520))
		Input.action_press("az_right")
		var best := 0.0
		for i in 240:
			await physics_frame
			if p.buffs.has(&"prashcha"):
				best = maxf(best, absf(p.velocity.x))
		rel()
		await clear()
		sling.append(best)
	row("Праща Воронки", near(sling[0], 560, 2) and near(sling[1], 728, 2), "до %d / с Грави до %d px/с" % [int(sling[0]), int(sling[1])],
		"до 560, с Грави до 728")

	# Холодец 5 с / с Медузой
	var heal: Array[float] = []
	var runs: Array[float] = []
	for arts in [[], [&"meduza"]]:
		await place(1100, arts, 20.0)
		var k := Kholodets.new()
		k.size = Vector2(900, 18)
		put(k, Vector2(1500, F))
		await frames(2)
		var h0 := p.hp
		await frames(300)
		heal.append(p.hp - h0)
		Input.action_press("az_right")
		await frames(20)
		runs.append(await speed(30))
		rel()
		await clear()
	row("Холодец 5 с / с Медузой", near(heal[0], 30, 1) and near(heal[1], 60, 1) and near(runs[0], 168, 2) and near(runs[1], 252, 2),
		"+%d / +%d HP, бег %d / %d px/с" % [int(round(heal[0])), int(round(heal[1])), int(runs[0]), int(runs[1])], "+30 / +60 HP, бег 168 / 252")

	# Цепочка: Жарка, за 0.5 с Трамплин
	await place(1000)
	var zz := Zharka.new()
	zz.size = Vector2(200, 160)
	put(zz, Vector2(1300, F))
	put(Trampolin.new(), Vector2(1420, F - 20))
	Input.action_press("az_right")
	await frames(160)
	rel()
	await clear()
	row("Цепочка: Жарка, за 0.5 с Трамплин", near(100.0 - p.hp, 12, 0.1) and p.stats.buff_counts.size() == 2,
		"урон %d, баффов от %d типов" % [int(100.0 - p.hp), p.stats.buff_counts.size()], "12 урона и два баффа")

	# Повтор той же аномалии раньше 1 с
	await place(1300)
	var zr := Zharka.new()
	zr.size = Vector2(200, 160)
	zr.active_time = 3.0
	put(zr, Vector2(1300, F))
	var counts: Array = []
	for i in 6:
		await frames(20)
		counts.append(p.stats.buff_counts.get(Anomaly.Type.ZHARKA, 0))
	await clear()
	row("Повтор той же аномалии раньше 1 с", counts.slice(1, 5) == [1, 1, 1, 1] and counts[5] == 2,
		"стоим в горящей Жарке, баффов каждые 0.33 с: %s" % str(counts),
		"бафф не начисляется")

	# Тайник, 100 генераций
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var all := ArtifactDb.artifact_ids()
	var bad := 0
	var need := 0
	var got := 0
	for g in 100:
		var owned: Array[StringName] = []
		for id in all:
			if rng.randf() < 0.3:
				owned.append(id)
		var fav := rng.randi_range(-1, 4)
		var cards := Cache.generate_cards(g % 2 == 1, owned, fav, rng)
		for id in cards:
			if id in owned:
				bad += 1
		var fits := func(id: StringName) -> bool: return ArtifactDb.data(id)["tag"] == fav or ArtifactDb.data(id)["tag"] == -1
		var avail: Array[StringName] = []
		for id in all:
			if id not in owned and (g % 2 == 1 or ArtifactDb.data(id)["rarity"] == &"common"):
				avail.append(id)
		if fav >= 0 and avail.any(fits):
			need += 1
			if cards.any(fits):
				got += 1
	row("Тайник, 100 генераций", bad == 0 and got == need, "уже взятых %d, карта под билд %d/%d" % [bad, got, need],
		"есть карта под билд, нет уже взятых")

	# Смерть от волны и от HP: забег сначала, артефактов нет
	z.queue_free()
	await frames(3)
	var run_zone = load("res://minigames/anomaly_zone/zone.tscn").instantiate()
	run_zone.run_seed = 5
	root.add_child(run_zone)
	await frames(3)
	var rp: Player = run_zone.player
	rp.stats.add_artifact(ArtifactDb.make(&"kaplya"))
	rp.add_charge(2)
	var att: int = run_zone.attempt
	var t2 := 0
	while run_zone.attempt == att and t2 < 600:
		await physics_frame
		t2 += 1
	var wave_ok: bool = run_zone.attempt == att + 1 and rp.stats.artifacts.is_empty() and rp.charge == 0 and rp.hp == rp.max_hp
	rp.stats.add_artifact(ArtifactDb.make(&"gravi"))
	rp.take_damage(500.0, Vector2.ZERO, true)
	await frames(70)
	var hp_ok: bool = run_zone.attempt == att + 2 and rp.stats.artifacts.is_empty() and run_zone.run.index == 0
	row("Смерть от волны и от HP", wave_ok and hp_ok, "волна — попытка %d, HP — попытка %d, артефактов %d, участок %d" % [att + 1,
		run_zone.attempt, rp.stats.artifacts.size(), run_zone.run.index + 1], "забег сначала, артефактов нет")
	print("ИТОГ: ", "все проверки пройдены" if fails == 0 else "провалено %d" % fails)
	quit()
