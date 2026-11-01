class_name WaveDirector
extends Node3D
## Manda gli zombie a ondate. Ogni ondata ha un budget di pericolosità che sale
## e lo spende scegliendo tipi di zombie (WaveEnemy) fino a esaurirlo; i pesi
## cambiano a caso a ogni ondata, così la composizione non è mai la stessa.
## Gli zombie escono, uno alla volta, dai punti di comparsa (i Marker3D figli)
## che nessun giocatore sta guardando. L'ondata finisce quando sono morti tutti;
## dopo una pausa parte la successiva.
##
## Decide tutto l'host; gli altri ricevono numero dell'ondata, fase, zombie
## rimasti e secondi alla prossima (anche chi entra a partita iniziata).

## Ondata o pausa cambiata, o zombie rimasti cambiati.
signal state_changed
## È partita l'ondata wave.
signal wave_started(wave: int)
## L'ondata wave è stata ripulita.
signal wave_cleared(wave: int)

enum Phase { WAITING, ACTIVE, BREAK }

const LAYER_WORLD := 1

## Tipi di zombie che le ondate possono mandare.
@export var enemies: Array[WaveEnemy] = []

@export_group("Budget")
## Budget della prima ondata.
@export var base_budget := 6.0
## Quanto sale il budget a ogni ondata...
@export var budget_growth := 3.0
## ...più questo per il quadrato delle ondate passate (crescita che accelera).
@export var budget_acceleration := 0.5
## Budget in più per ogni giocatore oltre il primo, in frazione.
@export var budget_per_extra_player := 0.6
## Quanto varia a caso il peso di ogni tipo da un'ondata all'altra (0 = mai).
@export_range(0.0, 1.0) var weight_variation := 0.75

@export_group("Tempi")
## Secondi prima della prima ondata.
@export var start_delay := 6.0
## Secondi di pausa tra un'ondata e la successiva.
@export var break_time := 12.0
## Secondi tra la comparsa di uno zombie e il successivo.
@export var spawn_interval := 0.7
## Zombie vivi al massimo insieme, con un solo giocatore...
@export var max_alive := 10
## ...più questi per ogni giocatore in più.
@export var max_alive_per_extra_player := 4

@export_group("Comparsa")
## Gli zombie non compaiono più vicini di così a un giocatore.
@export var min_spawn_distance := 14.0
## Oltre questa distanza un punto conta come fuori vista anche se è scoperto.
@export var view_distance := 45.0
## Metà dell'angolo di vista dei giocatori, in gradi (con un po' di margine).
@export var view_half_angle_degrees := 70.0
## Si sceglie a caso tra questi punti validi, i più vicini ai giocatori.
@export var nearest_choices := 3

var wave := 0
var phase := Phase.WAITING
## Zombie dell'ondata ancora da uccidere (in campo e in arrivo).
var remaining := 0

var _time_left := 0.0
var _spawn_left := 0.0
var _queue: Array[WaveEnemy] = []
var _alive: Array[Node] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("wave_director")
	_rng.randomize()
	if not multiplayer.is_server():
		return
	_time_left = start_delay
	if NetSession.is_online():
		multiplayer.peer_connected.connect(_send_state)


## Il director del livello, o null se non c'è.
static func of(node: Node) -> WaveDirector:
	return node.get_tree().get_first_node_in_group("wave_director")


## Secondi alla prossima ondata (durante l'attesa e la pausa).
func seconds_to_next_wave() -> float:
	return maxf(_time_left, 0.0)


## Budget dell'ondata number per players giocatori.
func budget_for(number: int, players: int) -> float:
	var passed := float(number - 1)
	var budget := base_budget + budget_growth * passed + budget_acceleration * passed * passed
	return budget * (1.0 + budget_per_extra_player * maxf(players - 1, 0))


## Gli zombie che manda un'ondata con quel budget, nell'ordine di arrivo.
func compose(number: int, budget: float) -> Array[WaveEnemy]:
	var weights := {}
	for enemy in enemies:
		if enemy.first_wave <= number:
			weights[enemy] = enemy.weight * _rng.randf_range(1.0 - weight_variation, 1.0 + weight_variation)
	var result: Array[WaveEnemy] = []
	while true:
		var choices: Array = weights.keys().filter(func(e: WaveEnemy): return e.cost <= budget)
		if choices.is_empty():
			break
		var enemy: WaveEnemy = _pick_weighted(choices, weights)
		result.append(enemy)
		budget -= enemy.cost
	return result


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		_time_left -= delta
		return
	match phase:
		Phase.WAITING, Phase.BREAK:
			_time_left -= delta
			if _time_left <= 0.0:
				_start_wave()
		Phase.ACTIVE:
			_spawn_left -= delta
			if _spawn_left <= 0.0 and not _queue.is_empty() and _alive.size() < _alive_cap():
				_spawn_left = spawn_interval
				_spawn(_queue.pop_front())


func _start_wave() -> void:
	wave += 1
	phase = Phase.ACTIVE
	_queue = compose(wave, budget_for(wave, _player_count()))
	remaining = _queue.size()
	_spawn_left = 0.0
	_publish()
	_announce_start(wave)
	if NetSession.is_online():
		_announce_start.rpc(wave)


