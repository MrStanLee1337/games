class_name ItemData
extends Resource
## Описание предмета. Иконки рисуются примитивами по shape и color.

enum Kind { ARTIFACT, CONSUMABLE }
enum Shape { CIRCLE, DIAMOND, TRIANGLE, SQUARE, HEXAGON, DROP, CROSS, BAR, BOLT }

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var kind: Kind = Kind.ARTIFACT
@export var color := Color.WHITE
@export var shape: Shape = Shape.CIRCLE
## Расходник: сколько HP возвращает.
@export var heal := 0.0
## Артефакт: влияние на аномалии в ауре. Элемент: {type, mult, inverted, damage_mult}.
@export var effects: Array[Dictionary] = []
## Артефакт: пассивные эффекты игроку (jump_mult, gravity_mult, regen).
@export var passives: Dictionary = {}


## Рисует иконку предмета в точке c; size — поперечник.
func draw_icon(ci: CanvasItem, c: Vector2, size: float) -> void:
	var r := size * 0.5
	var light := color.lightened(0.45)
	match shape:
		Shape.CIRCLE:
			ci.draw_circle(c, r, color)
			ci.draw_circle(c, r * 0.45, light)
		Shape.DIAMOND:
			ci.draw_colored_polygon(_poly(c, [Vector2(0, -r), Vector2(r * 0.8, 0), Vector2(0, r), Vector2(-r * 0.8, 0)]), color)
			ci.draw_colored_polygon(_poly(c, [Vector2(0, -r * 0.45), Vector2(r * 0.35, 0), Vector2(0, r * 0.45), Vector2(-r * 0.35, 0)]), light)
		Shape.TRIANGLE:
			ci.draw_colored_polygon(_poly(c, [Vector2(0, -r), Vector2(r, r * 0.8), Vector2(-r, r * 0.8)]), color)
			ci.draw_colored_polygon(_poly(c, [Vector2(0, -r * 0.2), Vector2(r * 0.35, r * 0.5), Vector2(-r * 0.35, r * 0.5)]), light)
		Shape.SQUARE:
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), color)
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.35, Vector2(r, r) * 0.7), light)
		Shape.HEXAGON:
			var pts: Array[Vector2] = []
			for i in 6:
				pts.append(Vector2.from_angle(i * TAU / 6.0) * r)
			ci.draw_colored_polygon(_poly(c, pts), color)
			ci.draw_circle(c, r * 0.4, light)
		Shape.DROP:
			ci.draw_circle(c + Vector2(0, r * 0.25), r * 0.75, color)
			ci.draw_colored_polygon(_poly(c, [Vector2(0, -r), Vector2(r * 0.62, r * 0.0), Vector2(-r * 0.62, r * 0.0)]), color)
			ci.draw_circle(c + Vector2(-r * 0.25, r * 0.3), r * 0.2, light)
		Shape.CROSS:
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), Color("e8ecf4"))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.2, -r * 0.65), Vector2(r * 0.4, r * 1.3)), color)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.65, -r * 0.2), Vector2(r * 1.3, r * 0.4)), color)
		Shape.BOLT:
			ci.draw_colored_polygon(_poly(c, [Vector2(r * 0.15, -r), Vector2(-r * 0.6, r * 0.1), Vector2(-r * 0.05, r * 0.1),
				Vector2(-r * 0.2, r), Vector2(r * 0.6, -r * 0.15), Vector2(r * 0.05, -r * 0.15)]), color)
		Shape.BAR:
			ci.draw_rect(Rect2(c + Vector2(-r, -r * 0.45), Vector2(r * 2.0, r * 0.9)), Color("e8ecf4"))
			for k in 3:
				ci.draw_rect(Rect2(c + Vector2(-r * 0.6 + k * r * 0.5, -r * 0.45), Vector2(r * 0.18, r * 0.9)), color)


static func _poly(c: Vector2, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p as Vector2))
	return out
