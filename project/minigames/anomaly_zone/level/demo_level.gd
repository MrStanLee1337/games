class_name DemoLevel
extends Node2D
## Демо-уровень «Зона»: семь секций слева направо. Каждая показывает одну идею механики.
## Уровень собирается кодом, чтобы все координаты были в одном месте и легко правились.
##
##  1. Разминка — бег, прыжки, стенка, рывок.
##  2. Жарка — острова над ямой; Капля гасит огонь, либо тайминг/болт.
##  3. Коридор Электр — разряжай болтами; с Каплей Электры злее (цена артефакта).
##  4. Трамплин — уступ достижим только с Пружиной (усиление и есть решение).
##  5. Воронка под пропастью — с Грави она отталкивает снизу и помогает перелететь.
##  6. Холодец и Жарка — Медуза (медленно, без урона) или Пламя (сушит, но раздувает огонь).
##  7. Финиш.

const FLOOR_Y := 600.0

var bounds := Rect2(-200.0, -300.0, 8600.0, 1300.0)
var fall_y := 960.0
var checkpoints: Array[Checkpoint] = []
var finish_sign: FinishSign


func _ready() -> void:
	_warmup()
	_zharka()
	_electra_corridor()
	_trampolin()
	_voronka()
	_kholodets()
	_finish()


# --- Секции ----------------------------------------------------------------

func _warmup() -> void:
	_floor(-200.0, 760.0)
	_floor(920.0, 1560.0)  # яма 160 px — обычный прыжок
	# Яма 260 px (1560..1820) — только с рывком.
	_plat(300.0, 520.0, 150.0, 20.0)
	_plat(520.0, 440.0, 150.0, 20.0, true)
	_plat(1180.0, 520.0, 40.0, 80.0)  # стенка
	_checkpoint(80.0)
	_sign(60.0, "A/D или ←/→ — бег\nПробел — прыжок (чем дольше держите, тем выше)")
	_sign(1400.0, "Shift — рывок.\nВ воздухе он один — восстанавливается на земле")


func _zharka() -> void:
	_floor(1820.0, 2100.0)
	_plat(2200.0, FLOOR_Y, 200.0, 40.0)  # остров под огненным столбом
	_floor(2500.0, 5600.0)  # дальше пол сплошной до пропасти Воронки
	_checkpoint(1840.0)
	_sign(1900.0, "F — бросить болт. Он провоцирует Жарку и Электру,\nа сам ничем не рискует", 360.0)
	_pickup(&"kaplya", 2040.0)
	var z := Zharka.new()
	z.size = Vector2(200.0, 200.0)
	_anomaly(z, Vector2(2300.0, FLOOR_Y))
	_pickup(&"aptechka", 2900.0)


func _electra_corridor() -> void:
	_checkpoint(3060.0)
	_sign(3100.0, "Электры бьют током. Разрядите болтом\nи бегите, пока она перезаряжается", 360.0)
	_plat(3180.0, 360.0, 1120.0, 110.0)  # потолок: сверху не перепрыгнуть
	for x in [3350.0, 3600.0, 3850.0, 4100.0]:
		_anomaly(Electra.new(), Vector2(x, FLOOR_Y - 40.0))
	_pickup(&"batareyka", 4400.0)


func _trampolin() -> void:
	_checkpoint(4560.0)
	_sign(4610.0, "Некоторые зоны почти невидимы.\nБолт их проявляет", 280.0)
	# Боковая ниша с Пружиной — в стороне от основного пути.
	_plat(4780.0, 520.0, 110.0, 20.0, true)
	_plat(4910.0, 440.0, 110.0, 20.0, true)
	_pickup(&"pruzhina", 4965.0, 440.0)
	# Высокий уступ: достаётся только трамплином с Пружиной (×2).
	_plat(4450.0, 330.0, 970.0, 20.0, true)
	_plat(5250.0, 370.0, 40.0, FLOOR_Y - 370.0)  # стена, закрывающая путь по земле
	var t := Trampolin.new()
	_anomaly(t, Vector2(5100.0, FLOOR_Y - 20.0))
	_pickup(&"gravi", 5390.0, 330.0)


func _voronka() -> void:
	_checkpoint(5400.0)
	_sign(5470.0, "Tab — инвентарь. На поясе только 3 слота:\nвыбирайте артефакты под задачу", 360.0)
	# Пропасть 640 px (5600..6240): без Грави не перелететь даже с рывком. Воронка под ней.
	var v := Voronka.new()
	v.radius = 460.0
	v.pull = 5000.0
	_anomaly(v, Vector2(5920.0, 700.0))
	_floor(6240.0, 8400.0)
	_pickup(&"aptechka", 6310.0)


func _kholodets() -> void:
	_checkpoint(6370.0)
	_pickup(&"plamya", 6580.0)
	var k := Kholodets.new()
	k.size = Vector2(700.0, 18.0)
	k.dps = 12.0
	_anomaly(k, Vector2(7190.0, FLOOR_Y))
	_pickup(&"meduza", 6880.0)  # лежит на краю лужи — риск ради награды
	_sign(6700.0, "Холодец замедляет и жжёт. Выберите: Медуза (без урона)\nили Пламя (сушит лужу, но раздувает Жарку)", 500.0)
	var z := Zharka.new()
	z.size = Vector2(110.0, 220.0)
	_anomaly(z, Vector2(7740.0, FLOOR_Y))


func _finish() -> void:
	finish_sign = FinishSign.new()
	finish_sign.position = Vector2(8200.0, FLOOR_Y)
	add_child(finish_sign)


# --- Помощники -------------------------------------------------------------

func _floor(x1: float, x2: float) -> void:
	_plat(x1, FLOOR_Y, x2 - x1, 300.0)


func _plat(x: float, y: float, w: float, h: float, one_way: bool = false) -> void:
	var p := Platform.new()
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	p.one_way = one_way
	add_child(p)


func _anomaly(a: Anomaly, pos: Vector2) -> void:
	a.position = pos
	add_child(a)


func _pickup(id: StringName, x: float, y: float = FLOOR_Y) -> void:
	var p := Pickup.new()
	p.item_id = id
	p.position = Vector2(x, y)
	add_child(p)


func _checkpoint(x: float) -> void:
	var c := Checkpoint.new()
	c.position = Vector2(x, FLOOR_Y)
	add_child(c)
	checkpoints.append(c)


func _sign(x: float, text: String, w: float = 320.0) -> void:
	var s := SignPost.new()
	s.position = Vector2(x, FLOOR_Y)
	s.text = text
	s.width = w
	add_child(s)


func _draw() -> void:
	# Точечная сетка — чтобы глазом ловить скорость и расстояния.
	for x in range(int(bounds.position.x), int(bounds.end.x), 100):
		for y in range(int(bounds.position.y), int(bounds.end.y), 100):
			draw_circle(Vector2(x, y), 2.0, Color(1, 1, 1, 0.07))
