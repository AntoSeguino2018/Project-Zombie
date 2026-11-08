class_name PlayerHud
extends CanvasLayer
## HUD del giocatore locale: mirino, barra della vita, munizioni e arma in mano,
## uccisioni e tempo della run, ondata in corso con gli zombie rimasti (o i
## secondi alla prossima), soldi (con i guadagni che compaiono e svaniscono),
## boost attivi con il tempo rimasto, oggetti passivi raccolti con il loro
## effetto totale, avvisi (es. soldi che non bastano),
## cosa si può fare con E, barra della rianimazione,
## direzione del danno, bordo rosso quando si subiscono danni (che resta acceso
## e pulsa con la vita bassa), comandi all'avvio, schermate di giocatore a
## terra, morto, di run persa e di run vinta (elicottero) con il riepilogo;
## accanto all'ondata, a che punto è l'elicottero. Con F3 mostra le statistiche
## delle prestazioni (FPS, fisica, zombie, detriti, cose a terra...).

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
var _waves: WaveDirector
var _run: RunManager
var _helicopter: Helicopter
var _inventory: RunInventory
var _gain_tween: Tween
var _debug_left := 0.0
var _debug_physics_frames := 0
var _debug_frames := 0
var _notice_tween: Tween
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
@onready var _revive_bar: ProgressBar = $ReviveBar
@onready var _money_label: Label = $MoneyLabel
@onready var _money_gain: Label = $MoneyGain
@onready var _boosts_label: RichTextLabel = $BoostsLabel
@onready var _notice_label: Label = $NoticeLabel
@onready var _items_label: RichTextLabel = $ItemsLabel
@onready var _debug_stats: Label = $DebugStats


