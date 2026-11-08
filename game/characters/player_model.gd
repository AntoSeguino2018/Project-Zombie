class_name PlayerModel
extends Node3D
## Modello in terza persona del giocatore (figlio del FpsController): sceglie la
## clip dallo stato del giocatore (vivo, a terra, morto, mentre rianima) e da
## come si sposta, e ne regola la velocità.
##
## Funziona allo stesso modo per il giocatore locale (di cui si vede solo
## l'ombra) e per quelli remoti, di cui si conosce solo la posizione: la
## velocità si ricava dallo spostamento tra un tick di fisica e l'altro.
## Le clip di movimento sono sul posto e animate a una velocità nominale
## (NOMINAL_SPEED, dalla scheda del personaggio): si riproducono più veloci o
## più lente perché i piedi seguano il giocatore.

## Clip che si ripetono; Salto si ferma sull'ultimo fotogramma, in volo.
const LOOPED: Array[StringName] = [&"Ferma", &"Cammina", &"Corsa", &"Indietro", &"Sinistra",
		&"Destra", &"ATerra", &"Rianima"]
## Velocità a cui è animata ogni clip di movimento, in m/s.
const NOMINAL_SPEED := {&"Cammina": 3.17, &"Corsa": 4.69, &"Indietro": 2.1,
		&"Sinistra": 1.07, &"Destra": 1.07, &"ATerra": 1.5}
## Punto del Salto in cui i piedi lasciano terra: prima c'è il piegamento, che
## in gioco avviene già in aria.
const JUMP_TAKEOFF := 0.25

## Tempo di passaggio da una clip all'altra, in secondi.
@export var blend_time := 0.15
## Sotto questa velocità orizzontale (m/s) si sta fermi.
@export var idle_speed := 0.4
## Da questa velocità in avanti (m/s) si corre invece di camminare.
@export var run_speed := 8.5
## Limiti della velocità di riproduzione: oltre, le gambe girerebbero troppo
## in fretta e si accetta che i piedi scivolino un po'.
@export var speed_scale_range := Vector2(0.5, 2.5)
## Velocità verticale (m/s) oltre cui un giocatore remoto è in aria.
@export var air_vertical_speed := 1.5
## Secondi in aria prima di passare al salto: evita il salto su scale e rampe.
@export var air_delay := 0.12

var _player: FpsController
var _anim: AnimationPlayer
var _clip := &""
var _last_position := Vector3.ZERO
var _velocity := Vector3.ZERO
var _air_time := 0.0


func _ready() -> void:
	_player = get_parent() as FpsController
	_anim = find_child("AnimationPlayer") as AnimationPlayer
	for clip in LOOPED:
		if _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_last_position = global_position
	_play(&"Ferma", 1.0)


## Clip in riproduzione.
func current_clip() -> StringName:
	return _clip


## Solo ombra (il giocatore locale non vede il proprio corpo) o visibile.
func set_shadow_only(shadow_only: bool) -> void:
	for node in find_children("*", "GeometryInstance3D"):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY \
				if shadow_only else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var moved := (global_position - _last_position) / delta
	_last_position = global_position
	# Un salto di posizione (rinascita, teletrasporto) non è movimento.
	if moved.length() < 30.0:
		_velocity = _velocity.lerp(moved, 1.0 - exp(-12.0 * delta))
	var local := _player.global_transform.basis.inverse() * _velocity
	var speed := Vector2(local.x, local.z).length()
	match _player.life:
		FpsController.Life.DEAD:
			_play(&"ATerra", 0.0)
		FpsController.Life.DOWNED:
			_play(&"ATerra", _scale_for(&"ATerra", speed, 0.0))
		_:
			_update_alive(local, speed, delta)


func _update_alive(local: Vector3, speed: float, delta: float) -> void:
	# Seduti sull'elicottero: si muovono con lui ma stanno fermi.
	if _player.is_boarded():
		_air_time = 0.0
		_play(&"Ferma", 1.0)
		return
	var in_air := not _player.is_on_floor() if _player.is_multiplayer_authority() \
			else absf(local.y) > air_vertical_speed
	_air_time = _air_time + delta if in_air else 0.0
	if _air_time > air_delay:
		if _clip != &"Salto":
			_play(&"Salto", 1.0)
			_anim.seek(JUMP_TAKEOFF, true)
		return
	if _is_reviving():
		_play(&"Rianima", 1.0)
		return
	if speed < idle_speed:
		_play(&"Ferma", 1.0)
		return
	var forward := -local.z
	var clip: StringName
	if absf(local.x) > absf(forward):
		clip = &"Destra" if local.x > 0.0 else &"Sinistra"
	elif forward > 0.0:
		clip = &"Corsa" if speed >= run_speed else &"Cammina"
	else:
		clip = &"Indietro"
	_play(clip, _scale_for(clip, speed, speed_scale_range.x))


func _scale_for(clip: StringName, speed: float, minimum: float) -> float:
	return clampf(speed / float(NOMINAL_SPEED[clip]), minimum, speed_scale_range.y)


## Sta rianimando un compagno. Chi controlla il giocatore e l'host lo sanno; gli
## altri lo deducono da un compagno a terra vicino che si sta rialzando.
func _is_reviving() -> bool:
	if _player.reviving() != null:
		return true
	if _player.is_multiplayer_authority() or multiplayer.is_server():
		return false
	for other in get_tree().get_nodes_in_group("players"):
		var mate := other as FpsController
		if mate != null and mate != _player and mate.life == FpsController.Life.DOWNED \
				and mate.revive_progress > 0.0 \
				and mate.global_position.distance_to(_player.global_position) <= _player.revive_distance + 0.5:
			return true
	return false


func _play(clip: StringName, speed_scale: float) -> void:
	if clip != _clip:
		_clip = clip
		_anim.play(clip, blend_time)
	_anim.speed_scale = speed_scale
