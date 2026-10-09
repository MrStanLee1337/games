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
## То же в воздухе: подобрано так, чтобы прыжок из подката давал ~238 px.
@export var air_overspeed_drag := 180.0
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

@export_group("Подкат и ползком")
## Подкат: S на бегу (скорость не ниже slide_min_speed × бег).
@export var slide_speed := 400.0
@export var slide_friction := 500.0
@export var slide_time := 0.45
@export_range(0.0, 1.0) var slide_min_speed := 0.8
@export var slide_cooldown := 0.3
## Высота хитбокса в подкате, ползком и в перекате, px.
@export var crouch_height := 24.0
@export var crawl_speed := 70.0

@export_group("Падение и перекат")
## Урон от падения по высоте от верхней точки: до safe — 0; от safe до lethal — от min до max
## линейно; выше lethal — fall_damage_lethal.
@export var safe_fall_height := 288.0
@export var lethal_fall_height := 576.0
@export var fall_damage_min := 10.0
@export var fall_damage_max := 60.0
@export var fall_damage_lethal := 100.0
## Медленная посадка (парение, пар) не ранит, даже если высота большая.
@export var fall_damage_min_speed := 500.0
## Перекат: S за roll_window_before до касания или roll_window_after после.
@export var roll_window_before := 0.15
@export var roll_window_after := 0.05
@export var roll_time := 0.35
## Перекат отменяет урон до lethal_fall_height, выше — умножает на это.
@export var roll_lethal_mult := 0.5
## Ниже этой высоты S перед касанием — не перекат, а подкат или присед.
@export var roll_min_fall := 96.0
## Жёсткое приземление (без переката, выше safe) — оглушение вдобавок к урону.
@export var hard_land_stun := 0.3

@export_group("Лестница")
@export var ladder_up_speed := 160.0
@export var ladder_down_speed := 220.0
## Держишь S дольше этого — съезжаешь быстро.
@export var ladder_slide_delay := 0.3
@export var ladder_slide_speed := 480.0
## Пробел с направлением — прыжок вбок.
@export var ladder_jump_out := 200.0
@export var ladder_jump_up := 380.0

@export_group("Груз")
## Пороги эффективного груза (груз × гравитация пояса), кг: до load_medium — налегке,
## до load_heavy — средний, до load_over — тяжёлый, выше — перегруз. Порог меняется сразу.
@export var load_medium := 8.0
@export var load_heavy := 14.0
@export var load_over := 20.0
## Бег по порогам (налегке — run_speed).
@export var run_speed_medium := 260.0
@export var run_speed_heavy := 230.0
@export var run_speed_over := 110.0
## Множители высоты прыжка по порогам (налегке — 1).
@export var jump_mult_medium := 0.85
@export var jump_mult_heavy := 0.65
@export var jump_mult_over := 0.25
## Тяжёлый: зацеп только на уровне груди — верх уступа не выше груди + столько px (уступ до ~105 px).
@export var heavy_grab_above_chest := 5.0
@export var climb_time_heavy := 0.6
## Тяжёлый: безопасная высота падения (4 роста вместо 6).
@export var safe_fall_heavy := 192.0
## Перегруз: множитель скорости на лестнице.
@export var ladder_mult_over := 0.6

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

@export_group("Тихий шаг и детектор")
## Тихий шаг (Ctrl) и потолок скорости с детектором в руке; ускорения те же.
@export var walk_speed := 110.0
## Достать детектор (X) — столько секунд. Убрать — мгновенно (и Пробелом с прыжком).
@export var detector_draw_time := 0.3

@export_group("Шум")
## Радиусы шума, px. Шаги шумят раз в noise_step_interval секунд.
@export var noise_run := 220.0
@export var noise_walk := 60.0
@export var noise_slide := 160.0
## Приземление: noise_land + noise_land_per_px × высота падения.
@export var noise_land := 80.0
@export var noise_land_per_px := 0.3
@export var noise_bolt := 180.0
@export var noise_step_interval := 0.3

