class_name SandboxLevel
extends ZoneLevel
## Песочница взаимодействий аномалий: по сценке на каждую связь; в конце — полигон движения. Запуск — sandbox.tscn (F6).
## Жарки здесь периодические, чтобы горели без провокации.


func _build() -> void:
	bounds = Rect2(-200.0, -300.0, 7100.0, 1300.0)
	_floor(-200.0, 6900.0)

	# 1. Жарка сушит Холодец. С обычной Жаркой жар до лужи не достаёт, с Пламенем — достаёт.
	_checkpoint(80.0)
	_sign(260.0, "Жар горящей Жарки сушит Холодец.\nОбычный до лужи не достаёт. Возьмите Пламя", 340.0)
	_pickup(&"plamya", 480.0)
	var z1 := Zharka.new()
	z1.periodic = true
	z1.period = 2.5
	_anomaly(z1, Vector2(700.0, FLOOR_Y))
	var k1 := Kholodets.new()
	k1.size = Vector2(300.0, 18.0)
	_anomaly(k1, Vector2(950.0, FLOOR_Y))

	# 2. Электра касается лужи: разряд идёт по всей луже.
	_checkpoint(1250.0)
	_sign(1380.0, "Электра касается лужи — её разряд\nбьёт всех в луже. Бросьте болт", 320.0)
	_pickup(&"batareyka", 1560.0)
	var k2 := Kholodets.new()
	k2.size = Vector2(400.0, 18.0)
	_anomaly(k2, Vector2(1800.0, FLOOR_Y))
	_anomaly(Electra.new(), Vector2(2010.0, FLOOR_Y - 40.0))

	# 3. Воронка затягивает пламя Жарки: столб наклоняется, вокруг ядра — огненный смерч.
	_checkpoint(2300.0)
	_sign(2420.0, "Воронка затягивает огонь Жарки.\nС Грави огонь отбросит в другую сторону", 320.0)
	_pickup(&"gravi", 2640.0)
	var z3 := Zharka.new()
	z3.periodic = true
	z3.period = 2.0
	z3.size = Vector2(60.0, 180.0)
	_anomaly(z3, Vector2(2800.0, FLOOR_Y))
	var v3 := Voronka.new()
	v3.radius = 220.0
	_anomaly(v3, Vector2(3000.0, 450.0))

	# 4. Трамплин подбрасывает болт в Электру над головой.
	_checkpoint(3500.0)
	_sign(3620.0, "Бросьте болт на Трамплин —\nон долетит до Электры наверху", 300.0)
	_anomaly(Trampolin.new(), Vector2(3900.0, FLOOR_Y - 20.0))
	_anomaly(Electra.new(), Vector2(3900.0, 380.0))

	# 5. Полигон движения: подкат, ползком, лестница, перекат, верёвка.
	_checkpoint(4300.0)
	_sign(4440.0, "S на бегу — подкат под плиту.
Под длинной — ползком", 300.0)
	_plat(4650.0, -300.0, 80.0, 870.0)  # щель 30 px
	_plat(4900.0, -300.0, 260.0, 870.0)
	_sign(5280.0, "Лестница: W / S, Пробел — спрыгнуть.
С башни 432 px: S перед касанием — перекат", 330.0)
	_plat(5500.0, 168.0, 300.0, 432.0)
	var lad := Ladder.new()
	lad.position = Vector2(5470.0, 168.0)
	lad.size = Vector2(28.0, 432.0)
	add_child(lad)
	_plat(5800.0, 456.0, 80.0, 20.0)  # ступенька: 288 px от верха башни — без урона
	_sign(5960.0, "Верёвка: прыжок с зажатым W", 240.0)
	var rope := Ladder.new()
	rope.position = Vector2(6150.0, 200.0)
	rope.size = Vector2(24.0, 270.0)
	rope.one_way_top = false
	rope.rope = true
	add_child(rope)
	_plat(6210.0, 330.0, 220.0, 20.0, true)

	_finish_at(6650.0)
