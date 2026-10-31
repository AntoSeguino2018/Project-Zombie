class_name DamageIndicator
extends Control
## Archi rossi attorno al mirino che indicano da dove arriva il danno. Ogni arco
## punta verso il punto da cui si è stati colpiti e si aggiorna girandosi, così
## si capisce subito dove voltarsi; poi svanisce.

@export var color := Color(1.0, 0.15, 0.1)
## Distanza degli archi dal centro dello schermo, in pixel.
@export var radius := 150.0
## Ampiezza di ogni arco, in gradi.
@export var arc_degrees := 50.0
@export var width := 9.0
## Secondi prima che un arco sparisca.
@export var duration := 1.2

## Ogni colpo: [punto da cui arriva (Vector3), secondi rimasti].
var _hits: Array = []


## Segna un colpo arrivato dal punto from (in coordinate del mondo).
func show_hit(from: Vector3) -> void:
	_hits.append([from, duration])
	if _hits.size() > 6:
		_hits.pop_front()


func _process(delta: float) -> void:
	if _hits.is_empty():
		return
	for hit in _hits:
		hit[1] -= delta
	_hits = _hits.filter(func(hit): return hit[1] > 0.0)
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var center := size * 0.5
	for hit in _hits:
		# Direzione del colpo vista dalla camera: 0 = davanti, positivo = a destra.
		var local: Vector3 = camera.global_basis.inverse() * (hit[0] - camera.global_position)
		var angle := atan2(local.x, -local.z)
		var screen_angle := angle - PI * 0.5
		var half := deg_to_rad(arc_degrees) * 0.5
		var faded := Color(color, color.a * clampf(hit[1] / duration, 0.0, 1.0) * 0.9)
		draw_arc(center, radius, screen_angle - half, screen_angle + half, 16, faded, width, true)
