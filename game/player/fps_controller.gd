class_name FpsController
extends CharacterBody3D
## Controller in prima persona: movimento, salto, sprint e visuale col mouse.
##
## Predisposto per la rete: input e camera sono attivi solo sul giocatore che ha
## l'autorità su questo nodo (in single player è sempre quello locale).
## La camera è top_level e segue la testa interpolata, così il movimento resta
## fluido anche su monitor a più di 60 Hz, mentre la rotazione del mouse è immediata.

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

@export_group("Vita")
## Secondi da morto prima di rinascere al punto di partenza.
@export var respawn_time := 3.0
## Sotto questa quota si muore: si è caduti fuori dal livello.
@export var kill_height := -30.0
## Di quanto scende la visuale da morti, in metri.
@export var death_camera_drop := 1.2

var _yaw := 0.0
var _pitch := 0.0
## Spostamento della visuale dovuto al rinculo (x = alto/basso, y = lati), in
## radianti. Si somma alla mira e torna a zero da solo.
var _recoil := Vector2.ZERO
## Spinta ricevuta (es. carica del Bestione): si somma al movimento e si esaurisce.
var _push := Vector3.ZERO
var _spawn_transform: Transform3D
var _respawn_left := 0.0
## Da 0 (vivo) a 1 (visuale a terra): fa crollare la camera quando si muore.
var _death_blend := 0.0

@onready var _head: Marker3D = $Head
@onready var _camera: Camera3D = $Camera3D
@onready var _body_mesh: MeshInstance3D = $BodyMesh
@onready var _weapon: HitscanWeapon = $Camera3D/Weapon
@onready var _melee: MeleeAttack = $Camera3D/Melee
@onready var _health: HealthComponent = $Health
@onready var _hud: PlayerHud = $Hud
@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	# I nemici cercano i bersagli in questo gruppo.
	add_to_group("players")
	_yaw = rotation.y
	_spawn_transform = global_transform
	if not is_multiplayer_authority():
		_weapon.visible = false
		_hud.visible = false
		set_process(false)
		set_process_unhandled_input(false)
		return
	# Il proprio corpo non si vede, ma continua a proiettare l'ombra.
	_body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_weapon.dealt_damage.connect(func(_target, _amount, killed): _hud.crosshair.show_hit(killed))
	_melee.dealt_damage.connect(func(_target, _amount, killed): _hud.crosshair.show_hit(killed))
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_hud.bind(_health)
	_camera.make_current()
	_capture_mouse()
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	if not is_multiplayer_authority():
		return
	if not _health.is_alive():
		_physics_process_dead(delta)
		return
	rotation.y = _yaw

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
	if global_position.y < kill_height:
		_health.take_damage(_health.current)


## Da morti si resta fermi (cadendo, se si è in aria) fino alla rinascita.
func _physics_process_dead(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * gravity_multiplier * delta
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	_respawn_left -= delta
	_hud.update_respawn_countdown(_respawn_left)
	if _respawn_left <= 0.0:
		_respawn()


func _handle_melee() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not _melee.can_attack():
		return
	if Input.is_action_just_pressed("melee"):
		_melee.attack(_head.global_position, -_aim_basis().z, self)


## Spinge via il giocatore con questa velocità (orizzontale + salto).
func apply_knockback(impulse: Vector3) -> void:
	if not _health.is_alive():
		return
	_push = Vector3(impulse.x, 0.0, impulse.z)
	velocity.y = maxf(velocity.y, impulse.y)


func _on_damaged(_amount: float, _source: Node, _hit_position: Vector3) -> void:
	# Un piccolo scossone della visuale: si capisce subito di essere stati colpiti.
	_recoil += Vector2(deg_to_rad(2.0), deg_to_rad(randf_range(-1.5, 1.5)))


func _on_died(_source: Node) -> void:
	_respawn_left = respawn_time
	_weapon.visible = false
	_hud.show_death()
	_hud.update_respawn_countdown(_respawn_left)


## Torna al punto di partenza con la vita piena.
## In multiplayer sarà l'host a decidere quando e dove si rinasce.
func _respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_push = Vector3.ZERO
	_yaw = _spawn_transform.basis.get_euler().y
	_pitch = 0.0
	_recoil = Vector2.ZERO
	_death_blend = 0.0
	reset_physics_interpolation()
	_health.reset()
	_weapon.visible = true
	_hud.hide_death()


func _handle_fire() -> void:
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
