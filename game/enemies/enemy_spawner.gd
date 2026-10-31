class_name EnemySpawner
extends Marker3D
## Fa comparire un nemico in questo punto e, quando muore, ne fa comparire un
## altro dopo qualche secondo. Provvisorio: più avanti gli spawn li deciderà il
## director della Fase 3.

@export var enemy_scene: PackedScene
## Secondi prima del primo nemico.
@export var initial_delay := 3.0
## Secondi tra la morte di un nemico e la comparsa del successivo.
@export var respawn_delay := 4.0

var _timer := Timer.new()


func _ready() -> void:
	if not is_multiplayer_authority():
		return
	_timer.one_shot = true
	_timer.timeout.connect(_spawn)
	add_child(_timer)
	_timer.start(initial_delay)


func _spawn() -> void:
	var enemy: Node3D = enemy_scene.instantiate()
	enemy.transform = transform
	add_sibling(enemy)
	HealthComponent.of(enemy).died.connect(_on_enemy_died, CONNECT_ONE_SHOT)


func _on_enemy_died(_source: Node) -> void:
	_timer.start(respawn_delay)
