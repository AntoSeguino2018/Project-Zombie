class_name ExplosionEffect
extends Node3D
## Esplosione: una sfera luminosa che si allarga e svanisce, un lampo di luce e
## schegge. Si elimina da solo.

## Secondi in cui la sfera svanisce.
@export var duration := 0.35

@onready var _ball: MeshInstance3D = $Ball
@onready var _light: OmniLight3D = $Light
@onready var _debris: CPUParticles3D = $Debris


## Fa esplodere l'effetto nel punto at, grande quanto radius.
func play(at: Vector3, radius: float) -> void:
	global_position = at
	_light.omni_range = radius * 3.0
	_debris.restart()
	_debris.emitting = true
	_ball.scale = Vector3.ONE * radius * 0.2
	var material: StandardMaterial3D = _ball.material_override
	var tween := create_tween().set_parallel()
	tween.tween_property(_ball, "scale", Vector3.ONE * radius, duration * 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.tween_property(_light, "light_energy", 0.0, duration)
	tween.chain().tween_interval(_debris.lifetime)
	tween.chain().tween_callback(queue_free)
