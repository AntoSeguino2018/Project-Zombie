extends Control
## Mirino a croce disegnato al centro dello schermo, con un bordo scuro
## per restare leggibile su qualsiasi sfondo.

@export var color := Color(1.0, 1.0, 1.0, 0.9)
@export var outline_color := Color(0.0, 0.0, 0.0, 0.6)
## Distanza delle linee dal centro, in pixel.
@export var gap := 5.0
## Lunghezza di ogni linea, in pixel.
@export var length := 8.0
@export var thickness := 2.0


func _draw() -> void:
	var center := size / 2.0
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var from := center + direction * gap
		var to := center + direction * (gap + length)
		draw_line(from - direction, to + direction, outline_color, thickness + 2.0)
		draw_line(from, to, color, thickness)
	draw_circle(center, 2.0, outline_color)
	draw_circle(center, 1.0, color)
