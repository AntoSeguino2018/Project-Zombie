class_name AmmoDisplay
extends Control
## Munizioni dell'arma in mano, allineate a destra: colpi rimasti grandi,
## capienza del caricatore piccola. Durante la ricarica sotto compare una barra
## che si riempie.

@export var text_color := Color.WHITE
## Colore quando restano pochi colpi.
@export var low_color := Color(1.0, 0.45, 0.3)
## Sotto questa frazione del caricatore i colpi sono "pochi".
@export_range(0.0, 1.0) var low_fraction := 0.25
@export var big_font_size := 44
@export var small_font_size := 22

var _weapon: Weapon


func bind(weapon: Weapon) -> void:
	_weapon = weapon


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _weapon == null or _weapon.data == null:
		return
	var font := get_theme_default_font()
	var magazine := _weapon.data.magazine_size
	var big := "∞" if magazine <= 0 else str(_weapon.ammo())
	var small := "" if magazine <= 0 else " / %d" % magazine
	var low := magazine > 0 and _weapon.ammo() <= ceili(magazine * low_fraction)
	var color := low_color if low else text_color

	var baseline := font.get_ascent(big_font_size)
	var small_width := font.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, small_font_size).x
	var big_width := font.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, big_font_size).x
	var x := size.x - small_width - big_width
	draw_string_outline(font, Vector2(x, baseline), big, HORIZONTAL_ALIGNMENT_LEFT, -1, big_font_size, 8, Color.BLACK)
	draw_string(font, Vector2(x, baseline), big, HORIZONTAL_ALIGNMENT_LEFT, -1, big_font_size, color)
	x += big_width
	draw_string_outline(font, Vector2(x, baseline), small, HORIZONTAL_ALIGNMENT_LEFT, -1, small_font_size, 6, Color.BLACK)
	draw_string(font, Vector2(x, baseline), small, HORIZONTAL_ALIGNMENT_LEFT, -1, small_font_size, text_color)

	if _weapon.is_reloading():
		var bar := Rect2(Vector2(size.x - 160.0, baseline + 8.0), Vector2(160.0, 6.0))
		draw_rect(bar.grow(2.0), Color(0.0, 0.0, 0.0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _weapon.reload_progress(), bar.size.y)), text_color)
