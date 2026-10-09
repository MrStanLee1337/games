class_name Section2a
extends RunSection
## Участок 2а · Котлован: Жарки и Трамплины. Скоростная дорога — Форсаж и верхние дороги; связки
## «Жарка → Трамплин» проходятся за одно попадание (Трамплин — в неуязвимости после ожога).


func _build() -> void:
	_begin("Участок 2а · Котлован")
	wave_speed = 231.6  # бот (tests/run_balance.gd): v = (xБ − xА + 480) / (1.1 · T_safe)
	_run(700.0)
	_split(&"combo_zt", true)
	_run(260.0)
	_road_cache(60.0)
	_run(360.0)
	_split(&"trampolin", true)
	_run(300.0)
	_block(70.0)
	_run(320.0)
	_split(&"combo_zt", true)
	_run(300.0)
	_basin()
	_item(&"bint", 150.0)
	_run(300.0)
	_pit(140.0)
	_run(300.0)
	_split(&"trampolin", true)
	_run(300.0)
	_rare_tower()
	_item(&"aptechka", 120.0)
	_run(260.0)
	_block(140.0)
	_run(360.0)
	_split(&"trampolin", true)
	_run(400.0)
	_shelter()
	_end_build()
