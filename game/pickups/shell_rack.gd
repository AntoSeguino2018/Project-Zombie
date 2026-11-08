class_name ShellRack
extends StaticBody3D
## Cassa dell'esercito con un proiettile da carro armato sopra (laboratori e
## parcheggio del campus). Guardandola e premendo E il proiettile va in spalla;
## dopo refill_time secondi ne ricompare un altro. Gratis: il prezzo è trovare
## un compagno con il martello.
##
## La forma si costruisce qui. In rete decide l'host; gli altri vedono il
## proiettile sparire e ricomparire (anche chi entra a partita iniziata).

## Secondi prima che ricompaia il proiettile.
@export var refill_time := 90.0

var stocked := true

var _refill_left := 0.0
var _shell: Node3D


func _ready() -> void:
	add_to_group("shell_racks")
	collision_layer = 1 | 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.7, 0.9)
	shape.shape = box
	shape.position.y = 0.35
	add_child(shape)
	var crate := MeshInstance3D.new()
	var crate_mesh := BoxMesh.new()
	crate_mesh.size = Vector3(1.2, 0.6, 0.9)
	var crate_material := StandardMaterial3D.new()
	crate_material.albedo_color = Color(0.3, 0.37, 0.25)
	crate_mesh.material = crate_material
	crate.mesh = crate_mesh
	crate.position.y = 0.3
	add_child(crate)
	_shell = TankShellPickup.build_model()
	_shell.position.y = 0.7
	_shell.rotation.y = PI / 2.0
	add_child(_shell)
	if multiplayer.is_server() and NetSession.is_online():
		multiplayer.peer_connected.connect(func(id: int): _receive_stocked.rpc_id(id, stocked))


func _physics_process(delta: float) -> void:
	if stocked or not multiplayer.is_server():
		return
	_refill_left -= delta
	if _refill_left <= 0.0:
		_set_stocked(true)


func interaction_text(player: FpsController) -> String:
	if not stocked or not player.can_carry_shell():
		return ""
	return "Metti in spalla il proiettile da carro armato"


## Sull'host.
func interact(player: FpsController, _slot: int) -> void:
	if not stocked or not player.can_carry_shell():
		return
	player.host_set_shell(true)
	_refill_left = refill_time
	_set_stocked(false)


## Sull'host, a inizio run: di nuovo pieno.
func host_reset() -> void:
	if not stocked:
		_set_stocked(true)


func _set_stocked(on: bool) -> void:
	_apply_stocked(on)
	if NetSession.is_online():
		_receive_stocked.rpc(on)


@rpc("authority", "call_remote", "reliable")
func _receive_stocked(on: bool) -> void:
	_apply_stocked(on)


func _apply_stocked(on: bool) -> void:
	stocked = on
	_shell.visible = on
