class_name RunManager
extends Node
## La run in corso. È persa quando nessun giocatore è più in piedi (tutti a
## terra o morti): si mostra il riepilogo e dopo qualche secondo si riparte da
## capo (ondata 1, solo la pistola, niente soldi, casse chiuse). A ogni ondata
## superata chi è a terra si rialza, chi è morto rinasce vicino a un compagno
## e tutti ricevono un premio in soldi e un oggetto passivo a caso. Chi uccide
## uno zombie ne prende la taglia (Enemy.bounty); a volte lo zombie lascia a
## terra un oggetto che può prendere chiunque.
##
## Decide tutto l'host; gli altri ricevono quando la run è persa e quando
## riparte (anche chi entra mentre il riepilogo è a schermo).

signal run_lost(wave: int)
signal run_restarted

## Secondi di riepilogo prima di ripartire.
@export var restart_delay := 8.0
## Premio a ogni giocatore per un'ondata superata: base + per_wave × ondata.
@export var wave_reward_base := 25
@export var wave_reward_per_wave := 5

## Ondata più alta raggiunta in questa sessione di gioco.
static var best_wave := 0

var lost := false
var lost_wave := 0

var _restart_left := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("run_manager")
	_rng.randomize()
	if not multiplayer.is_server():
		return
	_connect_waves.call_deferred()
	CombatEvents.bus.enemy_killed.connect(_on_enemy_killed)
	if NetSession.is_online():
		multiplayer.peer_connected.connect(func(id: int):
			if lost:
				_receive_lost.rpc_id(id, lost_wave, _restart_left))


## La run del livello, o null se non c'è (es. scene di prova).
static func of(node: Node) -> RunManager:
	return node.get_tree().get_first_node_in_group("run_manager")


## Vero se la run è in corso (o se non c'è una run).
static func is_running(node: Node) -> bool:
	var run := of(node)
	return run == null or not run.lost


## Secondi alla ripartenza mentre la run è persa.
func restart_seconds_left() -> float:
	return maxf(_restart_left, 0.0)


func _connect_waves() -> void:
	var waves := WaveDirector.of(self)
	if waves:
		waves.wave_cleared.connect(_on_wave_cleared)


func _exit_tree() -> void:
	if CombatEvents.bus.enemy_killed.is_connected(_on_enemy_killed):
		CombatEvents.bus.enemy_killed.disconnect(_on_enemy_killed)


## Sull'host: la taglia dello zombie va a chi l'ha ucciso (con gli oggetti che
## la aumentano o che curano a ogni uccisione); a volte lascia un oggetto.
func _on_enemy_killed(enemy: Node, killer: Node) -> void:
	if not enemy is Enemy or lost:
		return
	if killer is FpsController:
		var inventory: RunInventory = killer.inventory()
		inventory.host_add_money(roundi(enemy.bounty * (1.0 + inventory.stat("kill_money"))))
		var heal := inventory.stat("kill_heal")
		if heal > 0.0:
			HealthComponent.of(killer).heal(heal)
	if _rng.randf() < enemy.item_drop_chance:
		var replicator := PickupReplicator.of(self)
		if replicator:
			replicator.spawn_item(ItemCatalog.roll(_rng), enemy.global_position + Vector3.UP * 0.9)


func _on_wave_cleared(wave: int) -> void:
	_bring_back_fallen()
	for player in _players():
		player.inventory().host_add_money(wave_reward_base + wave_reward_per_wave * wave)
		player.inventory().host_add_item(ItemCatalog.roll(_rng))


func _physics_process(delta: float) -> void:
	if lost:
		_restart_left -= delta
	if not multiplayer.is_server():
		return
	if lost:
		if _restart_left <= 0.0:
			_host_restart()
	elif _nobody_standing():
		_host_lose()


func _players() -> Array[FpsController]:
	var result: Array[FpsController] = []
	for player in get_tree().get_nodes_in_group("players"):
		if player is FpsController and not player.is_queued_for_deletion():
			result.append(player)
	return result


func _nobody_standing() -> bool:
	var players := _players()
	return not players.is_empty() and not players.any(func(p: FpsController): return p.is_standing())


## Sull'host, a fine ondata: chi è a terra si rialza, chi è morto rinasce
## accanto a un compagno in piedi.
func _bring_back_fallen() -> void:
	if lost:
		return
	var standing := _players().filter(func(p: FpsController): return p.is_standing())
	for player in _players():
		match player.life:
			FpsController.Life.DOWNED:
				player.host_revive()
			FpsController.Life.DEAD:
				var at := player._spawn_transform.origin
				if not standing.is_empty():
					var buddy: FpsController = standing[_rng.randi() % standing.size()]
					var side := Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU)
					at = buddy.global_position + side * 1.2 + Vector3.UP * 0.1
				player.host_respawn(at)


func _host_lose() -> void:
	var waves := WaveDirector.of(self)
	var wave := waves.wave if waves else 0
	if waves:
		waves.host_pause()
	_apply_lost(wave, restart_delay)
	if NetSession.is_online():
		_receive_lost.rpc(wave, restart_delay)


@rpc("authority", "call_remote", "reliable")
func _receive_lost(wave: int, restart_left: float) -> void:
	_apply_lost(wave, restart_left)


func _apply_lost(wave: int, restart_left: float) -> void:
	lost = true
	lost_wave = wave
	_restart_left = restart_left
	best_wave = maxi(best_wave, wave)
	run_lost.emit(wave)


## Sull'host: tutto da capo. Le ondate prima degli zombie, così togliere gli
## zombie rimasti non conta come uccisioni dell'ondata.
func _host_restart() -> void:
	var waves := WaveDirector.of(self)
	if waves:
		waves.host_restart()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	for pickup in get_tree().get_nodes_in_group("weapon_pickups"):
		pickup.queue_free()
	for pickup in get_tree().get_nodes_in_group("item_pickups"):
		pickup.queue_free()
	for crate in get_tree().get_nodes_in_group("weapon_crates"):
		crate.host_reset()
	for player in _players():
		player.host_restart()
	_apply_restarted()
	if NetSession.is_online():
		_receive_restarted.rpc()


@rpc("authority", "call_remote", "reliable")
func _receive_restarted() -> void:
	_apply_restarted()


func _apply_restarted() -> void:
	lost = false
	_restart_left = 0.0
	run_restarted.emit()
