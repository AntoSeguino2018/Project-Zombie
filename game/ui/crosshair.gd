class_name Crosshair
extends Control
## Mirino a croce disegnato al centro dello schermo, con un bordo scuro
## per restare leggibile su qualsiasi sfondo. Mostra anche l'hitmarker
## (una X attorno al centro) quando un colpo fa danno.

@export var color := Color(1.0, 1.0, 1.0, 0.9)
@export var outline_color := Color(0.0, 0.0, 0.0, 0.6)
## Distanza delle linee dal centro, in pixel.
@export var gap := 5.0
## Lunghezza di ogni linea, in pixel.
@export var length := 8.0
@export var thickness := 2.0

@export_group("Hitmarker")
@export var hit_color := Color(1.0, 1.0, 1.0)
@export var kill_color := Color(1.0, 0.3, 0.25)
## Durata dell'hitmarker, in secondi (doppia sul colpo finale).
@export var hit_duration := 0.15

var _hit_time_left := 0.0
var _hit_total := 1.0
var _hit_killed := false


func _process(delta: float) -> void:
	if _hit_time_left > 0.0:
		_hit_time_left = maxf(_hit_time_left - delta, 0.0)
		queue_redraw()


func show_hit(killed: bool) -> void:
	_hit_killed = killed
	_hit_total = hit_duration * (2.0 if killed else 1.0)
	_hit_time_left = _hit_total
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var from := center + direction * gap
		var to := center + direction * (gap + length)
		draw_line(from - direction, to + direction, outline_color, thickness + 2.0)
		draw_line(from, to, color, thickness)
	draw_circle(center, 2.0, outline_color)
	draw_circle(center, 1.0, color)

	if _hit_time_left > 0.0:
		var marker_color := kill_color if _hit_killed else hit_color
		marker_color.a *= _hit_time_left / _hit_total
		var scale := 1.3 if _hit_killed else 1.0
		for diagonal: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var dir := diagonal.normalized()
			draw_line(center + dir * 7.0 * scale, center + dir * 14.0 * scale, marker_color, thickness)
