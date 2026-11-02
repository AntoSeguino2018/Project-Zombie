class_name MagnumViewmodel
extends Node3D
## La Magnum in prima persona: collega le animazioni del modello (Riposo,
## Sparo, Ricarica, Ispezione) all'arma e accende i LED azzurri che contano i
## colpi.
##
## Sul tamburo c'è un LED per camera (il quadratino davanti e la striscia
## esterna), acceso finché la camera ha il colpo. Lo sparo spegne la camera in
## alto e l'animazione gira il tamburo di 60°, portando su la successiva. La
## striscia in cima al fusto ripete il conteggio, perché in prima persona si
## vede meglio; con l'ultimo colpo lampeggia.
## Presa in mano, i LED si accendono uno dopo l'altro (avvio); nella ricarica si
## spengono quando escono i bossoli e si riaccendono mentre entrano le
## cartucce; nell'ispezione fanno un giro di "diagnostica".
## Arma e animazioni parlano tra loro con on_equip, on_fire, on_reload e
## on_inspect (vedi Weapon). Senza arma (es. a terra in una cassa) resta carica
## e a riposo. Il modello in prima persona lo vede solo chi spara: niente rete.

const LED_SHADER := preload("res://game/weapons/viewmodels/led_mask.gdshader")
const CHAMBERS := 6
## Secondi dell'animazione Ricarica (a velocità normale) in cui escono i bossoli
## e in cui le cartucce iniziano e finiscono di entrare.
const EJECT_TIME := 0.9
const LOAD_START := 2.3
const LOAD_END := 3.2
## Secondi dell'accensione dei LED quando si prende in mano.
const BOOT_TIME := 0.45
## Giri al secondo della "diagnostica" dell'ispezione.
const SCAN_SPEED := 2.0

var _weapon: Weapon
## L'ultimo sparo ha girato il tamburo di una camera (vale finché l'animazione
## non riparte da capo e lo riporta a zero).
var _drum_turned := false
var _boot_left := 0.0
var _time := 0.0
## Ricarica arrivata durante uno sparo: parte quando lo sparo finisce, e deve
## finire all'istante _reload_end (sul tempo _time).
var _reload_queued := false
var _reload_end := 0.0

@onready var _anim: AnimationPlayer = $Model/AnimationPlayer
@onready var _drum_leds: ShaderMaterial = _led_material($Model/Magnum/Gru/Tamburo, 2, 0)
@onready var _frame_leds: ShaderMaterial = _led_material($Model/Magnum/Fusto, 3, 1)


func _ready() -> void:
	# Come le altre armi in prima persona: niente ombre del modello sulla scena.
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D"):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anim.get_animation("Riposo").loop_mode = Animation.LOOP_LINEAR
	_anim.animation_finished.connect(_on_animation_finished)
	_play("Riposo")


## Le animazioni sono del modello: l'arma non deve aggiungere le sue.
func has_own_animations() -> bool:
	return true


func on_equip(weapon: Weapon) -> void:
	_weapon = weapon
	_boot_left = BOOT_TIME
	_reload_queued = false
	_play("Riposo")


func on_fire() -> void:
	_reload_queued = false
	# L'animazione deve finire prima del colpo successivo, anche con i boost.
	var interval := 1.0 / maxf(_weapon.data.fire_rate * _weapon.fire_rate_multiplier, 0.01)
	_play("Sparo", maxf(1.0, _anim.get_animation("Sparo").length / interval))
	_drum_turned = true


## La ricarica dura duration secondi: l'animazione si adatta. Se sta ancora
## finendo lo sparo, parte subito dopo e recupera il tempo.
func on_reload(duration: float) -> void:
	if _anim.current_animation == "Sparo":
		_reload_queued = true
		_reload_end = _time + duration
	else:
		_play("Ricarica", _anim.get_animation("Ricarica").length / maxf(duration, 0.05))


func on_inspect() -> void:
	if _anim.current_animation == "Riposo" and not _reload_queued:
		_play("Ispezione")


func _play(animation: String, speed := 1.0) -> void:
	_drum_turned = false
	_anim.stop()
	_anim.play(animation, -1.0, speed)


func _on_animation_finished(animation: StringName) -> void:
	if _reload_queued:
		_reload_queued = false
		_play("Ricarica", _anim.get_animation("Ricarica").length / maxf(_reload_end - _time, 0.05))
	elif animation != &"Riposo":
		_play("Riposo")


func _process(delta: float) -> void:
	_time += delta
	_boot_left -= delta
	var rounds := clampi(_weapon.ammo(), 0, CHAMBERS) if _weapon else CHAMBERS
	_drum_leds.set_shader_parameter("lit_mask", _drum_mask(rounds))
	_frame_leds.set_shader_parameter("lit_mask", _frame_mask(rounds))


## LED del tamburo: quali camere hanno il colpo, viste dal tamburo così com'è
## adesso (girato o no dall'ultimo sparo).
func _drum_mask(rounds: int) -> int:
	match _anim.current_animation:
		"Ispezione":
			return 1 << (int(_time * SCAN_SPEED * CHAMBERS) % CHAMBERS)
		"Ricarica":
			var loading := _loading_count()
			if loading >= 0:
				return _first(loading)
	var offset := 1 if _drum_turned else 0
	var mask := 0
	for i in _booting(rounds):
		mask |= 1 << ((i + offset) % CHAMBERS)
	return mask


## Striscia del fusto: i colpi rimasti, che si spengono dal davanti; l'ultimo
## colpo lampeggia.
func _frame_mask(rounds: int) -> int:
	match _anim.current_animation:
		"Ispezione":
			# Va e viene da un capo all'altro.
			var step := int(_time * SCAN_SPEED * CHAMBERS) % (CHAMBERS * 2 - 2)
			return 1 << (step if step < CHAMBERS else CHAMBERS * 2 - 2 - step)
		"Ricarica":
			var loading := _loading_count()
			if loading >= 0:
				return _last(loading)
	var count := _booting(rounds)
	if count == 1 and _boot_left <= 0.0 and fmod(_time, 0.5) < 0.25:
		return 0
	return _last(count)


## In ricarica: quanti LED accesi (0 dopo l'espulsione dei bossoli, poi sempre
## di più mentre entrano le cartucce), o -1 se i bossoli non sono ancora usciti.
func _loading_count() -> int:
	var t := _anim.current_animation_position
	if t < EJECT_TIME:
		return -1
	if t < LOAD_START:
		return 0
	return clampi(int((t - LOAD_START) / (LOAD_END - LOAD_START) * CHAMBERS) + 1, 0, CHAMBERS)


## Durante l'avvio i LED si accendono uno alla volta, fino ai colpi rimasti.
func _booting(rounds: int) -> int:
	if _boot_left <= 0.0:
		return rounds
	return mini(rounds, int((1.0 - _boot_left / BOOT_TIME) * CHAMBERS) + 1)


func _first(count: int) -> int:
	return (1 << count) - 1


func _last(count: int) -> int:
	return _first(CHAMBERS) & ~_first(CHAMBERS - count)


## Mette lo shader dei LED al posto del materiale luminoso della superficie,
## con gli stessi colori.
func _led_material(mesh: MeshInstance3D, surface: int, led_layout: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = LED_SHADER
	material.set_shader_parameter("layout", led_layout)
	var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
	if original:
		material.set_shader_parameter("on_color", original.albedo_color)
		material.set_shader_parameter("energy", original.emission_energy_multiplier)
	mesh.set_surface_override_material(surface, material)
	return material
