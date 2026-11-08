class_name TankShellPickup
extends StaticBody3D
## Proiettile da carro armato a terra (posato da chi lo portava): guardandolo e
## premendo E lo si mette in spalla (FpsController.host_set_shell). Se nessuno
## lo prende sparisce dopo lifetime secondi. Lo crea e lo toglie solo l'host
## (PickupReplicator.spawn_shell).
##
## build_model() è il modello del proiettile, usato anche dalla rastrelliera,
## in spalla e in prima persona: l'asse va verso -Z (la punta davanti).

@export var lifetime := 120.0

var _taken := false
var _time := 0.0


func _ready() -> void:
	add_to_group("shell_pickups")
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.3, 0.9)
	shape.shape = box
	shape.position.y = 0.15
	add_child(shape)
	var model := build_model()
	model.position.y = 0.1
	add_child(model)


func _process(delta: float) -> void:
	_time += delta
	if lifetime > 0.0 and _time >= lifetime and multiplayer.is_server():
		queue_free()


func interaction_text(player: FpsController) -> String:
	if _taken or not player.can_carry_shell():
		return ""
	return "Metti in spalla il proiettile da carro armato"


## Sull'host.
func interact(player: FpsController, _slot: int) -> void:
	if _taken or not player.can_carry_shell():
		return
	_taken = true
	player.host_set_shell(true)
	queue_free()


## Il proiettile: bossolo d'ottone e punta scura, lungo circa 77 cm, punta verso -Z.
static func build_model() -> Node3D:
	var root := Node3D.new()
	root.name = "Proiettile"
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.6, 0.25)
	brass.metallic = 1.0
	brass.roughness = 0.4
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.18, 0.2, 0.18)
	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.085
	body_mesh.bottom_radius = 0.085
	body_mesh.height = 0.55
	body_mesh.radial_segments = 10
	body_mesh.material = brass
	body.mesh = body_mesh
	body.rotation.x = -PI / 2.0
	root.add_child(body)
	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.02
	tip_mesh.bottom_radius = 0.085
	tip_mesh.height = 0.22
	tip_mesh.radial_segments = 10
	tip_mesh.material = dark
	tip.mesh = tip_mesh
	tip.rotation.x = -PI / 2.0
	tip.position.z = -0.385
	root.add_child(tip)
	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.09
	band_mesh.bottom_radius = 0.09
	band_mesh.height = 0.04
	band_mesh.radial_segments = 10
	band_mesh.material = dark
	band.mesh = band_mesh
	band.rotation.x = -PI / 2.0
	band.position.z = 0.25
	root.add_child(band)
	return root
