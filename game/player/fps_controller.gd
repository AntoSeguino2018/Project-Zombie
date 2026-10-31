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

@export_group("Visuale")
## Radianti di rotazione per pixel di movimento del mouse.
@export var mouse_sensitivity := 0.0025
## Quanto si può guardare in alto o in basso, in gradi.
@export_range(10.0, 89.0) var max_pitch_degrees := 89.0

var _yaw := 0.0
var _pitch := 0.0

@onready var _head: Marker3D = $Head
@onready var _camera: Camera3D = $Camera3D
@onready var _body_mesh: MeshInstance3D = $BodyMesh
@onready var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	_yaw = rotation.y
	if not is_multiplayer_authority():
		set_process(false)
		set_process_unhandled_input(false)
		return
	# Il proprio corpo non si vede, ma continua a proiettare l'ombra.
	_body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
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


func _process(_delta: float) -> void:
	_update_camera()


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
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
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()


func _update_camera() -> void:
	var eye := _head.get_global_transform_interpolated().origin
	_camera.global_transform = Transform3D(Basis.from_euler(Vector3(_pitch, _yaw, 0.0)), eye)


func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
