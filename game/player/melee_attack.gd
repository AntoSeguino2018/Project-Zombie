class_name MeleeAttack
extends Node3D
## Colpo corpo a corpo: un pugno davanti a sé che colpisce gli zombie vicini e
## li spinge via. Con la passiva "Mano pesante" il pugno diventa una mazzata:
## lo zombie vola via e, volando, danneggia gli altri zombie e sé stesso
## contro i muri.
##
## Il nodo è anche il pugno in prima persona: sta sotto la camera.
## Predisposto per la rete: attack() riceve origine e direzione come parametri,
## così in futuro potrà essere validato dall'host.

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
	for enemy in _targets(origin, forward):
		_hit(enemy, origin, forward, attacker)


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
	var killed := not health.is_alive()
	_spawn_damage_number(point, dealt, killed)
	dealt_damage.emit(health, dealt, killed)

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


func _spawn_damage_number(point: Vector3, amount: float, killed: bool) -> void:
	if not damage_number_scene or amount <= 0.0:
		return
	var number: DamageNumber = damage_number_scene.instantiate()
	get_tree().current_scene.add_child(number)
	number.show_value(amount, point, killed)
