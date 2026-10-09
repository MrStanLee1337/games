class_name RunSection
extends ZoneLevel
## Участок забега (~50 с безопасной дорогой). Собирается из кусков слева направо по курсору _x.
## Главная дорога — пол на FLOOR_Y. Развилка (_split) — ров глубиной TRENCH: безопасная дорога идёт
## по дну и выходит по двум ступеням высотой STEP (медленно), скоростная — поверху по площадкам
## сквозь аномалии (Форсаж, заряд и рывок, подброс на верхнюю дорогу, Праща). Сорвался со скоростной —
## оказался на безопасной. Дороги расходятся и сходятся на каждой развилке.
## Скорость волны wave_speed считает бот (tests/run_balance.gd) по времени безопасной дороги.

const TRENCH := 240.0
const STEP := 120.0
const PLAT_H := 20.0
## Верхняя дорога после Трамплина: ниже подброса (190; с Грави 133 — не достать), а спрыгнуть с неё
## даже с прыжком под Лёгкостью (140 + 135) — ещё без урона от падения (288).
const RUNWAY_H := 140.0
## Длина развилки каждого вида.
const SPLIT_LEN := {&"zharka": 1100.0, &"electra": 1200.0, &"trampolin": 1200.0, &"voronka": 1300.0, &"combo_zt": 1200.0}

## Название участка для HUD.
var title := ""
## Двери развилки (только у участка перед развилкой).
var doors: Array[ForkDoor] = []
var _x := 0.0
var _floor_from := 0.0
var _floor_open := false


func _begin(t: String) -> void:
	title = t
	_floor_from = -600.0
	_floor_open = true
	_x = 0.0
	_start(150.0)


func _end_build() -> void:
	bounds = Rect2(-600.0, -400.0, _x + 1200.0, 1700.0)
	fall_y = FLOOR_Y + TRENCH + 400.0


func _close() -> void:
	if _floor_open and _x > _floor_from:
		_floor(_floor_from, _x)
	_floor_open = false


func _open() -> void:
	_floor_from = _x
	_floor_open = true


# --- Куски трассы ------------------------------------------------------------

func _run(length: float) -> void:
	_x += length


## Яма на общей дороге (прыжком; упал — урон и возврат).
func _pit(w: float) -> void:
	_close()
	_x += w
	_open()


## Препятствие на дороге: до 24 px — перелезть на бегу, до ~100 — перепрыгнуть, выше — зацеп.
func _block(h: float, w: float = 60.0) -> void:
	_plat(_x, FLOOR_Y - h, w, h)
	_x += w


