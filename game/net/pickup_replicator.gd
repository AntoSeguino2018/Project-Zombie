class_name PickupReplicator
extends MultiplayerSpawner
## Fa comparire le armi a terra su tutti i partecipanti: quelle uscite dalle
## casse e quelle lasciate da chi ne ha raccolta un'altra. Solo l'host le crea
## (con spawn_pickup) e le toglie quando qualcuno le prende; chi entra a
## partita iniziata le riceve già al loro posto.

@export var pickup_scene: PackedScene

var _next_id := 0


func _ready() -> void:
	add_to_group("pickup_replicator")
	spawn_function = _create_pickup


## Il replicatore del livello, o null se non c'è (es. scene di prova).
static func of(node: Node) -> PickupReplicator:
	return node.get_tree().get_first_node_in_group("pickup_replicator")


## Sull'host: mette a terra l'arma spec (vedi WeaponCatalog) in position.
func spawn_pickup(spec: Array, position: Vector3) -> WeaponPickup:
	_next_id += 1
	return spawn([spec, position, _next_id])


func _create_pickup(data: Array) -> Node:
	var pickup: WeaponPickup = pickup_scene.instantiate()
	pickup.name = "Pickup%d" % data[2]
	pickup.position = data[1]
	pickup.spec = data[0]
	return pickup