func _spawn(enemy_type: WaveEnemy) -> void:
	var point := _pick_spawn_point()
	# Un piccolo scarto a caso, così non nascono uno dentro l'altro.
	var at := point.global_position + Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
	# Girato verso il giocatore più vicino.
	var yaw := point.global_rotation.y
	var players := _living_players()
	if not players.is_empty():
		var nearest: Node3D = players[0]
		for player in players:
			if player.global_position.distance_to(at) < nearest.global_position.distance_to(at):
				nearest = player
		var to_player := nearest.global_position - at
		yaw = atan2(-to_player.x, -to_player.z)
	var replicator := EnemyReplicator.of(self)
	var enemy: Node3D
	if replicator:
		enemy = replicator.spawn_enemy(enemy_type.scene, at, yaw)
	else:
		enemy = enemy_type.scene.instantiate()
		enemy.position = at
		enemy.rotation.y = yaw
		get_parent().add_child(enemy)
	if enemy == null:
		_on_enemy_gone(null)
		return
	_alive.append(enemy)
	HealthComponent.of(enemy).died.connect(func(_source): _on_enemy_gone(enemy), CONNECT_ONE_SHOT)
	# Se sparisce senza morire (es. livello chiuso) non blocca l'ondata.
	enemy.tree_exiting.connect(func(): if _alive.has(enemy): _on_enemy_gone(enemy), CONNECT_ONE_SHOT)


func _on_enemy_gone(enemy: Node) -> void:
	# Il livello si sta chiudendo: non c'è più un'ondata da seguire.
	if not is_inside_tree():
		return
	if enemy:
		_alive.erase(enemy)
	remaining = maxi(remaining - 1, 0)
	if remaining == 0 and phase == Phase.ACTIVE:
		phase = Phase.BREAK
		_time_left = break_time
		_announce_cleared(wave)
		if NetSession.is_online():
			_announce_cleared.rpc(wave)
	_publish()


## Un punto di comparsa che nessun giocatore vede e non troppo vicino; tra i
## validi, uno a caso dei più vicini, così gli zombie arrivano presto. Se non ce
## ne sono, il più lontano da tutti.
func _pick_spawn_point() -> Marker3D:
	var points: Array[Marker3D] = []
	for child in get_children():
		if child is Marker3D:
			points.append(child)
	var players := _living_players()
	if players.is_empty():
		return points[_rng.randi() % points.size()]
	var valid: Array = []
	var farthest: Marker3D = points[0]
	var farthest_distance := -1.0
	for point in points:
		var distance := _distance_to_nearest(point.global_position, players)
		if distance > farthest_distance:
			farthest = point
			farthest_distance = distance
		if distance >= min_spawn_distance and not players.any(func(p): return _sees(p, point.global_position)):
			valid.append([distance, point])
	if valid.is_empty():
		return farthest
	valid.sort_custom(func(a, b): return a[0] < b[0])
	return valid[_rng.randi() % mini(nearest_choices, valid.size())][1]


## Vero se il giocatore potrebbe vedere qualcosa che compare in at.
func _sees(player: Node3D, at: Vector3) -> bool:
	var eye := player.global_position + Vector3.UP * 1.6
	var target := at + Vector3.UP * 1.2
	var to_target := target - eye
	if to_target.length() > view_distance:
		return false
	var forward := -player.global_basis.z
	var flat := Vector3(to_target.x, 0.0, to_target.z).normalized()
	if Vector3(forward.x, 0.0, forward.z).normalized().dot(flat) < cos(deg_to_rad(view_half_angle_degrees)):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, LAYER_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _distance_to_nearest(at: Vector3, players: Array[Node3D]) -> float:
	var best := INF
	for player in players:
		best = minf(best, player.global_position.distance_to(at))
	return best


func _living_players() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for player: Node3D in get_tree().get_nodes_in_group("players"):
		var health := HealthComponent.of(player)
		if health and health.is_alive():
			result.append(player)
	return result


func _player_count() -> int:
	return maxi(get_tree().get_nodes_in_group("players").size(), 1)


func _alive_cap() -> int:
	return max_alive + max_alive_per_extra_player * (_player_count() - 1)


func _pick_weighted(choices: Array, weights: Dictionary) -> Variant:
	var total := 0.0
	for choice in choices:
		total += weights[choice]
	var r := _rng.randf() * total
	for choice in choices:
		r -= weights[choice]
		if r < 0.0:
			return choice
	return choices.back()


## Sull'host: avvisa tutti dello stato attuale.
func _publish() -> void:
	state_changed.emit()
	if NetSession.is_online():
		_receive_state.rpc(wave, phase, remaining, _time_left)


func _send_state(peer: int) -> void:
	_receive_state.rpc_id(peer, wave, phase, remaining, _time_left)


@rpc("authority", "call_remote", "reliable")
func _receive_state(new_wave: int, new_phase: int, new_remaining: int, time_left: float) -> void:
	wave = new_wave
	phase = new_phase as Phase
	remaining = new_remaining
	_time_left = time_left
	state_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _announce_start(number: int) -> void:
	wave_started.emit(number)


@rpc("authority", "call_remote", "reliable")
func _announce_cleared(number: int) -> void:
	wave_cleared.emit(number)