## Развилка: ров (безопасно и медленно) и скоростная дорога поверху сквозь аномалии вида kind.
## slow — посреди рва ещё блок, на который надо взбираться (безопасная дорога медленнее).
func _split(kind: StringName, slow: bool = false) -> void:
	_close()
	var x0 := _x
	var L: float = SPLIT_LEN[kind]
	var fy := FLOOR_Y
	_plat(x0, fy + TRENCH, L, 300.0)  # дно рва
	_plat(x0 + L - 140.0, fy + STEP, 140.0, STEP)  # ступень на выходе: из рва — два подъёма по STEP
	if slow:
		_plat(x0 + L * 0.5 - 40.0, fy + TRENCH - 130.0, 80.0, 130.0)
	match kind:
		&"zharka":
			# Площадка с широкой Жаркой: влетел — Форсаж (и 12 урона).
			_plat(x0 + 130.0, fy, 400.0, PLAT_H)
			var z := Zharka.new()
			z.size = Vector2(200.0, 150.0)
			_anomaly(z, Vector2(x0 + 360.0, fy))
			_plat(x0 + 660.0, fy, L - 150.0 - 660.0, PLAT_H)
		&"electra":
			# Электра даёт заряд; разрыв 300 px берётся только прыжком с рывком.
			_plat(x0 + 130.0, fy, 430.0, PLAT_H)
			_anomaly(Electra.new(), Vector2(x0 + 400.0, fy - 40.0))
			_plat(x0 + 860.0, fy, L - 150.0 - 860.0, PLAT_H)
		&"trampolin":
			# Трамплин подбрасывает на верхнюю дорогу (односторонняя, без ям), спуск — за рвом.
			_plat(x0 + 130.0, fy, 270.0, PLAT_H)
			_anomaly(Trampolin.new(), Vector2(x0 + 330.0, fy - 20.0))
			_plat(x0 + 340.0, fy - RUNWAY_H, L - 340.0 + 200.0, PLAT_H, true)
		&"combo_zt":
			# Жарка и сразу Трамплин: Трамплин приходится на неуязвимость после ожога —
			# два баффа за одно попадание (12 урона), дальше верхняя дорога.
			_plat(x0 + 130.0, fy, 400.0, PLAT_H)
			var zc := Zharka.new()
			zc.size = Vector2(160.0, 150.0)
			_anomaly(zc, Vector2(x0 + 260.0, fy))
			_anomaly(Trampolin.new(), Vector2(x0 + 470.0, fy - 20.0))
			_plat(x0 + 480.0, fy - RUNWAY_H, L - 480.0 + 200.0, PLAT_H, true)
		&"voronka":
			# Воронка над площадкой разгоняет: Праща даёт прыжок через разрыв 330 px.
			_plat(x0 + 130.0, fy, 570.0, PLAT_H)
			var v := Voronka.new()
			v.radius = 220.0
			v.pull = 2500.0
			_anomaly(v, Vector2(x0 + 420.0, fy - 40.0))
			_plat(x0 + 1030.0, fy, L - 150.0 - 1030.0, PLAT_H)
	_x = x0 + L
	_open()


## Ванна с Холодцом под односторонним мостом: лечиться — S+Пробел с моста, выход — прыжок вверх.
func _basin() -> void:
	_close()
	var x0 := _x
	_plat(x0, FLOOR_Y, 340.0, PLAT_H, true)
	_plat(x0, FLOOR_Y + 90.0, 340.0, 300.0)
	var k := Kholodets.new()
	k.size = Vector2(300.0, 18.0)
	_anomaly(k, Vector2(x0 + 170.0, FLOOR_Y + 90.0))
	_x += 340.0
	_open()


## Расходник на дороге (Е — подобрать).
func _item(id: StringName, dx: float = 0.0) -> void:
	_pickup(id, _x + dx)


## Обычный тайник на дороге.
func _road_cache(dx: float = 0.0) -> void:
	_cache(_x + dx, false)


## Редкий тайник на башне в стороне: лестница на h px (крюк на несколько секунд).
func _rare_tower(h: float = 460.0) -> void:
	var lx := _x + 40.0
	_ladder(lx, FLOOR_Y - h, FLOOR_Y)
	_plat(lx + 28.0, FLOOR_Y - h, 170.0, PLAT_H)
	_cache(lx + 140.0, true, FLOOR_Y - h)
	_x += 260.0


## Укрытие (точка Б участка). fork — двери развилки внутри; final — финиш забега.
func _shelter(fork: bool = false, final: bool = false) -> void:
	var s := Shelter.new()
	s.final = final
	s.position = Vector2(_x + 100.0, FLOOR_Y)
	add_child(s)
	goal = s
	if fork:
		doors.append(_door(_x + 360.0, RunManager.BRANCH_A, "2а · Котлован", [Anomaly.Type.ZHARKA, Anomaly.Type.TRAMPLIN]))
		doors.append(_door(_x + 620.0, RunManager.BRANCH_B, "2б · Подстанция", [Anomaly.Type.ELECTRA, Anomaly.Type.VORONKA]))
	_x += 820.0
	_close()
	_plat(_x, FLOOR_Y - 600.0, 60.0, 600.0)  # глухая стена за укрытием
	_x += 60.0


func _door(x: float, branch: StringName, t: String, types: Array[int]) -> ForkDoor:
	var d := ForkDoor.new()
	d.branch = branch
	d.title = t
	d.types = types
	d.position = Vector2(x, FLOOR_Y)
	add_child(d)
	return d
