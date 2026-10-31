class_name DamageNumber
extends Label3D
## Numero di danno che salta fuori dal punto colpito, sale e sbiadisce.
## Si elimina da solo.

## Di quanto sale il numero, in metri.
@export var rise := 0.6
## Spostamento laterale casuale massimo, in metri, per non sovrapporre i numeri.
@export var scatter := 0.4
## Durata totale, in secondi.
@export var duration := 0.7
@export var kill_color := Color(1.0, 0.35, 0.3)


## Mostra amount nel punto at. Il colpo finale usa un colore e una dimensione diversi.
func show_value(amount: float, at: Vector3, killed: bool) -> void:
	text = str(roundi(amount))
	if killed:
		modulate = kill_color
		font_size = roundi(font_size * 1.4)
	# Lo spostamento laterale segue la destra della camera, così si vede sullo schermo.
	var camera := get_viewport().get_camera_3d()
	var side := camera.global_basis.x if camera else Vector3.RIGHT
	position = at + side * randf_range(-scatter, scatter) + Vector3.UP * randf_range(0.1, 0.3)

	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y + rise, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tween.chain().tween_callback(queue_free)
