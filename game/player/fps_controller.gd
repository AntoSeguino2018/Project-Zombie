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
## Vita, caduta fuori dal livello, rianimazione e rinascita le decide l'host;
## chi controlla il giocatore si limita a mostrarle (HUD, visuale a terra) e
## gli altri vedono il corpo cadere a terra.
## Finita la vita non si muore subito: si resta A TERRA, si striscia piano e un
## compagno vivo può rianimarci tenendo premuto E vicino a noi. Se nessuno lo
## fa in tempo si MUORE e si rinasce alla fine dell'ondata (vedi RunManager).
## La camera è top_level e segue la testa interpolata, così il movimento resta
## fluido anche su monitor a più di 60 Hz, mentre la rotazione del mouse è immediata.

## Vivo, a terra (si può rianimare) o morto (si aspetta la fine dell'ondata).
enum Life { ALIVE, DOWNED, DEAD }

const LAYER_WORLD := 1
const LAYER_INTERACTABLE := 16

## Lo stato di vita è cambiato (su tutti i partecipanti).
signal life_changed(life: Life)

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
## Secondi a terra prima di morire, se nessuno ci rianima.
@export var bleed_out_time := 30.0
## Secondi tenendo premuto E per rianimare un compagno.
@export var revive_time := 3.0
## Distanza massima da cui si rianima un compagno, in metri.
@export var revive_distance := 2.5
## Vita con cui ci si rialza dopo essere stati rianimati, in frazione del massimo.
@export_range(0.05, 1.0) var revive_health_fraction := 0.4
## Soldi a chi finisce di rianimarci.
@export var revive_reward := 20
## Velocità strisciando a terra, in m/s.
@export var crawl_speed := 1.5
## Sotto questa quota si muore: si è caduti fuori dal livello.
@export var kill_height := -30.0
## Di quanto scende la visuale da morti, in metri (a terra un po' meno).
@export var death_camera_drop := 1.2

## Numero del giocatore nella partita (1-4): decide colore e nome.
var player_number := 1
var life := Life.ALIVE
## Da 0 a 1: quanto manca a rialzarsi mentre qualcuno ci rianima (deciso dall'host).
var revive_progress := 0.0
## Secondi a terra che restano prima di morire.
var bleed_left := 0.0
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
## Dopo la rinascita l'host aspetta un po' prima di controllare le cadute: la
## nuova posizione di un giocatore remoto arriva con qualche istante di ritardo.
var _fall_check_delay := 0.0
## Sull'host: il giocatore è caduto fuori dal livello, quindi muore senza
## passare da terra.
var _fell_out := false
## Compagno a terra che si potrebbe rianimare da qui (solo per chi controlla).
var _revive_candidate: FpsController
## Compagno che stiamo rianimando tenendo premuto E (lato host e lato nostro).
var _reviving: FpsController
## Sull'host: ultimo tick di fisica in cui qualcuno ci ha rianimato, e chi.
var _revived_frame := -10
var _last_reviver: FpsController
var _progress_send_left := 0.0
## Da 0 (vivo) a 1 (visuale a terra): fa crollare la camera quando si va giù.
var _death_blend := 0.0
## Posa da vivo del corpo, per rialzarlo alla rinascita.
var _body_rest: Transform3D
var _visor_rest: Transform3D
var _name_tag_height := 0.0
var _body_tween: Tween
## Oggetto interagibile guardato in questo momento (null = nessuno).
var _interact_target: Node
## Statistiche della run in corso, per l'HUD e la schermata di fine run.
var _kills := 0
var _run_time := 0.0
var _base_max_health := 100.0

@onready var _head: Marker3D = $Head
@onready var _camera: Camera3D = $Camera3D
@onready var _body_mesh: MeshInstance3D = $BodyMesh
@onready var _visor: MeshInstance3D = $Visor
@onready var _name_tag: Label3D = $NameTag
@onready var _weapon: Weapon = $Camera3D/Weapon
@onready var _melee: MeleeAttack = $Camera3D/Melee
@onready var _health: HealthComponent = $Health
@onready var _inventory: RunInventory = $Inventory
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
	_name_tag.text = display_name()
	_health.died.connect(_on_died)
	_base_max_health = _health.max_health
	if multiplayer.is_server():
		# Gli oggetti che alzano la vita massima la cambiano subito.
		_inventory.items_changed.connect(func():
			_health.set_max_health(_base_max_health + _inventory.stat("max_health")))
	if not multiplayer.is_server():
		# Chi entra a partita iniziata chiede all'host chi è a terra o morto.
		_request_life.rpc_id(1)
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
	_hud.bind_inventory(_inventory)
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
	elif event.is_action_pressed("inspect"):
		_weapon.inspect()
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
	var blend_target := {Life.ALIVE: 0.0, Life.DOWNED: 0.7, Life.DEAD: 1.0}[life] as float
	_death_blend = move_toward(_death_blend, blend_target, delta / 0.4)
	_update_camera()


