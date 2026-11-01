class_name PickupReplicator
extends MultiplayerSpawner
## Fa comparire le cose a terra su tutti i partecipanti: armi (uscite dalle
## casse o lasciate da chi ne ha raccolta un'altra) e oggetti passivi lasciati
## dagli zombie. Solo l'host le crea (spawn_pickup, spawn_item) e le toglie
## quando qualcuno le prende; chi entra a partita iniziata le riceve già al
## loro posto.

enum Kind { WEAPON, ITEM }

@export var pickup_scene: PackedScene
@export var item_scene: PackedScene

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
	return spawn([Kind.WEAPON, spec, position, _next_id])


## Sull'host: mette a terra l'oggetto passivo item in position.
func spawn_item(item: PassiveItem, position: Vector3) -> ItemPickup:
	_next_id += 1
	return spawn([Kind.ITEM, item.resource_path, position, _next_id])


func _create_pickup(data: Array) -> Node:
	if data[0] == Kind.ITEM:
		var item_pickup: ItemPickup = item_scene.instantiate()
		item_pickup.name = "Item%d" % data[3]
		item_pickup.position = data[2]
		item_pickup.item_path = data[1] if ItemCatalog.is_item(data[1]) else ItemCatalog.ITEMS[0]
		return item_pickup
	var pickup: WeaponPickup = pickup_scene.instantiate()
	pickup.name = "Pickup%d" % data[3]
	pickup.position = data[2]
	pickup.spec = data[1]
	return pickup
