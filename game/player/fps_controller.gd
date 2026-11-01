class_name FpsController
extends CharacterBody3D
## Controller in prima persona: movimento, salto, sprint e visuale col mouse.
##
## In rete il nodo si chiama come l'id del partecipante che lo controlla: lui
## ne ha l'autorità (input, camera, movimento) e invia il suo stato con
## MultiplayerSynchronizer; sugli altri il giocatore insegue quello stato in
## modo morbido. Da soli il giocatore è sempre quello locale.
## Guardando un oggetto interagibile (casse, armi a terra) l'HUD mostra cosa
## si può fare con E; l'azione la esegue l'host, che controlla la distanza.
## Vita, morte, caduta fuori dal livello e rinascita le decide l'host; chi
## controlla il giocatore si limita a mostrarle (HUD, visuale a terra) e gli
## altri vedono il corpo cadere a terra.
## La camera è top_level e segue la testa interpolata, così il movimento resta
## fluido anche su monitor a più di 60 Hz, mentre la rotazione del mouse è immediata.

const LAYER_WORLD := 1
const LAYER_INTERACTABLE := 16

@export_group("Movimento")
## Velocità camminando, in m/s.
@export var walk_speed := 7.0
## Velocità in sprint, in m/s. Lo sprint vale solo andando in avanti.
@export var sprint_speed := 11.0
## Velocità verticale all'inizio del salto, in m/s.
@export var jump_velocity := 6.5
## Moltiplica la gravità del progetto: più alto = salto meno "lunare".
@export var gravity_multiplier := 1.6
## Rapidità con cui si esaurisce una spinta subita (a terra e in aria).
@export var push_friction := Vector2(6.0, 1.5)

@export_group("Visuale")
## Radianti di rotazione per pixel di movimento del mouse.
@export var mouse_sensitivity := 0.0025
## Quanto si può guardare in alto o in basso, in gradi.
@export_range(10.0, 89.0) var max_pitch_degrees := 89.0

@export_group("Interazione")
## Distanza massima da cui si usano casse e armi a terra, in metri.
@export var interact_distance := 2.6

@export_group("Rete")
## Rapidità con cui un giocatore remoto raggiunge l'ultima posizione ricevuta.
@export var remote_smoothing := 18.0
## Colori dei giocatori, nell'ordine di arrivo nella partita.
@export var player_colors: Array[Color] = [Color(0.95, 0.55, 0.2), Color(0.3, 0.7, 0.95),
		Color(0.55, 0.85, 0.35), Color(0.9, 0.4, 0.75)]

@export_group("Vita")
## Secondi da morto prima di rinascere al punto di partenza.
@export var respawn_time := 3.0
## Sotto questa quota si muore: si è caduti fuori dal livello.
@export var kill_height := -30.0
## Di quanto scende la visuale da morti, in metri.
@export var death_camera_drop := 1.2

## Numero del giocatore nella partita (1-4): decide colore e nome.
var player_number := 1
## Stato condiviso in rete: lo scrive chi controlla il giocatore, gli altri lo inseguono.
var sync_position := Vector3.ZERO
var sync_yaw := 0.0
var sync_pitch := 0.0

var _yaw := 0.0
var _pitch := 0.0
## Spostamento della visuale dovuto al rinculo (x = alto/basso, y = lati), in
## radianti. Si somma alla mira e torna a zero da solo.
var _recoil := Vector2.ZERO
## Spinta ricevuta (es. carica del Bestione): si somma al movimento e si esaurisce.
var _push := Vector3.ZERO
var _spawn_transform: Transform3D
var _respawn_left := 0.0
## Dopo la rinascita l'host aspetta un po' prima di controllare le cadute: la
## nuova posizione di un giocatore remoto arriva con qualche istante di ritardo.
var _fall_check_delay := 0.0
## Da 0 (vivo) a 1 (visuale a terra): fa crollare la camera quando si muore.
var _death_blend := 0.0
## Posa da vivo del corpo, per rialzarlo alla rinascita.
var _body_rest: Transform3D
var _visor_rest: Transform3D
var _name_tag_height := 0.0
var _body_tween: Tween
## Oggetto interagibile guardato in questo momento (null = nessuno).
var _interact_target: Node
## Statistiche della vita in corso, per l'HUD e la schermata di morte.
var _kills := 0
var _alive_time := 0.0
var _best_time := 0.0

