class_name ImpactEffect
extends Node3D
## Effetto d'impatto di un colpo: scintille e segno sulla superficie.
## Il segno sbiadisce e il nodo si elimina da solo. Le scintille si tolgono
## appena finite e i segni insieme sono al massimo MAX_ALIVE (sparisce il più
## vecchio): sparando a raffica se ne accumulavano centinaia, e ognuno costa
## qualche oggetto in più da disegnare.

## Segni dei colpi visibili insieme al massimo.
const MAX_ALIVE := 40

static var _alive: Array[ImpactEffect] = []

## Secondi prima che il segno sparisca del tutto.
@export var lifetime := 5.0

@onready var _decal: Decal = $Decal
@onready var _sparks: CPUParticles3D = $Sparks


func _ready() -> void:
	_alive.append(self)
	while _alive.size() > MAX_ALIVE:
		var oldest: ImpactEffect = _alive.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var tween := create_tween()
	tween.tween_interval(lifetime - 1.0)
	tween.tween_property(_decal, "modulate:a", 0.0, 1.0)
	tween.tween_callback(queue_free)
	var sparks_done := create_tween()
	sparks_done.tween_interval(_sparks.lifetime + 0.1)
	sparks_done.tween_callback(_sparks.queue_free)


func _exit_tree() -> void:
	_alive.erase(self)


## Posiziona l'effetto sul punto colpito, con l'asse Y allineato alla normale,
## e fa partire le scintille. Va chiamata dopo l'aggiunta alla scena.
func place(point: Vector3, normal: Vector3) -> void:
	var reference := Vector3.UP if absf(normal.y) < 0.99 else Vector3.FORWARD
	var x_axis := reference.cross(normal).normalized()
	global_transform = Transform3D(Basis(x_axis, normal, x_axis.cross(normal)), point)
	# Le scintille partono solo ora: se partissero in _ready nascerebbero
	# nell'origine del mondo, prima che l'effetto venga spostato qui.
	_sparks.reset_physics_interpolation()
	_sparks.emitting = true
