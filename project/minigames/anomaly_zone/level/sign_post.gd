class_name SignPost
extends Node2D
## Текстовая подсказка на уровне. Начало координат — уровень пола под табличкой.

@export var text := ""
@export var width := 320.0


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_line(Vector2(0.0, 0.0), Vector2(0.0, -34.0), Color("4f596e"), 3.0)
	var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, 15).y
	var r := Rect2(Vector2(-width * 0.5 - 8.0, -34.0 - h - 14.0), Vector2(width + 16.0, h + 12.0))
	draw_rect(r, Color("1d2027"))
	draw_rect(r, Color("4f596e"), false, 1.5)
	draw_multiline_string(font, r.position + Vector2(8.0, 20.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, 15, -1, Color(1, 1, 1, 0.85))
