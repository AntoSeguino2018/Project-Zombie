class_name PlayerHud
extends CanvasLayer
## HUD del giocatore locale: mirino, barra della vita, bordo rosso quando si
## subiscono danni (che resta acceso e pulsa con la vita bassa) e schermata di
## morte con il conto alla rovescia.

## Sotto questa frazione di vita il bordo rosso resta acceso.
@export_range(0.0, 1.0) var low_health_fraction := 0.3
## Quanto si accende il bordo: danno subito in frazione della vita, moltiplicato.
@export var flash_per_damage := 4.0
## Velocità con cui il bordo si spegne dopo un colpo, al secondo.
@export var flash_fade := 2.5

var _health: HealthComponent
var _flash := 0.0
var _time := 0.0

@onready var crosshair: Crosshair = $Crosshair
@onready var _health_bar: HealthBar = $HealthBar
@onready var _vignette: ShaderMaterial = $DamageFlash.material
@onready var _death_label: Label = $DeathLabel


func bind(health: HealthComponent) -> void:
	_health = health
	health.changed.connect(_health_bar.set_health)
	health.damaged.connect(_on_damaged)
	_health_bar.set_health(health.current, health.max_health)


func show_death() -> void:
	_death_label.visible = true
	crosshair.visible = false


func update_respawn_countdown(seconds_left: float) -> void:
	_death_label.text = "SEI MORTO\nRinasci tra %d" % maxi(ceili(seconds_left), 1)


func hide_death() -> void:
	_death_label.visible = false
	crosshair.visible = true


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - flash_fade * delta, 0.0)
	var steady := 0.0
	if _health and not _health.is_alive():
		steady = 0.7
	elif _health:
		var fraction := _health.current / _health.max_health
		if fraction < low_health_fraction:
			steady = lerpf(0.25, 0.55, 1.0 - fraction / low_health_fraction) + 0.08 * sin(_time * 5.0)
	_vignette.set_shader_parameter("intensity", maxf(_flash, steady))


func _on_damaged(amount: float, _source: Node, _hit_position: Vector3) -> void:
	_flash = clampf(amount / _health.max_health * flash_per_damage, 0.35, 1.0)