@onready var _head: Marker3D = $Head
@onready var _camera: Camera3D = $Camera3D
@onready var _body_mesh: MeshInstance3D = $BodyMesh
@onready var _visor: MeshInstance3D = $Visor
@onready var _name_tag: Label3D = $NameTag
@onready var _weapon: Weapon = $Camera3D/Weapon
@onready var _melee: MeleeAttack = $Camera3D/Melee
@onready var _health: HealthComponent = $Health
@onready var _hud: PlayerHud = $Hud
@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _enter_tree() -> void:
	# In rete il nome è l'id del partecipante che controlla questo giocatore.
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())


func _ready() -> void:
	# I nemici cercano i bersagli in questo gruppo.
	add_to_group("players")
	_yaw = rotation.y
	_spawn_transform = global_transform
	sync_position = global_position
	sync_yaw = _yaw
	_body_rest = _body_mesh.transform
	_visor_rest = _visor.transform
	_name_tag_height = _name_tag.position.y
	_apply_player_color()
	_name_tag.text = "Giocatore %d" % player_number
	_health.died.connect(_on_died)
	if not is_multiplayer_authority():
		_weapon.visible = false
		_hud.visible = false
		set_process(false)
		set_process_unhandled_input(false)
		return
	# Il proprio corpo non si vede, ma continua a proiettare l'ombra.
	_body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_visor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_name_tag.visible = false
	_weapon.dealt_damage.connect(func(_target, _amount, killed): _hud.crosshair.show_hit(killed))
	_melee.dealt_damage.connect(func(_target, _amount, killed): _hud.crosshair.show_hit(killed))
	_hud.bind_weapon(_weapon)
	CombatEvents.bus.enemy_killed.connect(_on_enemy_killed)
	_health.damaged.connect(_on_damaged)
	_hud.bind(_health)
	_camera.make_current()
	_capture_mouse()
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("reload"):
		_weapon.start_reload()
	elif event.is_action_pressed("weapon_1"):
		_weapon.equip(0)
	elif event.is_action_pressed("weapon_2"):
		_weapon.equip(1)
	elif event.is_action_pressed("weapon_next"):
		_weapon.cycle(1)
	elif event.is_action_pressed("weapon_prev"):
		_weapon.cycle(-1)
	elif event is InputEventMouseButton and event.pressed:
		_capture_mouse()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: Vector2 = event.screen_relative
		_yaw = wrapf(_yaw - motion.x * mouse_sensitivity, -PI, PI)
		var limit := deg_to_rad(max_pitch_degrees)
		_pitch = clampf(_pitch - motion.y * mouse_sensitivity, -limit, limit)


func _process(delta: float) -> void:
	_recoil = _recoil.lerp(Vector2.ZERO, 1.0 - exp(-_weapon.data.recoil_recovery * delta))
	if not _health.is_alive():
		_death_blend = move_toward(_death_blend, 1.0, delta / 0.4)
	_update_camera()


func _physics_process(delta: float) -> void:
	if not _health.is_alive():
		_respawn_left -= delta
	_fall_check_delay -= delta
	if multiplayer.is_server():
		_apply_host_rules()
	if not is_multiplayer_authority():
		_follow_remote_state(delta)
		return
	if not _health.is_alive():
		_physics_process_dead(delta)
		_publish_state()
		return
	rotation.y = _yaw
	_alive_time += delta
	_hud.update_stats(_kills, _alive_time)

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * gravity_multiplier * delta

	# get_vector limita già la lunghezza a 1 (e mantiene l'analogico del gamepad).
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := transform.basis * Vector3(input.x, 0.0, input.y)
	var sprinting := Input.is_action_pressed("sprint") and input.y < 0.0
	var speed := sprint_speed if sprinting else walk_speed
	var friction := push_friction.x if is_on_floor() else push_friction.y
	_push = _push.lerp(Vector3.ZERO, 1.0 - exp(-friction * delta))
	velocity.x = direction.x * speed + _push.x
	velocity.z = direction.z * speed + _push.z

	move_and_slide()
	_handle_fire()
	_handle_melee()
	_handle_interaction()
	_publish_state()


## Armi portate dal giocatore.
func weapon() -> Weapon:
	return _weapon


