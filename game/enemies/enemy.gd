class_name Enemy
extends CharacterBody3D
## Base comune di tutti gli zombie: scelta del bersaglio, inseguimento con la
## navigazione, lampo quando viene colpito, spinte, stordimento e morte.
##
## Ogni tipo di zombie estende questa classe e decide come attaccare
## (_wants_attack, _begin_attack, _update_attack, _interrupt_attack).
## In rete pensa e si muove solo sull'host, che manda agli altri posizione,
## direzione e posa del corpo (attacchi, volo, stordimento, caduta da morto):
## lì lo zombie insegue morbidamente quello stato. Vita, lampi e morte
## arrivano invece da HealthComponent.

enum State { CHASE, ATTACK, STUNNED, LAUNCHED, DEAD }

const LAYER_WORLD := 1
const LAYER_PLAYERS := 2

@export_group("Movimento")
## Velocità di corsa, in m/s.
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

@export_group("Spinte")
## Se falso le spinte non lo fanno volare: resta solo stordito (es. il Bestione).
@export var can_be_launched := true
## Secondi di stordimento quando una spinta non riesce a farlo volare.
@export var unlaunchable_stun := 0.8
## Secondi a terra stordito dopo essere atterrato da una spinta.
@export var landing_stun := 0.5
## Velocità minima, in m/s, per farsi male sbattendo contro un muro in volo.
@export var wall_hit_min_speed := 6.0
## Velocità minima, in m/s, per sfondare un muro distruttibile sbattendoci contro.
@export var wall_break_speed := 9.0
## Danno ai blocchi del muro quando lo sfonda.
@export var wall_break_damage := 80.0
## Per mostrare i danni che non arrivano dalle armi (urti in volo, muri).
@export var damage_number_scene: PackedScene

@export_group("Morte")
## Secondi in cui il corpo resta a terra prima di sparire.
@export var corpse_time := 1.0
## Soldi che riceve chi lo uccide.
@export var bounty := 10
## Probabilità che da morto lasci a terra un oggetto passivo.
@export_range(0.0, 1.0) var item_drop_chance := 0.02

@export_group("Rete")
## Volte al secondo in cui l'host manda lo stato dello zombie.
@export var sync_rate := 30.0
## Rapidità con cui uno zombie remoto raggiunge l'ultima posizione ricevuta.
@export var remote_smoothing := 15.0
## Rapidità per la posa: più alta, perché i segnali d'attacco (braccia alzate,
## accucciata) devono arrivare interi e in tempo per schivare.
@export var pose_smoothing := 40.0

## Stato condiviso in rete: lo scrive l'host, gli altri lo inseguono.
var sync_position := Vector3.ZERO
var sync_yaw := 0.0
## Posa del corpo (Visual) e angolo delle braccia, se ci sono.
var sync_pose := Transform3D.IDENTITY
var sync_arms := 0.0

var _state := State.CHASE
var _state_time := 0.0
var _target: Node3D
var _repath_left := 0.0
var _slow_left := 0.0
var _stun_duration := 0.0
## Danno che fa in volo a chi colpisce e a sé stesso contro un muro (0 = nessuno).
var _impact_damage := 0.0
var _impact_source: Node
var _impact_hits: Array[Node] = []
var _hit_wall := false
var _flash := StandardMaterial3D.new()
## Anti-incastro: da quanto non avanza, e per quanto scivola ancora di lato.
var _stuck_time := 0.0
var _unstick_left := 0.0
var _unstick_direction := Vector3.ZERO

@onready var _health: HealthComponent = $Health
@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: Node3D = $Visual
@onready var _pose_arms: Node3D = get_node_or_null("Visual/Arms")
@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("enemies")
	# Lampo bianco quando viene colpito, come i manichini.
	_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	for part: MeshInstance3D in _visual.find_children("*", "MeshInstance3D"):
		part.material_overlay = _flash

	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_publish_state()
	_add_net_sync()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		_follow_host_state(delta)
		return
	if not is_on_floor():
		velocity.y -= _gravity * gravity_multiplier * delta
	_slow_left -= delta
	_state_time += delta
	match _state:
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_update_attack(delta)
		State.STUNNED:
			_update_stunned(delta)
		State.DEAD:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
				velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	var velocity_before_move := velocity
	move_and_slide()
	_after_move(velocity_before_move)
	_publish_state()


## Scrive lo stato che l'host manda agli altri partecipanti.
func _publish_state() -> void:
	sync_position = global_position
	sync_yaw = rotation.y
	sync_pose = _visual.transform
	sync_arms = _pose_arms.rotation.x if _pose_arms else 0.0


func _follow_host_state(delta: float) -> void:
	var weight := 1.0 - exp(-remote_smoothing * delta)
	if global_position.distance_to(sync_position) > 4.0:
		global_position = sync_position
		reset_physics_interpolation()
	else:
		global_position = global_position.lerp(sync_position, weight)
	rotation.y = lerp_angle(rotation.y, sync_yaw, weight)
	var pose_weight := 1.0 - exp(-pose_smoothing * delta)
	_visual.transform = _visual.transform.interpolate_with(sync_pose, pose_weight)
	if _pose_arms:
		_pose_arms.rotation.x = lerpf(_pose_arms.rotation.x, sync_arms, pose_weight)


