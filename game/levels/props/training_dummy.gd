extends StaticBody3D
## Manichino bersaglio per provare le armi: mostra la vita, lampeggia e oscilla
## quando viene colpito, sparisce quando viene distrutto e poi ricompare.

## Secondi prima di ricomparire dopo essere stato distrutto.
@export var respawn_time := 3.0

var _flash := StandardMaterial3D.new()

@onready var _health: HealthComponent = $Health
@onready var _visual: Node3D = $Visual
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _label: Label3D = $HealthLabel


func _ready() -> void:
	# Un materiale sovrapposto bianco e trasparente: il lampo è la sua opacità.
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	for part in _visual.get_children():
		if part is MeshInstance3D:
			part.material_overlay = _flash

	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_health.changed.connect(_update_label)
	_update_label(_health.current, _health.max_health)


func _on_damaged(_amount: float, _source: Node, _hit_position: Vector3) -> void:
	_flash.albedo_color.a = 0.7
	create_tween().tween_property(_flash, "albedo_color:a", 0.0, 0.12)
	var wobble := create_tween()
	wobble.tween_property(_visual, "rotation:z", deg_to_rad(randf_range(-6.0, 6.0)), 0.04)
	wobble.tween_property(_visual, "rotation:z", 0.0, 0.4) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_died(_source: Node) -> void:
	_set_present(false)
	await get_tree().create_timer(respawn_time).timeout
	_health.reset()
	_set_present(true)


func _set_present(present: bool) -> void:
	_visual.visible = present
	_label.visible = present
	_shape.set_deferred("disabled", not present)


func _update_label(current: float, maximum: float) -> void:
	_label.text = "%d / %d" % [ceili(current), roundi(maximum)]