## Sull'host, per ogni giocatore: chi cade fuori dal livello muore, chi è
## morto da abbastanza tempo rinasce.
func _apply_host_rules() -> void:
	if _health.is_alive():
		if global_position.y < kill_height and _fall_check_delay <= 0.0:
			_health.take_damage(_health.current)
	elif _respawn_left <= 0.0:
		if NetSession.is_online():
			_respawn.rpc()
		_respawn()


## Scrive lo stato che MultiplayerSynchronizer invia agli altri partecipanti.
func _publish_state() -> void:
	sync_position = global_position
	sync_yaw = _yaw
	sync_pitch = _pitch


## Sugli altri partecipanti il giocatore insegue morbidamente l'ultimo stato
## ricevuto: niente scatti anche se i pacchetti arrivano a ritmo irregolare.
func _follow_remote_state(delta: float) -> void:
	var weight := 1.0 - exp(-remote_smoothing * delta)
	# Un salto grande (rinascita, teletrasporto) si applica subito.
	if global_position.distance_to(sync_position) > 4.0:
		global_position = sync_position
		reset_physics_interpolation()
	else:
		global_position = global_position.lerp(sync_position, weight)
	rotation.y = lerp_angle(rotation.y, sync_yaw, weight)


func _apply_player_color() -> void:
	var player_color := player_colors[(player_number - 1) % player_colors.size()]
	var material := StandardMaterial3D.new()
	material.albedo_color = player_color
	_body_mesh.material_override = material
	_name_tag.modulate = player_color.lightened(0.3)