## Sincronizzazione di rete, uguale per tutti i tipi di zombie: posizione e
## direzione sempre, la posa solo quando cambia.
func _add_net_sync() -> void:
	var config := SceneReplicationConfig.new()
	for property in [&"sync_position", &"sync_yaw", &"sync_pose", &"sync_arms"]:
		var path := NodePath(".:" + property)
		config.add_property(path)
		config.property_set_spawn(path, true)
		var changes_rarely: bool = property == &"sync_pose" or property == &"sync_arms"
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
				if changes_rarely else SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var net_sync := MultiplayerSynchronizer.new()
	net_sync.name = "NetSync"
	net_sync.replication_config = config
	net_sync.replication_interval = 1.0 / sync_rate
	net_sync.delta_interval = 1.0 / sync_rate
	add_child(net_sync)


func is_attacking() -> bool:
	return _state == State.ATTACK


func is_stunned() -> bool:
	return _state == State.STUNNED


func is_launched() -> bool:
	return _state == State.LAUNCHED


## Centro del corpo: dove mirano gli attacchi corpo a corpo.
func center() -> Vector3:
	return _shape.global_position


## Spinge via lo zombie con questa velocità iniziale. Se non può volare resta
## solo stordito. impact_damage è il danno che farà in volo a chi colpisce
## (e a sé stesso se sbatte contro un muro); source è chi l'ha spinto.
func apply_knockback(impulse: Vector3, impact_damage := 0.0, source: Node = null) -> void:
	if _state == State.DEAD:
		# Anche il corpo vola via: non fa danni, ma è soddisfacente.
		velocity = impulse
		return
	if not can_be_launched:
		stun(unlaunchable_stun)
		return
	_leave_attack()
	_set_state(State.LAUNCHED)
	velocity = impulse
	_impact_damage = impact_damage
	_impact_source = source
	_impact_hits.clear()
	_hit_wall = false


## Lo zombie resta fermo e intontito per questi secondi.
func stun(seconds: float) -> void:
	if _state == State.DEAD:
		return
	_leave_attack()
	_set_state(State.STUNNED)
	_stun_duration = seconds
	_stop()


# --- Da ridefinire nei vari tipi di zombie ---------------------------------

## Vero se, da questa distanza dal bersaglio (orizzontale), deve iniziare un attacco.
func _wants_attack(_to_target: Vector3) -> bool:
	return false


func _begin_attack() -> void:
	pass


## Chiamata a ogni tick durante l'attacco: alla fine deve chiamare _end_attack().
func _update_attack(_delta: float) -> void:
	_end_attack()


## L'attacco viene interrotto (spinta, stordimento, morte): rimettere a posto la posa.
func _interrupt_attack() -> void:
	pass


## Direzione in cui correre inseguendo il bersaglio.
func _chase_direction(delta: float) -> Vector3:
	return _path_direction(delta)


## Dopo il movimento del tick, con la velocità che aveva prima di muoversi.
func _after_move(velocity_before_move: Vector3) -> void:
	if _state == State.LAUNCHED:
		_update_launched(velocity_before_move)


# --- Comportamento comune --------------------------------------------------

func _chase(delta: float) -> void:
	_target = _find_target()
	if _target == null:
		_stop()
		return
	var to_target := _flat(_target.global_position - global_position)
	if _wants_attack(to_target):
		_set_state(State.ATTACK)
		_begin_attack()
		return
	var direction := _unstick(_chase_direction(delta), delta)
	var speed := move_speed * (hit_slow_factor if _slow_left > 0.0 else 1.0)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_turn_towards(direction if not direction.is_zero_approx() else to_target, turn_speed, delta)


func _end_attack() -> void:
	_set_state(State.CHASE)


func _leave_attack() -> void:
	if _state == State.ATTACK:
		_interrupt_attack()


## Se inseguendo resta fermo per mezzo secondo (per esempio contro lo spigolo
## di una porta), scivola di lato lungo l'ostacolo per un attimo e poi riprende
## il percorso. Restituisce la direzione da seguire in questo tick.
func _unstick(direction: Vector3, delta: float) -> Vector3:
	if _unstick_left > 0.0:
		_unstick_left -= delta
		return _unstick_direction
	var moving := _flat(get_real_velocity()).length()
	if direction.is_zero_approx() or _slow_left > 0.0 or moving > move_speed * 0.25:
		_stuck_time = 0.0
		return direction
	_stuck_time += delta
	if _stuck_time < 0.5:
		return direction
	_stuck_time = 0.0
	_unstick_left = 0.6
	var side := direction.cross(Vector3.UP).normalized()
	var sign := 1.0 if randf() < 0.5 else -1.0
	if get_slide_collision_count() > 0:
		# Verso il lato in cui la direzione voluta scivola lungo l'ostacolo.
		var normal := _flat(get_slide_collision(0).get_normal())
		var slid := direction.slide(normal) if not normal.is_zero_approx() else Vector3.ZERO
		if slid.length() > 0.05:
			sign = signf(side.dot(slid))
		_unstick_direction = (side * sign + normal * 0.5).normalized()
	else:
		_unstick_direction = side * sign
	return _unstick_direction


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


