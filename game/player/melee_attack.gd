class_name MeleeAttack
extends Node3D
## Corpo a corpo: il pugno (tasto F) e l'arma bianca del terzo slot (tasto 3,
## poi click sinistro). Colpiscono gli zombie vicini davanti a sé e li spingono.
## Con la passiva "Mano pesante" il pugno diventa una mazzata: lo zombie vola
## via e, volando, danneggia gli altri zombie e sé stesso contro i muri.
## Le armi bianche (MeleeWeaponData) hanno i loro numeri: il martellone
## scaraventa come la Mano pesante, la katana taglia molti zombie insieme.
##
## Il nodo è anche il pugno e l'arma bianca in prima persona: sta sotto la camera.
## In rete chi colpisce vede subito l'animazione, ma bersagli, danni, spinte e
## muri li calcola l'host, che poi gli rimanda numeri e hitmarker. Quale arma
## bianca ha ogni giocatore lo decide l'host (host_set_weapon).

## Il colpo ha fatto danno a qualcosa con un HealthComponent.
signal dealt_damage(target: HealthComponent, amount: float, killed: bool)
## L'arma bianca è cambiata (null = nessuna).
signal weapon_changed(weapon: MeleeWeaponData)

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
## Dove si tiene l'arma bianca, sotto la camera.
@export var held_position := Vector3(0.24, -0.3, -0.42)

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

## L'arma bianca del terzo slot (null = nessuna).
var weapon: MeleeWeaponData
## Terzo slot in mano (solo per chi controlla il giocatore).
var active := false

var _cooldown_left := 0.0
var _fist_rest := Vector3.ZERO
var _held := Node3D.new()
var _swing_tween: Tween

@onready var _fist: Node3D = $Fist


func _ready() -> void:
	_fist_rest = _fist.position
	_fist.visible = false
	# Il braccio sta sulla camera: la sua ombra cadrebbe nel mondo dal punto sbagliato.
	for node in _fist.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_held.name = "Held"
	_held.position = held_position
	_held.visible = false
	add_child(_held)
	if not multiplayer.is_server():
		# Chi entra a partita iniziata chiede all'host le armi bianche di tutti.
		_request_weapon.rpc_id(1)


func _physics_process(delta: float) -> void:
	_cooldown_left -= delta


func can_attack() -> bool:
	return _cooldown_left <= 0.0


## Mette in mano (o via) l'arma bianca. Senza arma bianca non si attiva.
func set_active(on: bool) -> void:
	active = on and weapon != null
	_held.visible = active
	if active:
		_rest_pose()


## Tira un pugno da origin (la testa) guardando verso forward.
## attacker è chi colpisce: non viene mai colpito.
func attack(origin: Vector3, forward: Vector3, attacker: Node3D) -> void:
	_cooldown_left = cooldown
	_animate()
	if multiplayer.is_server():
		_strike(origin, forward, attacker, _punch_data())
	else:
		_request_strike.rpc_id(1, origin, forward, false)


## Colpo con l'arma bianca in mano.
func swing(origin: Vector3, forward: Vector3, attacker: Node3D) -> void:
	if weapon == null:
		return
	_cooldown_left = weapon.cooldown
	_animate_swing()
	if multiplayer.is_server():
		_strike(origin, forward, attacker, weapon)
	else:
		_request_strike.rpc_id(1, origin, forward, true)


## Sull'host: il giocatore ha l'arma bianca id ("" = nessuna). Restituisce la
## spec di quella che aveva (per lasciarla a terra), o [] se non ne aveva.
func host_set_weapon(id: String) -> Array:
	var old := MeleeCatalog.spec_for(weapon.id) if weapon else []
	_apply_weapon(id)
	if NetSession.is_online():
		_receive_weapon.rpc(id)
	return old


@rpc("any_peer", "call_remote", "reliable")
func _receive_weapon(id: String) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_apply_weapon(id)


