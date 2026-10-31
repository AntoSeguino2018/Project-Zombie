class_name HealthBar
extends Control
## Barra della vita del giocatore. Il danno appena subito resta visibile per un
## attimo come una striscia chiara che poi si consuma.

@export var fill_color := Color(0.45, 0.85, 0.35)
## Colore della barra quando la vita è bassa.
@export var low_color := Color(0.95, 0.3, 0.25)
@export var back_color := Color(0.0, 0.0, 0.0, 0.55)
@export var trail_color := Color(1.0, 0.95, 0.85, 0.9)
## Sotto questa frazione di vita la barra diventa del colore "basso".
@export_range(0.0, 1.0) var low_fraction := 0.3
## Secondi prima che la striscia del danno inizi a consumarsi.
@export var trail_delay := 0.35
## Velocità con cui si consuma, in frazioni della barra al secondo.
@export var trail_speed := 0.8

var _current := 100.0
var _maximum := 100.0
var _trail := 1.0
var _trail_wait := 0.0


func set_health(current: float, maximum: float) -> void:
	_current = current
	_maximum = maximum
	if _fraction() < _trail:
		_trail_wait = trail_delay
	else:
		_trail = _fraction()
	queue_redraw()


func _process(delta: float) -> void:
	if _trail <= _fraction():
		return
	if _trail_wait > 0.0:
		_trail_wait -= delta
	else:
		_trail = maxf(_fraction(), _trail - trail_speed * delta)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), back_color)
	var inner := Rect2(Vector2.ZERO, size).grow(-3.0)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * _trail, inner.size.y)), trail_color)
	var fill := low_color if _fraction() < low_fraction else fill_color
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * _fraction(), inner.size.y)), fill)

	var font := get_theme_default_font()
	var font_size := 18
	var text := "%d / %d" % [ceili(_current), roundi(_maximum)]
	var baseline := Vector2(0.0, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, 4, Color.BLACK)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color.WHITE)


func _fraction() -> float:
	return clampf(_current / _maximum, 0.0, 1.0) if _maximum > 0.0 else 0.0
