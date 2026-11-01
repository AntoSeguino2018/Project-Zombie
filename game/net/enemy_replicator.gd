class_name EnemyReplicator
extends MultiplayerSpawner
## Fa comparire gli zombie su tutti i partecipanti. Solo l'host li crea (con
## spawn_enemy) e li elimina; MultiplayerSpawner li replica sugli altri con lo
## stesso nome, così vita e colpi si ritrovano con lo stesso percorso.
## Funziona anche da soli: allora c'è solo l'host.

## Tipi di zombie che possono comparire (gli spawner possono usare solo questi).
@export var enemy_scenes: Array[PackedScene] = []

var _next_id := 0


func _ready() -> void:
	add_to_group("enemy_replicator")
	spawn_function = _create_enemy


## Il replicatore del livello, o null se non c'è (es. scene di prova).
static func of(node: Node) -> EnemyReplicator:
	return node.get_tree().get_first_node_in_group("enemy_replicator")


## Sull'host: crea lo zombie di tipo scene in position, girato di yaw.
func spawn_enemy(scene: PackedScene, position: Vector3, yaw: float) -> Enemy:
	var type := enemy_scenes.find(scene)
	if type < 0:
		push_error("Zombie non registrato in EnemyReplicator: %s" % scene.resource_path)
		return null
	_next_id += 1
	return spawn([type, position, yaw, _next_id])


func _create_enemy(data: Array) -> Node:
	var enemy: Enemy = enemy_scenes[data[0]].instantiate()
	enemy.name = "Zombie%d" % data[3]
	enemy.position = data[1]
	enemy.rotation.y = data[2]
	return enemy