func _ready() -> void:
	var tween := create_tween()
	tween.tween_interval(controls_time)
	tween.tween_property(_controls_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(_controls_label.hide)
	# Il giocatore può nascere prima che il livello abbia finito di prepararsi.
	_bind_waves.call_deferred()


func _bind_waves() -> void:
	_run = RunManager.of(self)
	if _run:
		_run.run_restarted.connect(hide_death)
	_helicopter = Helicopter.of(self)
	if _helicopter:
		_helicopter.state_changed.connect(_on_helicopter_changed)
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


func bind_inventory(inventory: RunInventory) -> void:
	_inventory = inventory
	inventory.money_changed.connect(_on_money_changed)
	inventory.notice.connect(show_notice)
	inventory.items_changed.connect(_update_items)
	_money_label.text = "%d €" % inventory.money
	_update_items()


## Oggetti raccolti, in alto a sinistra: nome, copie ed effetto totale.
func _update_items() -> void:
	var lines := PackedStringArray()
	for path in _inventory.items:
		var item: PassiveItem = _inventory.resource_for(path)
		var count: int = _inventory.items[path]
		lines.append("[color=#%s]%s[/color]%s  [color=#cccccc]%s[/color]" % [
				item.color.lightened(0.3).to_html(false), item.display_name,
				" ×%d" % count if count > 1 else "", item.summary(count)])
	_items_label.text = "
".join(lines)


func _on_money_changed(money: int, delta: int) -> void:
	_money_label.text = "%d €" % money
	if delta == 0:
		return
	_money_gain.text = ("+%d €" if delta > 0 else "−%d €") % absi(delta)
	_money_gain.add_theme_color_override("font_color",
			Color(1.0, 0.82, 0.29) if delta > 0 else Color(1.0, 0.45, 0.4))
	if _gain_tween:
		_gain_tween.kill()
	_money_gain.modulate.a = 1.0
	_gain_tween = create_tween()
	_gain_tween.tween_interval(0.8)
	_gain_tween.tween_property(_money_gain, "modulate:a", 0.0, 0.5)


## Messaggio breve sotto il centro dello schermo, che svanisce da solo.
func show_notice(text: String) -> void:
	_notice_label.text = text
	if _notice_tween:
		_notice_tween.kill()
	_notice_label.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(2.0)
	_notice_tween.tween_property(_notice_label, "modulate:a", 0.0, 0.6)


## Boost attivi, uno per riga, con il tempo rimasto.
func _update_boosts() -> void:
	if _inventory == null or _inventory.boosts.is_empty():
		_boosts_label.text = ""
		return
	var lines := PackedStringArray()
	for path in _inventory.boosts:
		var boost: Boost = _inventory.resource_for(path)
		lines.append("[color=#%s]%s[/color]  %s" % [boost.color.lightened(0.35).to_html(false),
				boost.display_name, format_time(ceilf(_inventory.boosts[path]))])
	_boosts_label.text = "
".join(lines)


## Arma bianca in mano: il suo nome, niente munizioni.
func show_melee(weapon: MeleeWeaponData) -> void:
	_weapon_label.text = weapon.display_name
	_weapon_label.modulate = MeleeCatalog.COLOR
	_ammo_display.visible = false


## Proiettile da carro armato in spalla: mani occupate.
func show_shell() -> void:
	_weapon_label.text = "Proiettile in spalla"
	_weapon_label.modulate = Color(1.0, 0.8, 0.4)
	_ammo_display.visible = false


## Di nuovo l'arma da fuoco in mano.
func show_guns(weapon: Weapon) -> void:
	_ammo_display.visible = crosshair.visible
	if weapon.data:
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


## Uccisioni e tempo della run in corso, in alto a destra.
func update_stats(kills: int, seconds: float) -> void:
	_stats_label.text = "%d uccisioni   %s" % [kills, format_time(seconds)]


## Segna un colpo arrivato dal punto from (in coordinate del mondo).
func show_damage_from(from: Vector3) -> void:
	_damage_indicator.show_hit(from)


func show_downed() -> void:
	_death_label.visible = true
	_set_alive_widgets(false)


## A terra: secondi prima di morire e, se qualcuno ci sta rianimando, a che punto è.
func update_bleed_out(seconds_left: float, revive_progress: float) -> void:
	if _run_is_lost():
		return
	if revive_progress > 0.0:
		_death_label.text = "A TERRA
Ti stanno rianimando..."
	else:
		_death_label.text = "A TERRA
Un compagno può rianimarti

Muori tra %d" % maxi(ceili(seconds_left), 1)
	_show_revive_bar(revive_progress)


func show_dead() -> void:
	_death_label.visible = true
	_set_alive_widgets(false)
	_show_revive_bar(0.0)
	if not _run_is_lost():
		_death_label.text = "SEI MORTO
Rinasci alla fine dell'ondata"


## Barra di chi sta rianimando un compagno.
func update_revive(player: FpsController) -> void:
	if player.life != FpsController.Life.ALIVE:
		return
	var target := player.reviving()
	if is_instance_valid(target) and target.life == FpsController.Life.DOWNED:
		show_prompt("Rianimando %s..." % target.display_name())
		_show_revive_bar(target.revive_progress)
	else:
		_show_revive_bar(0.0)


func _show_revive_bar(progress: float) -> void:
	_revive_bar.visible = progress > 0.0
	_revive_bar.value = progress


func _run_is_lost() -> bool:
	return is_instance_valid(_run) and _run.is_over()


func _update_run_lost() -> void:
	if not _run_is_lost():
		return
	if _run.won:
		_update_run_won()
		return
	_death_label.visible = true
	_set_alive_widgets(false)
	_show_revive_bar(0.0)
	var player := get_parent() as FpsController
	var reached := "Ondata %d" % _run.lost_wave if _run.lost_wave > 0 else "Prima della prima ondata"
	var record := "Record: ondata %d" % RunManager.best_wave if RunManager.best_wave > 0 else ""
	_death_label.text = "RUN PERSA
%s  ·  %d uccisioni
%s

Si riparte tra %d" % [
			reached, player.kills() if player else 0, record, maxi(ceili(_run.restart_seconds_left()), 1)]