func _update_stunned(delta: float) -> void:
	_stop()
	# Barcolla all'indietro e ondeggia, sempre meno man mano che si riprende.
	var left := clampf(1.0 - _state_time / maxf(_stun_duration, 0.01), 0.0, 1.0)
	_visual.rotation.x = move_toward(_visual.rotation.x, deg_to_rad(15.0) * left, 6.0 * delta)
	_visual.rotation.z = sin(_state_time * 14.0) * 0.15 * left
	if _state_time >= _stun_duration:
		_reset_pose()
		_set_state(State.CHASE)


func _update_launched(velocity_before_move: Vector3) -> void:
	# In volo si ribalta all'indietro.
	_visual.rotation.x = minf(_visual.rotation.x + 0.25, deg_to_rad(80.0))
	var speed := _flat(velocity_before_move).length()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var other := collision.get_collider()
		if other is Enemy:
			if _impact_damage > 0.0 and other not in _impact_hits:
				# Lo zombie lanciato diventa un proiettile: colpisce e spinge gli altri.
				_impact_hits.append(other)
				other._take_impact_damage(_impact_damage, _impact_source, collision.get_position())
				other.apply_knockback(_flat(velocity_before_move) * 0.6 + Vector3.UP * 3.0, 0.0, _impact_source)
		elif collision.get_normal().y < 0.5 and not other is FpsController \
				and speed >= wall_hit_min_speed and not _hit_wall:
			_hit_wall = true
			var structure := DestructibleBlocks.from_collider(other)
			if structure and speed >= wall_break_speed:
				# Scaraventato abbastanza forte, sfonda il muro.
				structure.damage_sphere(collision.get_position(), 0.6, wall_break_damage, speed * 0.5)
			if _impact_damage > 0.0:
				_take_impact_damage(_impact_damage, _impact_source, collision.get_position())
			# Rimbalza un po' all'indietro.
			var bounce := _flat(velocity_before_move).bounce(collision.get_normal()) * 0.3
			velocity.x = bounce.x
			velocity.z = bounce.z
	if _state == State.LAUNCHED and is_on_floor() and _state_time > 0.1:
		stun(landing_stun)


func _take_impact_damage(amount: float, source: Node, at: Vector3) -> void:
	var dealt := _health.take_damage(amount, source, at)
	if dealt <= 0.0:
		return
	# Il numero lo vede chi ha lanciato lo zombie, come per i suoi colpi.
	var killed := not _health.is_alive()
	if source and not source.is_multiplayer_authority():
		_show_damage_number.rpc_id(source.get_multiplayer_authority(), dealt, at, killed)
	else:
		_show_damage_number(dealt, at, killed)


@rpc("authority", "call_remote", "reliable")
func _show_damage_number(amount: float, at: Vector3, killed: bool) -> void:
	if damage_number_scene:
		var number: DamageNumber = damage_number_scene.instantiate()
		get_tree().current_scene.add_child(number)
		number.show_value(amount, at, killed)


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


## Vero se dal petto si vede il bersaglio senza muri in mezzo.
func _can_see(target: Node3D, eye_height := 1.4) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * eye_height, target.global_position + Vector3.UP * 1.0,
			LAYER_WORLD | LAYER_PLAYERS, [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == target


func _on_damaged(_amount: float, _source: Node, _hit_position: Vector3) -> void:
	_slow_left = hit_slow_time
	_flash.albedo_color.a = 0.7
	create_tween().tween_property(_flash, "albedo_color:a", 0.0, 0.12)


## Arriva su tutti i partecipanti: ognuno conta le sue uccisioni.
func _on_died(source: Node) -> void:
	CombatEvents.bus.enemy_killed.emit(self, source)
	# Il corpo non blocca più nessuno e non si può colpire, ma cade ancora a terra.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", LAYER_WORLD)
	# La caduta e la sparizione le decide l'host (sugli altri arriva la posa,
	# poi lo zombie viene tolto).
	if not is_multiplayer_authority():
		return
	_leave_attack()
	_set_state(State.DEAD)
	# Cade all'indietro, resta a terra un attimo e poi sparisce.
	var tween := _physics_tween()
	tween.tween_property(_visual, "rotation", Vector3(deg_to_rad(90.0), 0.0, 0.0), 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_visual, "position:y", 0.2, 0.35)
	tween.tween_interval(corpse_time)
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.01, 0.25)
	tween.tween_callback(queue_free)


func _set_state(state: State) -> void:
	_state = state
	_state_time = 0.0


func _reset_pose() -> void:
	_physics_tween().tween_property(_visual, "rotation", Vector3.ZERO, 0.15)


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
