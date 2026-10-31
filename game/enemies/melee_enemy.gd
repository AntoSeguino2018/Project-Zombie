class_name MeleeEnemy
extends CharacterBody3D
## Nemico da mischia: insegue il giocatore vivo più vicino aggirando gli
## ostacoli e, quando è abbastanza vicino, prepara un colpo e lo sferra.
##
## Prima del colpo alza le braccia per un attimo: è il momento per allontanarsi
## o spostarsi di lato. Predisposto per la rete: pensa e si muove solo dove ha
## l'autorità (l'host); i client vedranno la sua posizione sincronizzata.

enum State { CHASE, ATTACK, DEAD }

@export_group("Movimento")
## Velocità di corsa, in m/s. Più lenta del giocatore, così lo si può distanziare.
@export var move_speed := 4.5
## Rapidità con cui si gira verso dove sta andando.
@export var turn_speed := 8.0
## Moltiplica la gravità del progetto, come per il giocatore.
@export var gravity_multiplier := 1.6
## Secondi tra un ricalcolo del percorso e il successivo.
@export var repath_interval := 0.2
## Quando viene colpito rallenta a questa frazione della velocità...
@export_range(0.0, 1.0) var hit_slow_factor := 0.35
## ...per questi secondi.
@export var hit_slow_time := 0.2

@export_group("Attacco")
@export var attack_damage := 15.0
## Distanza orizzontale (tra i centri) da cui inizia a preparare il colpo.
@export var attack_range := 1.7
## Il colpo va a segno solo se il bersaglio è ancora entro questa distanza...
@export var attack_reach := 2.3
## ...e davanti a lui, entro questo angolo (in gradi) da dove guarda.
@export var attack_arc_degrees := 70.0
## Secondi di preparazione prima del colpo.
@export var attack_windup := 0.5
## Secondi fermo dopo il colpo, prima di tornare a inseguire.
@export var attack_recovery := 0.6

@export_group("Morte")
## Secondi in cui il corpo resta a terra prima di sparire.
@export var corpse_time := 1.0

var _state := State.CHASE
var _state_time := 0.0
var _target: Node3D
var _struck := false
var _repath_left := 0.0
var _slow_left := 0.0
var _attack_tween: Tween
var _flash := StandardMaterial3D.new()

@onready var _health: HealthComponent = $Health
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual
@onready var _arms: Node3D = $Visual/Arms
@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	# Stesso lampo bianco dei manichini quando viene colpito.
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	for part: MeshInstance3D in _visual.find_children("*", "MeshInstance3D"):
		part.material_overlay = _flash

	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	if not is_multiplayer_authority():
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * gravity_multiplier * delta
	_slow_left -= delta
	_state_time += delta
	match _state:
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_attack(delta)
	move_and_slide()


func is_attacking() -> bool:
	return _state == State.ATTACK


func _chase(delta: float) -> void:
	_target = _find_target()
	if _target == null:
		_stop()
		return
	var to_target := _flat(_target.global_position - global_position)
	if to_target.length() <= attack_range and _height_to(_target) < 1.5:
		_start_attack()
		return
	var direction := _path_direction(delta)
	var speed := move_speed * (hit_slow_factor if _slow_left > 0.0 else 1.0)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_turn_towards(direction if not direction.is_zero_approx() else to_target, turn_speed, delta)


## Direzione orizzontale verso il prossimo punto del percorso (zero se non c'è).
func _path_direction(delta: float) -> Vector3:
	# Prima della prima sincronizzazione la mappa non si può interrogare.
	if NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) == 0:
		return Vector3.ZERO
	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = repath_interval
		_agent.target_position = _target.global_position
	return _flat(_agent.get_next_path_position() - global_position).normalized()


func _start_attack() -> void:
	_set_state(State.ATTACK)
	_struck = false
	_stop()
	# Braccia su durante la preparazione, giù di colpo, poi a riposo.
	_attack_tween = _physics_tween()
	_attack_tween.tween_property(_arms, "rotation:x", deg_to_rad(75.0), attack_windup) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_attack_tween.tween_property(_arms, "rotation:x", deg_to_rad(-25.0), 0.08)
	_attack_tween.tween_property(_arms, "rotation:x", 0.0, maxf(attack_recovery - 0.08, 0.01))


func _attack(delta: float) -> void:
	_stop()
	if not _struck:
		# Durante la preparazione segue il bersaglio, ma lentamente.
		if is_instance_valid(_target):
			_turn_towards(_flat(_target.global_position - global_position), turn_speed * 0.3, delta)
		if _state_time >= attack_windup:
			_struck = true
			_strike()
	elif _state_time >= attack_windup + attack_recovery:
		_set_state(State.CHASE)


func _strike() -> void:
	if not is_instance_valid(_target):
		return
	var health := HealthComponent.of(_target)
	if health == null or not health.is_alive():
		return
	var to_target := _flat(_target.global_position - global_position)
	var in_arc := to_target.length() < 0.01 \
			or rad_to_deg((-global_basis.z).angle_to(to_target)) <= attack_arc_degrees
	if to_target.length() <= attack_reach and _height_to(_target) < 1.5 and in_arc:
		health.take_damage(attack_damage, self, _target.global_position + Vector3.UP)


## Il giocatore vivo più vicino, o null se non ce ne sono.
func _find_target() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for player: Node3D in get_tree().get_nodes_in_group("players"):
		var health := HealthComponent.of(player)
		if health == null or not health.is_alive():
			continue
		var distance := global_position.distance_squared_to(player.global_position)
		if distance < best_distance:
			best = player
			best_distance = distance
	return best


func _on_damaged(_amount: float, _source: Node, _hit_position: Vector3) -> void:
	_slow_left = hit_slow_time
	_flash.albedo_color.a = 0.7
	create_tween().tween_property(_flash, "albedo_color:a", 0.0, 0.12)


func _on_died(_source: Node) -> void:
	_set_state(State.DEAD)
	if _attack_tween:
		_attack_tween.kill()
	set_physics_process(false)
	_shape.set_deferred("disabled", true)
	# Cade all'indietro, resta a terra un attimo e poi sparisce.
	var tween := _physics_tween()
	tween.tween_property(_visual, "rotation:x", deg_to_rad(90.0), 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_visual, "position:y", 0.2, 0.35)
	tween.tween_interval(corpse_time)
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.01, 0.25)
	tween.tween_callback(queue_free)


func _set_state(state: State) -> void:
	_state = state
	_state_time = 0.0


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _turn_towards(direction: Vector3, speed: float, delta: float) -> void:
	if direction.is_zero_approx():
		return
	var yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-speed * delta))


func _height_to(node: Node3D) -> float:
	return absf(node.global_position.y - global_position.y)


func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)


## Le animazioni del corpo girano al passo della fisica, così l'interpolazione
## le rende fluide insieme al movimento.
func _physics_tween() -> Tween:
	return create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
