class_name Section3
extends RunSection
## Участок 3 — финал: все типы аномалий, развилки чаще, в конце — точка Б.


func _build() -> void:
	_begin("Участок 3")
	wave_speed = 240.4  # бот (tests/run_balance.gd): v = (xБ − xА + 480) / (1.1 · T_safe)
	_run(700.0)
	_split(&"voronka")
	_run(260.0)
	_road_cache(60.0)
	_run(360.0)
	_split(&"combo_zt")
	_run(300.0)
	_split(&"electra")
	_run(300.0)
	_basin()
	_run(300.0)
	_pit(150.0)
	_run(300.0)
	_split(&"zharka")
	_run(300.0)
	_rare_tower()
	_run(260.0)
	_block(140.0)
	_run(300.0)
	_split(&"trampolin")
	_run(300.0)
	_split(&"voronka")
	_run(400.0)
	_shelter(false, true)
	_end_build()