func _physics_process(delta: float) -> void:
	_fall_check_delay -= delta
	if life == Life.DOWNED and not multiplayer.is_server() and revive_progress <= 0.0:
		bleed_left -= delta
	if multiplayer.is_server():
		_apply_host_rules(delta)
	if not is_multiplayer_authority():
		_follow_remote_state(delta)
		return
	if RunManager.is_running(self):
		_run_time += delta
	_hud.update_stats(_kills, _run_time)
	_hud.update_revive(self)
	if life != Life.ALIVE:
		_physics_process_down(delta)
		_publish_state()
		return
	rotation.y = _yaw
	_sync_weapon_bonuses()

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * gravity_multiplier * delta

	# get_vector limita già la lunghezza a 1 (e mantiene l'analogico del gamepad).
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := transform.basis * Vector3(input.x, 0.0, input.y)
	var sprinting := Input.is_action_pressed("sprint") and input.y < 0.0
	var speed := (sprint_speed if sprinting else walk_speed) * (1.0 + _inventory.stat("move_speed"))
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


## Soldi, boost e oggetti della run.
func inventory() -> RunInventory:
	return _inventory


## Passa all'arma gli effetti di boost e oggetti.
func _sync_weapon_bonuses() -> void:
	_weapon.fire_rate_multiplier = _inventory.fire_rate_multiplier()
	_weapon.reload_speed_multiplier = _inventory.reload_speed_multiplier()
	_weapon.magazine_multiplier = 1.0 + _inventory.stat("magazine")


## Moltiplica i danni che fa questo giocatore (oggetti); lo usa HealthComponent.
func damage_multiplier() -> float:
	return 1.0 + _inventory.stat("damage")


## Moltiplica il danno dei pugni (oltre a damage_multiplier).
func melee_multiplier() -> float:
	return 1.0 + _inventory.stat("melee_damage")


## Vero se è in piedi (vivo e non a terra).
func is_standing() -> bool:
	return life == Life.ALIVE


## Sull'host, per ogni giocatore: chi cade fuori dal livello muore; chi sta
## rianimando un compagno fa avanzare la rianimazione; chi è a terra si
## dissangua, ma non mentre qualcuno lo sta rianimando.
func _apply_host_rules(delta: float) -> void:
	match life:
		Life.ALIVE:
			if global_position.y < kill_height and _fall_check_delay <= 0.0:
				_fell_out = true
				_health.take_damage(_health.current)
			elif _can_revive(_reviving):
				var speed := 1.0 + _inventory.stat("revive_speed")
				_reviving._host_add_revive(delta * speed / _reviving.revive_time, self)
		Life.DOWNED:
			var being_revived := Engine.get_physics_frames() - _revived_frame <= 1
			if not being_revived and revive_progress > 0.0:
				_set_revive_progress(0.0, true)
			if revive_progress >= 1.0:
				host_revive()
			elif not being_revived:
				bleed_left -= delta
				if bleed_left <= 0.0:
					_host_set_life(Life.DEAD)


## Sull'host: vero se da qui si può rianimare target.
func _can_revive(target: FpsController) -> bool:
	return is_instance_valid(target) and target != self and target.life == Life.DOWNED \
			and life == Life.ALIVE and global_position.distance_to(target.global_position) <= revive_distance + 1.0


## Sull'host: un compagno ci sta rianimando; amount è la frazione fatta in questo tick.
func _host_add_revive(amount: float, reviver: FpsController) -> void:
	_revived_frame = Engine.get_physics_frames()
	_last_reviver = reviver
	_set_revive_progress(minf(revive_progress + amount, 1.0))


