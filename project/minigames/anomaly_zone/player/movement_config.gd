class_name MovementConfig
extends Resource
## Все числа движения игрока в одном месте (по образцу items/artifact_db.gd).
## Экземпляр по умолчанию — movement_default.tres. В player.gd констант движения нет:
## игрок читает эффективную копию (конфиг × пассивы артефактов), которую пересчитывает
## Player.recompute_movement() через derive().
## Числа — из ТЗ «Зона: движение игрока» для героя ростом H = 48 px.

@export_group("Масштаб")
## Рост героя, px. Если он другой, расстояния, скорости и ускорения умножаются на H/48,
## времена не меняются.
@export var hero_height := 48.0
@export var hero_width := 24.0

@export_group("Бег")
@export var run_speed := 280.0
## Полная скорость за ~0.09 с.
@export var ground_accel := 3200.0
## Остановка за ~0.07 с.
@export var ground_decel := 4200.0
## Разворот на бегу (ввод против скорости, на земле).
@export var turn_accel := 6000.0
@export var air_accel := 1800.0
@export var air_decel := 900.0
## Скорость выше бега (после рывка, толчка) при вводе в ту же сторону гаснет плавно.
@export var overspeed_drag := 250.0
## Трение на земле, пока действует внешняя сила (иначе притяжение Воронки не чувствуется).
@export var pulled_friction_mult := 0.25

@export_group("Прыжок")
## Прыжок задаётся высотой и временем до вершины; гравитация и скорость выводятся:
## g = 2h / t², v0 = 2h / t.
@export var jump_height := 112.0
@export var jump_time_to_apex := 0.38
@export var fall_gravity_mult := 1.5
## У вершины, пока держишь Пробел, гравитация меньше — время прицелиться.
@export var apex_threshold := 60.0
@export var apex_gravity_mult := 0.5
## Отпустил Пробел на подъёме — вертикальная скорость умножается на это.
@export_range(0.0, 1.0) var jump_cut := 0.5
@export var terminal_fall := 900.0

@export_group("Прощение ввода")
@export var coyote_time := 0.10
@export var jump_buffer := 0.12
## Головой задел угол потолка — сдвиг в сторону вместо удара, px.
@export var corner_correction := 8.0
## Ногами задел край платформы на подъёме — подбросить на неё, px.
@export var ledge_nudge := 6.0
## Сколько секунд игрок проходит сквозь одностороннюю платформу после S+Пробел.
@export var drop_through_time := 0.25

@export_group("Стена")
## Падая и прижимаясь к стене, игрок съезжает не быстрее этого.
@export var wall_slide_speed := 140.0
## Отскок от стены: скорость от стены и вверх (подъём ~87 px).
@export var wall_jump_out := 300.0
@export var wall_jump_up := 520.0
## Первые секунды после отскока управление к стене ослаблено, чтобы не прилипать обратно.
@export var wall_jump_lock := 0.12
@export var wall_jump_control := 0.3
## Отскоков до касания земли.
@export var wall_jumps_max := 2
## Отскок срабатывает и сразу после отрыва от стены.
@export var wall_coyote := 0.08

@export_group("Зацеп и перелезание")
## Зацеп: верх уступа между уровнем груди и этой высотой над головой, px.
@export var ledge_above_head := 12.0
## Уровень груди: px выше центра тела.
@export var ledge_chest_offset := 7.0
## Зацеп срабатывает, если край был в зоне в последние секунды.
@export var grab_buffer := 0.08
## Вис: голова на столько px выше края.
@export var hang_head_above := 10.0
@export var climb_time := 0.25
## После «отпустить» (S) или прыжка со стены — не цепляться снова столько секунд.
@export var regrab_cooldown := 0.3
## Быстрое перелезание: препятствие ниже середины тела перелезается на бегу за это время.
@export var vault_time := 0.12
@export var vault_max_height := 24.0

@export_group("Рывок (Вспышка)")
@export var dash_speed := 850.0
@export var dash_time := 0.2
## Перезарядка рывка на земле; в воздухе — один рывок до касания земли.
@export var dash_cooldown := 0.35
## Скорость после рывка, доля от бега.
@export var dash_end_speed := 1.0
## Рывок на заряде Батарейки со Вспышкой: множители скорости и длительности.
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

# Выводятся в derive(): эффективные гравитация подъёма и стартовая скорость прыжка.
var gravity := 0.0
var jump_velocity := 0.0


func body_size() -> Vector2:
	return Vector2(hero_width, hero_height)


## Пересчёт выводимых величин с пассивами артефактов.
## jump_mult умножает высоту прыжка; gravity_mult — гравитацию при той же высоте
## (прыжок становится дольше и дальше, как у Грави).
func derive(jump_mult: float, gravity_mult: float) -> void:
	var g_up := 2.0 * jump_height / (jump_time_to_apex * jump_time_to_apex)
	gravity = g_up * gravity_mult
	jump_velocity = sqrt(2.0 * gravity * jump_height * jump_mult)