@rpc("any_peer", "call_remote", "reliable")
func _request_weapon() -> void:
	if multiplayer.is_server():
		_receive_weapon.rpc_id(multiplayer.get_remote_sender_id(), weapon.id if weapon else "")


func _apply_weapon(id: String) -> void:
	weapon = MeleeCatalog.data(id)
	for child in _held.get_children():
		child.queue_free()
	if weapon:
		_held.add_child(MeleeCatalog.build_model(weapon))
	var was_active := active
	set_active(was_active)
	weapon_changed.emit(weapon)


## Il pugno, con o senza Mano pesante, come se fosse un'arma bianca.
func _punch_data() -> MeleeWeaponData:
	var punch := MeleeWeaponData.new()
	punch.reach = reach
	punch.arc_degrees = arc_degrees
	punch.max_targets = max_targets
	if heavy_hand:
		punch.damage = heavy_damage
		punch.push_speed = heavy_launch_speed
		punch.push_up = heavy_launch_up
		punch.launch = true
		punch.launch_impact_damage = heavy_impact_damage
		punch.structure_damage = heavy_structure_damage
		punch.structure_radius = heavy_structure_radius
	else:
		punch.damage = damage
		punch.push_speed = push_speed
		punch.push_up = push_up
		punch.structure_damage = structure_damage
	return punch


func _strike(origin: Vector3, forward: Vector3, attacker: Node3D, hit: MeleeWeaponData) -> void:
	for enemy in _targets(origin, forward, hit):
		_hit(enemy, origin, forward, attacker, hit)
	_hit_structure(origin, forward, hit)
	if hit.is_hammer:
		_hit_shell_carriers(origin, forward, attacker, hit)


## Martellata su un compagno con il proiettile da carro armato in spalla: il
## proiettile parte a razzo (FpsController.host_fire_shell). Al compagno
## nessun danno.
func _hit_shell_carriers(origin: Vector3, forward: Vector3, attacker: Node3D, hit: MeleeWeaponData) -> void:
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	for player in get_tree().get_nodes_in_group("players"):
		if player == attacker or not player is FpsController or not player.carrying_shell:
			continue
		var chest: Vector3 = player.global_position + Vector3.UP * 1.3
		var to_player := chest - origin
		var flat := Vector3(to_player.x, 0.0, to_player.z)
		if to_player.length() > hit.reach + 0.4:
			continue
		if flat.length() > 0.6 and rad_to_deg(flat_forward.angle_to(flat)) > hit.arc_degrees:
			continue
		if _blocked(origin, chest):
			continue
		player.host_fire_shell(attacker)


## Sull'host: il colpo di un altro partecipante (pugno o arma bianca, quella
## che l'host sa che ha).
@rpc("any_peer", "call_remote", "reliable")
func _request_strike(origin: Vector3, forward: Vector3, with_weapon: bool) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	var health := HealthComponent.of(owner)
	if health and not health.is_alive():
		return
	# Il colpo deve partire dalla testa del giocatore, non da lontano.
	if origin.distance_to(owner.global_position) > 3.0:
		return
	if with_weapon and weapon == null:
		return
	_strike(origin, forward, owner, weapon if with_weapon else _punch_data())


## Se davanti, a portata, c'è un muro distruttibile, ne stacca un pezzo.
func _hit_structure(origin: Vector3, forward: Vector3, hit: MeleeWeaponData) -> void:
	if hit.structure_damage <= 0.0:
		return
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward.normalized() * hit.reach, LAYER_WORLD)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var structure := DestructibleBlocks.from_collider(result.collider) if result else null
	if structure == null:
		return
	# Il punto appena dentro la superficie colpita: lì c'è il blocco giusto.
	var inside: Vector3 = result.position - result.normal * 0.1
	if hit.structure_radius > 0.0:
		structure.damage_sphere(inside, hit.structure_radius, hit.structure_damage, 8.0)
	else:
		structure.damage_point(inside, hit.structure_damage, forward.normalized() * 3.0)