@export_group("Камера")
## Зум относительно базового: транзит 1, в поле аномалии и с детектором в руке ближе.
@export var zoom_field := 1.2
@export var zoom_detector := 1.35
@export var zoom_time := 0.6
## Взгляд вперёд по направлению бега: смещение и за сколько секунд набирается.
@export var look_ahead := 64.0
@export var look_ahead_time := 0.4
## Падение быстрее fall_look_speed — камера смещается вниз до fall_look px.
@export var fall_look_speed := 600.0
@export var fall_look := 96.0
@export var fall_look_time := 0.3
## Мёртвая зона по вертикали: камера не дёргается на каждом прыжке.
@export var dead_zone_y := 24.0
@export var cam_smoothing := 7.0
@export var cam_offset_y := -24.0
## Тряска только от урона и жёсткого приземления, не больше shake_max px.
@export var shake_max := 4.0
@export var shake_decay := 20.0

@export_group("Отладка")
## Печатать смену состояний в консоль (в оверлее F1 последние смены видны всегда).
@export var log_states := false

enum Tier { LIGHT, MEDIUM, HEAVY, OVER }
const TIER_NAMES := ["налегке", "средний", "тяжёлый", "перегруз"]

# Выводятся в derive(): эффективные гравитация подъёма и стартовая скорость прыжка.
var gravity := 0.0
var jump_velocity := 0.0
# Приёмы, которые отнимает груз (выставляет apply_tier()).
var tier: Tier = Tier.LIGHT
var allow_wall_jump := true
var allow_air_dash := true
var allow_slide := true
var allow_grab := true
var allow_dash := true
var tier_jump_mult := 1.0


func tier_for(load_kg: float) -> Tier:
	if load_kg > load_over:
		return Tier.OVER
	if load_kg > load_heavy:
		return Tier.HEAVY
	if load_kg > load_medium:
		return Tier.MEDIUM
	return Tier.LIGHT


## Порог груза: скорость бега, высота прыжка и отнятые приёмы. Вызывать до derive().
## Средний — нет отскока от стены и рывка в воздухе; тяжёлый — ещё нет подката, зацеп только
## до груди, подтягивание дольше, безопасное падение ниже; перегруз — нет зацепа и рывка, лестницы медленнее.
func apply_tier(t: Tier) -> void:
	tier = t
	if t >= Tier.MEDIUM:
		run_speed = run_speed_medium
		tier_jump_mult = jump_mult_medium
		allow_wall_jump = false
		allow_air_dash = false
	if t >= Tier.HEAVY:
		run_speed = run_speed_heavy
		tier_jump_mult = jump_mult_heavy
		allow_slide = false
		# Полоса зацепа: от груди + heavy_grab_above_chest вниз до середины тела (уже не 5 px, а 12).
		ledge_above_head = -(hero_height * 0.5 - ledge_chest_offset - heavy_grab_above_chest)
		ledge_chest_offset = 0.0
		climb_time = climb_time_heavy
		safe_fall_height = safe_fall_heavy
	if t >= Tier.OVER:
		run_speed = run_speed_over
		tier_jump_mult = jump_mult_over
		allow_grab = false
		allow_dash = false
		ladder_up_speed *= ladder_mult_over
		ladder_down_speed *= ladder_mult_over
		ladder_slide_speed *= ladder_mult_over


func body_size() -> Vector2:
	return Vector2(hero_width, hero_height)


## Урон от падения с высоты h (без переката).
func fall_damage(h: float) -> float:
	if h <= safe_fall_height:
		return 0.0
	if h > lethal_fall_height:
		return fall_damage_lethal
	var t := (h - safe_fall_height) / (lethal_fall_height - safe_fall_height)
	return lerpf(fall_damage_min, fall_damage_max, t)


## Пересчёт выводимых величин с пассивами артефактов.
## jump_mult умножает высоту прыжка; gravity_mult — гравитацию при той же высоте
## (прыжок становится дольше и дальше, как у Грави).
func derive(jump_mult: float, gravity_mult: float) -> void:
	var g_up := 2.0 * jump_height / (jump_time_to_apex * jump_time_to_apex)
	gravity = g_up * gravity_mult
	jump_velocity = sqrt(2.0 * gravity * jump_height * jump_mult)
