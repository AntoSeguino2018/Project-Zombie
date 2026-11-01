class_name BurnFlames
extends CPUParticles3D
## Fiamme sopra un corpo che brucia: blocchetti arancioni che salgono e
## svaniscono. Le crea e le toglie HealthComponent.


func _init() -> void:
	position = Vector3(0.0, 1.0, 0.0)
	amount = 40
	lifetime = 0.6
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = Vector3(0.35, 0.6, 0.35)
	direction = Vector3.UP
	spread = 15.0
	gravity = Vector3(0.0, 2.5, 0.0)
	initial_velocity_min = 0.5
	initial_velocity_max = 1.5
	scale_amount_min = 0.8
	scale_amount_max = 1.6
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	scale_amount_curve = fade
	var colors := Gradient.new()
	colors.set_color(0, Color(1.0, 0.7, 0.15))
	colors.set_color(1, Color(0.9, 0.2, 0.05))
	color_ramp = colors
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.16
	cube.material = material
	mesh = cube
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