## Da morti si resta fermi (cadendo, se si è in aria) fino alla rinascita.
func _physics_process_dead(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * gravity_multiplier * delta
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	_hud.update_respawn_countdown(_respawn_left)


## Cerca l'oggetto interagibile sotto il mirino, aggiorna la scritta e, se si
## preme E, lo usa (sull'host direttamente, altrimenti chiedendolo all'host).
func _handle_interaction() -> void:
	_interact_target = null
	var text := ""
	var aim := -_aim_basis().z
	var query := PhysicsRayQueryParameters3D.create(_head.global_position,
			_head.global_position + aim * interact_distance, LAYER_WORLD | LAYER_INTERACTABLE, [get_rid()])
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result and result.collider.has_method("interaction_text"):
		text = result.collider.interaction_text(self)
		if text != "":
			_interact_target = result.collider
	_hud.show_prompt(text)
	if _interact_target and Input.is_action_just_pressed("interact"):
		interact_with(_interact_target)


## Usa target: sull'host direttamente, altrimenti chiedendolo all'host.
func interact_with(target: Node) -> void:
	if multiplayer.is_server():
		_host_interact(target, _weapon.current_slot())
	else:
		_request_interact.rpc_id(1, target.get_path(), _weapon.current_slot())


## Sull'host: il giocatore usa target, se è vivo e abbastanza vicino. slot è
## l'arma che ha in mano (quella da scambiare).
func _host_interact(target: Node, slot: int) -> void:
	if not _health.is_alive() or not target is Node3D or not target.has_method("interact"):
		return
	# Un po' di margine: la posizione di un giocatore remoto arriva in ritardo.
	if _head.global_position.distance_to(target.global_position) > interact_distance + 1.5:
		return
	target.interact(self, slot)


@rpc("any_peer", "call_remote", "reliable")
func _request_interact(target_path: NodePath, slot: int) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == get_multiplayer_authority():
		var target := get_node_or_null(target_path)
		if target:
			_host_interact(target, slot)


func _handle_melee() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not _melee.can_attack():
		return
	if Input.is_action_just_pressed("melee"):
		_melee.attack(_head.global_position, -_aim_basis().z, self)


## Spinge via il giocatore con questa velocità (orizzontale + salto). Gli
## zombie la chiamano sull'host: se il giocatore è di un altro partecipante,
## la spinta va a lui, che è chi lo muove.
func apply_knockback(impulse: Vector3) -> void:
	if not is_multiplayer_authority():
		if multiplayer.is_server():
			_receive_knockback.rpc_id(get_multiplayer_authority(), impulse)
		return
	if not _health.is_alive():
		return
	_push = Vector3(impulse.x, 0.0, impulse.z)
	velocity.y = maxf(velocity.y, impulse.y)


@rpc("any_peer", "call_remote", "reliable")
func _receive_knockback(impulse: Vector3) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		apply_knockback(impulse)


func _on_damaged(_amount: float, source: Node, _hit_position: Vector3) -> void:
	# Un piccolo scossone della visuale: si capisce subito di essere stati colpiti.
	_recoil += Vector2(deg_to_rad(2.0), deg_to_rad(randf_range(-1.5, 1.5)))
	if source is Node3D and source != self:
		_hud.show_damage_from(source.global_position)


func _on_enemy_killed(_enemy: Node, killer: Node) -> void:
	if killer == self and _health.is_alive():
		_kills += 1
		_hud.update_stats(_kills, _alive_time)


func _on_died(_source: Node) -> void:
	_respawn_left = respawn_time
	_show_dead_body(true)
	if not is_multiplayer_authority():
		return
	_weapon.visible = false
	_hud.show_prompt("")
	_best_time = maxf(_best_time, _alive_time)
	_hud.show_death(_kills, _alive_time, _best_time)
	_hud.update_respawn_countdown(_respawn_left)


## Il corpo cade a terra da morto (lo vedono gli altri; per sé resta l'ombra)
## e si rialza alla rinascita.
func _show_dead_body(dead: bool) -> void:
	# Disteso all'indietro, con i piedi dove stava in piedi.
	var lying := Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0.0, 0.4, 0.0))
	if _body_tween:
		_body_tween.kill()
	_body_tween = create_tween().set_parallel()
	_body_tween.tween_property(_body_mesh, "transform", lying * _body_rest if dead else _body_rest, 0.35) 			.set_trans(Tween.TRANS_BOUNCE if dead else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(_visor, "transform", lying * _visor_rest if dead else _visor_rest, 0.35) 			.set_trans(Tween.TRANS_BOUNCE if dead else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(_name_tag, "position:y", _name_tag_height - 1.2 if dead else _name_tag_height, 0.35)
	_name_tag.modulate.a = 0.5 if dead else 1.0


## Torna al punto di partenza con la vita piena. La decide l'host: chiamata
## direttamente lì, con una chiamata di rete sugli altri.
@rpc("any_peer", "call_remote", "reliable")
func _respawn() -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	# Sull'host riempie la vita; sugli altri non fa nulla e la vita arriva dall'host.
	_health.reset()
	_show_dead_body(false)
	_fall_check_delay = 1.0
	if not is_multiplayer_authority():
		# Si mostra subito al punto di partenza, senza aspettare la sua posizione.
		global_position = _spawn_transform.origin
		sync_position = global_position
		reset_physics_interpolation()
		return
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_push = Vector3.ZERO
	_yaw = _spawn_transform.basis.get_euler().y
	_pitch = 0.0
	_recoil = Vector2.ZERO
	_death_blend = 0.0
	reset_physics_interpolation()
	_weapon.visible = true
	_weapon.refill()
	_kills = 0
	_alive_time = 0.0
	_hud.update_stats(_kills, _alive_time)
	_hud.hide_death()


func _handle_fire() -> void:
	# Caricatore vuoto (per esempio dopo un cambio arma): si ricarica da solo.
	if _weapon.ammo() == 0:
		_weapon.start_reload()
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not _weapon.can_fire():
		return
	var trigger := Input.is_action_pressed("fire") if _weapon.data.automatic \
			else Input.is_action_just_pressed("fire")
	if not trigger:
		return
	_weapon.fire(_head.global_position, -_aim_basis().z, [get_rid()])
	_recoil.x += deg_to_rad(_weapon.data.recoil_pitch_degrees)
	_recoil.y += deg_to_rad(randf_range(-1.0, 1.0) * _weapon.data.recoil_yaw_degrees)


## Direzione in cui si guarda, rinculo compreso: si spara dove si vede il mirino.
func _aim_basis() -> Basis:
	var limit := deg_to_rad(max_pitch_degrees)
	var pitch := clampf(_pitch + _recoil.x, -limit, limit)
	return Basis.from_euler(Vector3(pitch, _yaw + _recoil.y, 0.0))


func _update_camera() -> void:
	var eye := _head.get_global_transform_interpolated().origin
	var aim := _aim_basis()
	if _death_blend > 0.0:
		# Da morti la visuale crolla verso terra e si inclina di lato.
		var t := smoothstep(0.0, 1.0, _death_blend)
		eye.y -= death_camera_drop * t
		aim = aim * Basis(Vector3.BACK, deg_to_rad(25.0) * t)
	_camera.global_transform = Transform3D(aim, eye)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