func _targets(origin: Vector3, forward: Vector3, hit: MeleeWeaponData) -> Array[Enemy]:
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	var found: Array[Enemy] = []
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		var health := HealthComponent.of(enemy)
		if health == null or not health.is_alive():
			continue
		var to_enemy := enemy.center() - origin
		var flat := Vector3(to_enemy.x, 0.0, to_enemy.z)
		if to_enemy.length() > hit.reach or absf(to_enemy.y) > 1.8:
			continue
		# Quelli attaccati al giocatore contano anche se un po' fuori angolo.
		if flat.length() > 0.6 and rad_to_deg(flat_forward.angle_to(flat)) > hit.arc_degrees:
			continue
		if _blocked(origin, enemy.center()):
			continue
		found.append(enemy)
	found.sort_custom(func(a: Enemy, b: Enemy):
		return origin.distance_squared_to(a.center()) < origin.distance_squared_to(b.center()))
	return found.slice(0, hit.max_targets)


func _hit(enemy: Enemy, origin: Vector3, forward: Vector3, attacker: Node3D, hit: MeleeWeaponData = null) -> void:
	if hit == null:
		hit = _punch_data()
	var health := HealthComponent.of(enemy)
	# Il punto colpito è il lato rivolto verso chi colpisce (conta per le corazze).
	var toward_attacker := Vector3(origin.x - enemy.center().x, 0.0, origin.z - enemy.center().z)
	var point := enemy.center() + toward_attacker.normalized() * 0.4
	var amount := hit.damage
	if attacker.has_method("melee_multiplier"):
		amount *= attacker.melee_multiplier()
	var dealt := health.take_damage(amount, attacker, point)
	_report_damage(health, dealt, not health.is_alive(), point)

	var direction := Vector3(enemy.global_position.x - origin.x, 0.0, enemy.global_position.z - origin.z)
	if direction.length() < 0.1:
		direction = Vector3(forward.x, 0.0, forward.z)
	direction = direction.normalized()
	enemy.apply_knockback(direction * hit.push_speed + Vector3.UP * hit.push_up,
			hit.launch_impact_damage if hit.launch else 0.0, attacker)


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


## Posa a riposo dell'arma bianca: i martelli dritti e un po' in avanti, la
## katana inclinata verso il centro.
func _rest_pose() -> void:
	if _swing_tween:
		_swing_tween.kill()
	_held.position = held_position
	_held.rotation = Vector3(-0.35, 0.0, 0.0) if weapon == null or weapon.swing == MeleeWeaponData.Swing.OVERHEAD \
			else Vector3(-0.7, 0.0, 0.5)
	# Le armi lunghe (martellone) più in basso e più inclinate: non coprono la visuale.
	if weapon and weapon.handle_length > 0.6:
		_held.position += Vector3(0.06, -0.28, 0.05)
		_held.rotation = Vector3(-0.75, 0.0, -0.35)


## Colpo dell'arma bianca: dall'alto in basso (martelli) o di taglio (katana),
## sempre dentro il tempo tra un colpo e l'altro.
func _animate_swing() -> void:
	if weapon == null:
		return
	_rest_pose()
	_held.visible = active
	var t := minf(weapon.cooldown, 0.9)
	_swing_tween = create_tween()
	if weapon.swing == MeleeWeaponData.Swing.OVERHEAD:
		_swing_tween.tween_property(_held, "rotation:x", 0.6, t * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_swing_tween.tween_property(_held, "rotation:x", -1.5, t * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_swing_tween.tween_property(_held, "rotation:x", -0.35, t * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_swing_tween.tween_property(_held, "rotation", Vector3(-1.4, 0.0, 1.4), t * 0.25)
		_swing_tween.tween_property(_held, "rotation", Vector3(-1.4, 0.0, -1.2), t * 0.25) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_swing_tween.tween_property(_held, "rotation", Vector3(-0.7, 0.0, 0.5), t * 0.4)


## Numero sul bersaglio e hitmarker solo per chi ha colpito.
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
