class_name MeleeAttack
extends Node3D
## Colpo corpo a corpo: un pugno davanti a sé che colpisce gli zombie vicini e
## li spinge via. Con la passiva "Mano pesante" il pugno diventa una mazzata:
## lo zombie vola via e, volando, danneggia gli altri zombie e sé stesso
## contro i muri.
##
## Il nodo è anche il pugno in prima persona: sta sotto la camera.
## In rete chi tira il pugno vede subito l'animazione, ma bersagli, danni,
## spinte e muri li calcola l'host, che poi gli rimanda numeri e hitmarker.

## Il pugno ha fatto danno a qualcosa con un HealthComponent.
signal dealt_damage(target: HealthComponent, amount: float, killed: bool)

@export var damage := 10.0
## Distanza massima dal centro del bersaglio, in metri.
@export var reach := 2.4
## Angolo massimo, in gradi, tra dove si guarda e il bersaglio.
@export var arc_degrees := 50.0
## Zombie colpiti al massimo da un pugno (i più vicini).
@export var max_targets := 3
## Secondi tra un pugno e l'altro.
@export var cooldown := 0.7
## Spinta del pugno normale, in m/s (in avanti e verso l'alto).
@export var push_speed := 5.0
@export var push_up := 2.5
## Danno del pugno normale ai blocchi distruttibili: ne stacca uno a colpo.
@export var structure_damage := 45.0
@export var damage_number_scene: PackedScene

@export_group("Mano pesante")
## Passiva del personaggio. Per ora è attiva qui; col sistema dei personaggi
## (Fase 4) la imposterà il personaggio scelto.
@export var heavy_hand := true
@export var heavy_damage := 25.0
## Velocità con cui lo zombie viene scaraventato via, in m/s.
@export var heavy_launch_speed := 14.0
@export var heavy_launch_up := 5.0
## Danno che lo zombie lanciato fa agli altri zombie e a sé stesso contro un muro.
@export var heavy_impact_damage := 20.0
## Danno ai blocchi distruttibili nel raggio del colpo: stacca un pezzo grosso
## come un pugno (più blocchi insieme).
@export var heavy_structure_damage := 100.0
@export var heavy_structure_radius := 0.35

const LAYER_WORLD := 1

var _cooldown_left := 0.0
var _fist_rest := Vector3.ZERO

@onready var _fist: Node3D = $Fist


func _ready() -> void:
	_fist_rest = _fist.position
	_fist.visible = false


func _physics_process(delta: float) -> void:
	_cooldown_left -= delta


func can_attack() -> bool:
	return _cooldown_left <= 0.0


## Tira un pugno da origin (la testa) guardando verso forward.
## attacker è chi colpisce: non viene mai colpito.
func attack(origin: Vector3, forward: Vector3, attacker: Node3D) -> void:
	_cooldown_left = cooldown
	_animate()
	if multiplayer.is_server():
		_strike(origin, forward, attacker)
	else:
		_request_strike.rpc_id(1, origin, forward)


func _strike(origin: Vector3, forward: Vector3, attacker: Node3D) -> void:
	for enemy in _targets(origin, forward):
		_hit(enemy, origin, forward, attacker)
	_hit_structure(origin, forward)


## Sull'host: il pugno di un altro partecipante.
@rpc("any_peer", "call_remote", "reliable")
func _request_strike(origin: Vector3, forward: Vector3) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	var health := HealthComponent.of(owner)
	if health and not health.is_alive():
		return
	# Il pugno deve partire dalla testa del giocatore, non da lontano.
	if origin.distance_to(owner.global_position) > 3.0:
		return
	_strike(origin, forward, owner)


