class_name Tracer
extends Node3D
## Scia luminosa di un colpo, dalla bocca dell'arma al punto d'arrivo.
## Sbiadisce in pochi centesimi di secondo e si elimina da sola.

## Durata della scia, in secondi.
@export var duration := 0.06

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(_mesh, "transparency", 1.0, duration)
	tween.tween_callback(queue_free)


## Allunga la scia da from a to (la mesh è lunga 1 m lungo -Z).
func stretch(from: Vector3, to: Vector3) -> void:
	var direction := to - from
	var up := Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.FORWARD
	global_transform = Transform3D(Basis.looking_at(direction, up), from)
	scale.z = direction.length()
