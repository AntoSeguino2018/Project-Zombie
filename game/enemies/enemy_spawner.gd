class_name EnemySpawner
extends Marker3D
## Fa comparire zombie in questo punto, scegliendoli a caso dalla lista, finché
## non ce ne sono max_alive vivi insieme. Quando ne muore uno, dopo un po' ne
## arriva un altro. Provvisorio: più avanti gli spawn li deciderà il director
## della Fase 3.
## Gli zombie li crea solo l'host; se nel livello c'è un EnemyReplicator
## compaiono anche sugli altri partecipanti.

## Tipi di zombie tra cui scegliere. Ripetere un tipo lo rende più frequente.
@export var enemy_scenes: Array[PackedScene] = []
## Secondi prima del primo zombie.
@export var initial_delay := 3.0
## Secondi tra una comparsa e la successiva.
@export var spawn_interval := 4.0
## Zombie vivi al massimo, contando solo quelli nati qui.
@export var max_alive := 1

var _alive: Array[Node] = []
var _timer := Timer.new()


func _ready() -> void:
	if not multiplayer.is_server():
		return
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)
	_timer.start(initial_delay)


func _on_timer() -> void:
	if _alive.size() < max_alive and not enemy_scenes.is_empty():
		_spawn(enemy_scenes.pick_random())
	if _alive.size() < max_alive:
		_timer.start(spawn_interval)


func _spawn(scene: PackedScene) -> void:
	# Un piccolo scarto a caso, così non nascono uno dentro l'altro.
	var at := position + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	var replicator := EnemyReplicator.of(self)
	var enemy: Node3D
	if replicator:
		enemy = replicator.spawn_enemy(scene, at, rotation.y)
	else:
		enemy = scene.instantiate()
		enemy.position = at
		enemy.rotation.y = rotation.y
		add_sibling(enemy)
	if enemy == null:
		return
	_alive.append(enemy)
	HealthComponent.of(enemy).died.connect(_on_enemy_died.bind(enemy), CONNECT_ONE_SHOT)


func _on_enemy_died(_source: Node, enemy: Node) -> void:
	_alive.erase(enemy)
	if _timer.is_stopped():
		_timer.start(spawn_interval)