func _set_revive_progress(value: float, force_send := false) -> void:
	revive_progress = value
	if not NetSession.is_online():
		return
	_progress_send_left -= get_physics_process_delta_time()
	if force_send or _progress_send_left <= 0.0:
		_progress_send_left = 0.1
		_receive_revive_progress.rpc(value)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _receive_revive_progress(value: float) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		revive_progress = value


## Sull'host: rialza un giocatore a terra lì dove si trova, con un po' di vita.
func host_revive() -> void:
	if life != Life.DOWNED:
		return
	_health.restore(_health.max_health * revive_health_fraction)
	_host_set_life(Life.ALIVE)
	# Chi ha appena finito di rianimarci viene ricompensato.
	if is_instance_valid(_last_reviver) and Engine.get_physics_frames() - _revived_frame <= 1:
		_last_reviver.inventory().host_add_money(revive_reward)
	_last_reviver = null


## Sull'host: fa rinascere un giocatore morto in at, con la vita piena.
func host_respawn(at: Vector3) -> void:
	_health.reset()
	_host_set_life(Life.ALIVE)
	_teleport(at)
	if NetSession.is_online():
		_receive_teleport.rpc(at)


## Sull'host, a inizio run: vita piena, punto di partenza, solo la pistola.
func host_restart() -> void:
	# Prima l'inventario: chi si rialza deve già avere i caricatori senza oggetti.
	_inventory.host_reset()
	_health.reset()
	_host_set_life(Life.ALIVE)
	_weapon.host_set_loadout([["pistol"]], 0)
	_teleport(_spawn_transform.origin)
	_reset_run_stats()
	if NetSession.is_online():
		_receive_teleport.rpc(_spawn_transform.origin)
		_receive_run_restart.rpc()


## Sull'host: cambia lo stato di vita e lo manda a tutti.
func _host_set_life(new_life: Life) -> void:
	if new_life == Life.DOWNED:
		bleed_left = bleed_out_time
	_apply_life(new_life, bleed_left)
	if NetSession.is_online():
		_receive_life.rpc(new_life, bleed_left)


@rpc("any_peer", "call_remote", "reliable")
func _receive_life(new_life: int, new_bleed_left: float) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_apply_life(new_life as Life, new_bleed_left)


@rpc("any_peer", "call_remote", "reliable")
func _request_life() -> void:
	if multiplayer.is_server():
		_receive_life.rpc_id(multiplayer.get_remote_sender_id(), life, bleed_left)


func _apply_life(new_life: Life, new_bleed_left: float) -> void:
	bleed_left = new_bleed_left
	revive_progress = 0.0
	if new_life == life:
		return
	life = new_life
	_fell_out = false
	_reviving = null
	_show_dead_body(life != Life.ALIVE, life == Life.DEAD)
	if is_multiplayer_authority():
		_weapon.visible = life == Life.ALIVE
		_hud.show_prompt("")
		match life:
			Life.ALIVE:
				_fall_check_delay = 1.0
				_sync_weapon_bonuses()
				_weapon.refill()
				_hud.hide_death()
			Life.DOWNED:
				_hud.show_downed()
			Life.DEAD:
				_hud.show_dead()
	life_changed.emit(life)


## Sposta il giocatore in at. Lo esegue chi lo controlla; gli altri lo
## mostrano subito lì, senza aspettare la sua posizione.
func _teleport(at: Vector3) -> void:
	_fall_check_delay = 1.0
	global_position = at
	sync_position = at
	velocity = Vector3.ZERO
	_push = Vector3.ZERO
	reset_physics_interpolation()


@rpc("any_peer", "call_remote", "reliable")
func _receive_teleport(at: Vector3) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_teleport(at)


@rpc("any_peer", "call_remote", "reliable")
func _receive_run_restart() -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_reset_run_stats()


func _reset_run_stats() -> void:
	_kills = 0
	_run_time = 0.0
	_yaw = _spawn_transform.basis.get_euler().y
	_pitch = 0.0
	_recoil = Vector2.ZERO
	if is_multiplayer_authority():
		_hud.update_stats(_kills, _run_time)


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


## A terra si striscia piano; da morti si resta fermi (cadendo, se si è in aria).
func _physics_process_down(delta: float) -> void:
	rotation.y = _yaw
	if not is_on_floor():
		velocity.y -= _gravity * gravity_multiplier * delta
	var direction := Vector3.ZERO
	if life == Life.DOWNED:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		direction = transform.basis * Vector3(input.x, 0.0, input.y)
		_hud.update_bleed_out(bleed_left, revive_progress)
	velocity.x = direction.x * crawl_speed
	velocity.z = direction.z * crawl_speed
	move_and_slide()


