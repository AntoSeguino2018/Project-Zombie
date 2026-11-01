class_name PlayerHud
extends CanvasLayer
## HUD del giocatore locale: mirino, barra della vita, munizioni e arma in mano,
## uccisioni e tempo di sopravvivenza, ondata in corso con gli zombie rimasti
## (o i secondi alla prossima), cosa si può fare con E, direzione del
## danno, bordo rosso quando
## si subiscono danni (che resta acceso e pulsa con la vita bassa), comandi
## all'avvio e schermata di morte con il riepilogo e il conto alla rovescia.

## Sotto questa frazione di vita il bordo rosso resta acceso.
@export_range(0.0, 1.0) var low_health_fraction := 0.3
## Quanto si accende il bordo: danno subito in frazione della vita, moltiplicato.
@export var flash_per_damage := 4.0
## Velocità con cui il bordo si spegne dopo un colpo, al secondo.
@export var flash_fade := 2.5
## Secondi in cui restano visibili i comandi all'avvio, prima di svanire.
@export var controls_time := 10.0

var _health: HealthComponent
var _flash := 0.0
var _time := 0.0
var _death_summary := ""
var _waves: WaveDirector
var _banner_tween: Tween

@onready var crosshair: Crosshair = $Crosshair
@onready var _health_bar: HealthBar = $HealthBar
@onready var _vignette: ShaderMaterial = $DamageFlash.material
@onready var _death_label: Label = $DeathLabel
@onready var _weapon_label: Label = $WeaponLabel
@onready var _ammo_display: AmmoDisplay = $AmmoDisplay
@onready var _damage_indicator: DamageIndicator = $DamageIndicator
@onready var _stats_label: Label = $StatsLabel
@onready var _controls_label: Label = $ControlsLabel
@onready var _prompt: RichTextLabel = $InteractPrompt
@onready var _wave_label: Label = $WaveLabel
@onready var _wave_banner: Label = $WaveBanner


func _ready() -> void:
	var tween := create_tween()
	tween.tween_interval(controls_time)
	tween.tween_property(_controls_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(_controls_label.hide)
	# Il giocatore può nascere prima che il livello abbia finito di prepararsi.
	_bind_waves.call_deferred()


func _bind_waves() -> void:
	_waves = WaveDirector.of(self)
	if _waves == null:
		return
	_waves.wave_started.connect(func(wave: int): _show_banner("ONDATA %d" % wave))
	_waves.wave_cleared.connect(func(wave: int): _show_banner("Ondata %d superata!" % wave))


func bind(health: HealthComponent) -> void:
	_health = health
	health.changed.connect(_health_bar.set_health)
	health.damaged.connect(_on_damaged)
	_health_bar.set_health(health.current, health.max_health)


func bind_weapon(weapon: Weapon) -> void:
	_ammo_display.bind(weapon)
	weapon.equipped.connect(_show_weapon_name)
	_show_weapon_name(weapon.data)


## Nome dell'arma in mano, del colore della sua rarità.
func _show_weapon_name(data: WeaponData) -> void:
	_weapon_label.text = data.display_name
	_weapon_label.modulate = WeaponCatalog.rarity_color(data)


## Scritta "E ..." sotto il mirino; vuota la nasconde.
func show_prompt(text: String) -> void:
	_prompt.visible = text != ""
	if _prompt.visible:
		_prompt.text = "[center][color=#ffd24a]E[/color]  %s[/center]" % text


## Uccisioni e tempo di sopravvivenza della vita in corso, in alto a destra.
func update_stats(kills: int, seconds_alive: float) -> void:
	_stats_label.text = "%d uccisioni   %s" % [kills, format_time(seconds_alive)]


## Segna un colpo arrivato dal punto from (in coordinate del mondo).
func show_damage_from(from: Vector3) -> void:
	_damage_indicator.show_hit(from)


## Schermata di morte con il riepilogo della vita appena finita.
func show_death(kills: int, seconds_alive: float, best_seconds: float) -> void:
	_death_label.visible = true
	_death_summary = "Sopravvissuto %s  ·  %d uccisioni\nRecord %s" % [
			format_time(seconds_alive), kills, format_time(best_seconds)]
	_set_alive_widgets(false)


func update_respawn_countdown(seconds_left: float) -> void:
	_death_label.text = "SEI MORTO\n%s\n\nRinasci tra %d" % [
			_death_summary, maxi(ceili(seconds_left), 1)]


static func format_time(seconds: float) -> String:
	var total := floori(seconds)
	return "%d:%02d" % [floori(total / 60.0), total % 60]


func hide_death() -> void:
	_death_label.visible = false
	_set_alive_widgets(true)


## Mirino e arma si vedono solo da vivi.
func _set_alive_widgets(alive: bool) -> void:
	crosshair.visible = alive
	_ammo_display.visible = alive
	_weapon_label.visible = alive


## Scritta grande che compare e svanisce, per l'inizio e la fine delle ondate.
func _show_banner(text: String) -> void:
	_wave_banner.text = text
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_wave_banner, "modulate:a", 1.0, 0.2)
	_banner_tween.tween_interval(2.0)
	_banner_tween.tween_property(_wave_banner, "modulate:a", 0.0, 0.6)


func _update_wave_label() -> void:
	if not is_instance_valid(_waves):
		_wave_label.text = ""
	elif _waves.phase == WaveDirector.Phase.ACTIVE:
		_wave_label.text = "Ondata %d   ·   %d zombie" % [_waves.wave, _waves.remaining]
	else:
		_wave_label.text = "Ondata %d tra %d" % [_waves.wave + 1, ceili(_waves.seconds_to_next_wave())]


func _process(delta: float) -> void:
	_time += delta
	_update_wave_label()
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
