class_name MovementConfig
extends Resource
## Все числа движения игрока в одном месте (по образцу items/artifact_db.gd).
## Экземпляр по умолчанию — movement_default.tres. В player.gd констант движения нет:
## игрок читает эффективную копию (конфиг × пассивы артефактов), которую пересчитывает
## Player.recompute_movement().

@export_group("Масштаб")
## Рост героя, px. Числа ТЗ даны для H = 48; при другом росте расстояния, скорости
## и ускорения умножаются на H/48, времена не меняются.
@export var hero_height := 40.0
@export var hero_width := 24.0

@export_group("Бег")
@export var run_speed := 300.0
@export var ground_accel := 2800.0
@export var ground_decel := 3600.0
@export var air_accel := 1500.0
@export var air_decel := 700.0
## Трение на земле, пока действует внешняя сила (иначе притяжение Воронки не чувствуется).
@export var pulled_friction_mult := 0.25

@export_group("Прыжок")
@export var jump_velocity := 560.0
@export var gravity := 1500.0
@export var fall_gravity_mult := 1.6
## Во сколько раз обрезается скорость подъёма, если Пробел отпустили.
@export_range(0.0, 1.0) var jump_cut := 0.4
@export var terminal_fall := 900.0

@export_group("Прощение ввода")
@export var coyote_time := 0.1
@export var jump_buffer := 0.12
## Сколько секунд игрок проходит сквозь одностороннюю платформу после S+Пробел.
@export var drop_through_time := 0.25

@export_group("Рывок")
@export var dash_speed := 720.0
@export var dash_time := 0.18
@export var dash_cooldown := 0.4
## Скорость после рывка, доля от бега.
@export var dash_end_speed := 0.9
## Рывок на заряде Батарейки: множители скорости и длительности.
@export var charged_dash_speed := 1.6
@export var charged_dash_time := 1.3

@export_group("Камера")
@export var look_ahead := 90.0
@export var look_ahead_speed := 3.0
@export var cam_smoothing := 7.0
@export var cam_offset_y := -24.0
@export var shake_decay := 40.0

@export_group("Отладка")
## Печатать смену состояний в консоль (в оверлее F1 последние смены видны всегда).
@export var log_states := false


func body_size() -> Vector2:
	return Vector2(hero_width, hero_height)