## Riepilogo della vittoria: chi si è salvato e le statistiche della run.
func _update_run_won() -> void:
	_death_label.visible = true
	_set_alive_widgets(false)
	_show_revive_bar(0.0)
	var player := get_parent() as FpsController
	var saved := ", ".join(_run.escaped) if not _run.escaped.is_empty() else "nessuno"
	var reached := "Ondata %d" % _run.won_wave if _run.won_wave > 0 else "Prima della prima ondata"
	_death_label.text = "SIETE TORNATI A CASA!
Salvati: %s
%s  ·  %d uccisioni  ·  %s

Si riparte tra %d" % [saved, reached, player.kills() if player else 0,
			format_time(player.run_time() if player else 0.0), maxi(ceili(_run.restart_seconds_left()), 1)]


func _on_helicopter_changed() -> void:
	if _helicopter.phase == Helicopter.Phase.INCOMING:
		_show_banner("Elicottero chiamato!")
	elif _helicopter.phase == Helicopter.Phase.LANDED:
		_show_banner("L'elicottero è sul tetto!")


static func format_time(seconds: float) -> String:
	var total := floori(seconds)
	return "%d:%02d" % [floori(total / 60.0), total % 60]


func hide_death() -> void:
	_death_label.visible = false
	_show_revive_bar(0.0)
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
	var helicopter_text := _helicopter.status_text() if is_instance_valid(_helicopter) else ""
	if not helicopter_text.is_empty():
		_wave_label.text += "   ·   " + helicopter_text


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("toggle_stats"):
		_debug_stats.visible = not _debug_stats.visible
		# Il tempo di disegno della scheda video si misura solo a pannello aperto.
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), _debug_stats.visible)
		_debug_physics_frames = Engine.get_physics_frames()
		_debug_frames = Engine.get_process_frames()


## Statistiche delle prestazioni, aggiornate 4 volte al secondo.
func _update_debug_stats(delta: float) -> void:
	_debug_left -= delta
	if not _debug_stats.visible or _debug_left > 0.0:
		return
	_debug_left = 0.25
	var tree := get_tree()
	var rubble := RubbleField.of(self)
	var viewport := get_viewport().get_viewport_rid()
	# Passi di fisica per frame: più di 1 vuol dire che il gioco sta recuperando
	# frame lenti (e la fisica sembra costare di più perché si somma).
	var frames := maxi(Engine.get_process_frames() - _debug_frames, 1)
	var steps := float(Engine.get_physics_frames() - _debug_physics_frames) / frames
	_debug_frames = Engine.get_process_frames()
	_debug_physics_frames = Engine.get_physics_frames()
	_debug_stats.text = "
".join([
		"%d FPS  ·  frame %.1f ms" % [Performance.get_monitor(Performance.TIME_FPS),
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0],
		"fisica %.1f ms  ·  %.1f passi per frame" % [Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, steps],
		"disegno: CPU %.1f ms  ·  scheda video %.1f ms" % [RenderingServer.viewport_get_measured_render_time_cpu(viewport),
				RenderingServer.viewport_get_measured_render_time_gpu(viewport)],
		"zombie %d" % tree.get_nodes_in_group("enemies").size(),
		"detriti in movimento %d  ·  macerie %d" % [rubble.active_count(), rubble.rubble_count()],
		"armi a terra %d  ·  oggetti a terra %d" % [tree.get_nodes_in_group("weapon_pickups").size(),
				tree.get_nodes_in_group("item_pickups").size()],
		"nodi %d  ·  disegnati %d  ·  draw call %d" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)],
	])


func _process(delta: float) -> void:
	_time += delta
	_update_debug_stats(delta)
	_update_wave_label()
	_update_run_lost()
	_update_boosts()
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