## Cerca l'oggetto interagibile sotto il mirino, aggiorna la scritta e, se si
## preme E, lo usa (sull'host direttamente, altrimenti chiedendolo all'host).
func _handle_interaction() -> void:
	_interact_target = null
	# Un compagno a terra vicino ha la precedenza su casse e armi.
	_revive_candidate = _nearest_downed_teammate()
	var holding := _revive_candidate != null and Input.is_action_pressed("interact")
	_set_reviving(_revive_candidate if holding else null)
	if _revive_candidate:
		_hud.show_prompt("" if holding else "Tieni premuto: rianima %s" % _revive_candidate.display_name())
		return
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


## Nome mostrato sopra la testa e nei messaggi.
func display_name() -> String:
	return "Giocatore %d" % player_number


## Il compagno a terra più vicino entro revive_distance, o null.
func _nearest_downed_teammate() -> FpsController:
	var best: FpsController = null
	var best_distance := revive_distance
	for player in get_tree().get_nodes_in_group("players"):
		if player == self or not player is FpsController or player.life != Life.DOWNED:
			continue
		var distance: float = global_position.distance_to(player.global_position)
		if distance <= best_distance:
			best = player
			best_distance = distance
	return best


## Inizia o smette di rianimare target (null = smette); lo decide l'host.
func _set_reviving(target: FpsController) -> void:
	if target == _reviving:
		return
	_reviving = target
	if not multiplayer.is_server():
		_request_revive.rpc_id(1, target.get_path() if target else NodePath())


## Il compagno che si sta rianimando in questo momento, o null.
func reviving() -> FpsController:
	return _reviving


@rpc("any_peer", "call_remote", "reliable")
func _request_revive(target_path: NodePath) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	var target := get_node_or_null(target_path) if not target_path.is_empty() else null
	_reviving = target as FpsController


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
	if killer == self:
		_kills += 1
		_hud.update_stats(_kills, _run_time)


## Uccisioni nella run in corso.
func kills() -> int:
	return _kills


## Finita la vita: lo stato (a terra o morto) lo decide l'host e arriva a tutti.
func _on_died(_source: Node) -> void:
	if multiplayer.is_server():
		_host_set_life(Life.DEAD if _fell_out else Life.DOWNED)


## Il corpo cade a terra (lo vedono gli altri; per sé resta l'ombra) e si
## rialza quando si torna in piedi. Il nome di chi è a terra si vede anche
## attraverso i muri, così i compagni lo trovano.
func _show_dead_body(down: bool, dead := false) -> void:
	# Disteso all'indietro, con i piedi dove stava in piedi.
	var lying := Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0.0, 0.4, 0.0))
	if _body_tween:
		_body_tween.kill()
	_body_tween = create_tween().set_parallel()
	_body_tween.tween_property(_body_mesh, "transform", lying * _body_rest if down else _body_rest, 0.35) \
			.set_trans(Tween.TRANS_BOUNCE if down else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(_visor, "transform", lying * _visor_rest if down else _visor_rest, 0.35) \
			.set_trans(Tween.TRANS_BOUNCE if down else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_body_tween.tween_property(_name_tag, "position:y", _name_tag_height - 1.2 if down else _name_tag_height, 0.35)
	_name_tag.text = display_name() + ("  ·  A TERRA" if down and not dead else "")
	_name_tag.no_depth_test = down and not dead
	# Visto attraverso i muri ha sempre la stessa grandezza: leggibile da
	# lontano, senza coprire la visuale a chi lo rianima da vicino.
	_name_tag.fixed_size = _name_tag.no_depth_test
	_name_tag.pixel_size = 0.0012 if _name_tag.fixed_size else 0.005
	_name_tag.modulate.a = 0.5 if dead else 1.0


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
		# A terra la visuale crolla verso il pavimento; da morti si inclina anche di lato.
		var t := smoothstep(0.0, 1.0, _death_blend)
		eye.y -= death_camera_drop * t
		aim = aim * Basis(Vector3.BACK, deg_to_rad(25.0) * clampf((_death_blend - 0.7) / 0.3, 0.0, 1.0))
	_camera.global_transform = Transform3D(aim, eye)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