## Se davanti, a portata di pugno, c'è un muro distruttibile, ne stacca un pezzo.
func _hit_structure(origin: Vector3, forward: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward.normalized() * reach, LAYER_WORLD)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var structure := DestructibleBlocks.from_collider(result.collider) if result else null
	if structure == null:
		return
	# Il punto appena dentro la superficie colpita: lì c'è il blocco giusto.
	var inside: Vector3 = result.position - result.normal * 0.1
	if heavy_hand:
		structure.damage_sphere(inside, heavy_structure_radius, heavy_structure_damage, 8.0)
	else:
		structure.damage_point(inside, structure_damage, forward.normalized() * 3.0)


func _targets(origin: Vector3, forward: Vector3) -> Array[Enemy]:
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	var found: Array[Enemy] = []
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		var health := HealthComponent.of(enemy)
		if health == null or not health.is_alive():
			continue
		var to_enemy := enemy.center() - origin
		var flat := Vector3(to_enemy.x, 0.0, to_enemy.z)
		if to_enemy.length() > reach or absf(to_enemy.y) > 1.8:
			continue
		# Quelli attaccati al giocatore contano anche se un po' fuori angolo.
		if flat.length() > 0.6 and rad_to_deg(flat_forward.angle_to(flat)) > arc_degrees:
			continue
		if _blocked(origin, enemy.center()):
			continue
		found.append(enemy)
	found.sort_custom(func(a: Enemy, b: Enemy):
		return origin.distance_squared_to(a.center()) < origin.distance_squared_to(b.center()))
	return found.slice(0, max_targets)


func _hit(enemy: Enemy, origin: Vector3, forward: Vector3, attacker: Node3D) -> void:
	var health := HealthComponent.of(enemy)
	# Il punto colpito è il lato rivolto verso chi tira il pugno (conta per le corazze).
	var toward_attacker := Vector3(origin.x - enemy.center().x, 0.0, origin.z - enemy.center().z)
	var point := enemy.center() + toward_attacker.normalized() * 0.4
	var dealt := health.take_damage(heavy_damage if heavy_hand else damage, attacker, point)
	_report_damage(health, dealt, not health.is_alive(), point)

	var direction := Vector3(enemy.global_position.x - origin.x, 0.0, enemy.global_position.z - origin.z)
	if direction.length() < 0.1:
		direction = Vector3(forward.x, 0.0, forward.z)
	direction = direction.normalized()
	if heavy_hand:
		enemy.apply_knockback(direction * heavy_launch_speed + Vector3.UP * heavy_launch_up,
				heavy_impact_damage, attacker)
	else:
		enemy.apply_knockback(direction * push_speed + Vector3.UP * push_up, 0.0, attacker)


func _blocked(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _animate() -> void:
	_fist.visible = true
	_fist.position = _fist_rest
	var tween := create_tween()
	tween.tween_property(_fist, "position", _fist_rest + Vector3(0.14, 0.12, -0.42), 0.06) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_fist, "position", _fist_rest, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_fist.hide)


## Numero sul bersaglio e hitmarker solo per chi ha tirato il pugno.
func _report_damage(target: HealthComponent, dealt: float, killed: bool, point: Vector3) -> void:
	if is_multiplayer_authority():
		_show_damage(target, dealt, killed, point)
	else:
		_confirm_damage.rpc_id(get_multiplayer_authority(), target.get_path(), dealt, killed, point)


@rpc("any_peer", "call_remote", "reliable")
func _confirm_damage(target_path: NodePath, dealt: float, killed: bool, point: Vector3) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_show_damage(get_node_or_null(target_path) as HealthComponent, dealt, killed, point)


func _show_damage(target: HealthComponent, dealt: float, killed: bool, point: Vector3) -> void:
	_spawn_damage_number(point, dealt, killed)
	dealt_damage.emit(target, dealt, killed)


func _spawn_damage_number(point: Vector3, amount: float, killed: bool) -> void:
	if not damage_number_scene or amount <= 0.0:
		return
	var number: DamageNumber = damage_number_scene.instantiate()
	get_tree().current_scene.add_child(number)
	number.show_value(amount, point, killed)
