class_name HealthComponent
extends Node
## Vita di qualsiasi cosa possa subire danni: giocatori, nemici, bersagli.
##
## Si aggiunge come nodo figlio del corpo che viene colpito; chi spara la trova
## con HealthComponent.of(corpo_colpito).
## In rete la vita la decide solo l'host, anche quella dei giocatori: sugli
## altri take_damage(), heal() e reset() non fanno nulla, e ogni cambiamento
## arriva dall'host con gli stessi segnali (lampi, barra della vita, morte).
## Può anche bruciare (colpi incendiari): perde vita un po' alla volta finché
## il fuoco non si spegne, e intanto sopra il corpo si vedono le fiamme.

signal damaged(amount: float, source: Node, hit_position: Vector3)
signal died(source: Node)
signal changed(current: float, maximum: float)
signal burning_changed(burning: bool)

## Ogni quanti secondi il fuoco toglie vita.
const BURN_TICK := 0.5

@export var max_health := 100.0

var current := 0.0
## Se impostato, modifica ogni danno in arrivo prima di applicarlo (corazze,
## punti deboli...). Riceve (amount, source, hit_position) e restituisce il
## danno da applicare.
var damage_filter: Callable
## Vero mentre brucia (anche sugli altri partecipanti, per le fiamme).
var burning := false

var _burn_damage := 0.0
var _burn_left := 0.0
var _burn_tick_left := 0.0
var _burn_source: Node
var _flames: Node3D


func _enter_tree() -> void:
	# Il corpo può appartenere a un altro partecipante (il giocatore), ma la
	# sua vita resta dell'host.
	set_multiplayer_authority(1, false)


func _ready() -> void:
	current = max_health


func _physics_process(delta: float) -> void:
	if not burning or not is_multiplayer_authority():
		return
	_burn_left -= delta
	_burn_tick_left -= delta
	if _burn_tick_left <= 0.0:
		_burn_tick_left += BURN_TICK
		# Senza punto colpito: il fuoco passa sotto le corazze.
		take_damage(_burn_damage * BURN_TICK, _burn_source if is_instance_valid(_burn_source) else null)
	if _burn_left <= 0.0 and burning:
		_set_burning(false)


## Restituisce il componente vita figlio diretto di node, o null se non c'è.
static func of(node: Object) -> HealthComponent:
	if not node is Node:
		return null
	for child in node.get_children():
		if child is HealthComponent:
			return child
	return null


func is_alive() -> bool:
	return current > 0.0


## Applica il danno e restituisce quanto ne è stato inflitto davvero (dopo
## l'eventuale filtro, mai più della vita rimasta). source è chi ha causato il danno.
func take_damage(amount: float, source: Node = null, hit_position := Vector3.ZERO) -> float:
	if not is_multiplayer_authority():
		return 0.0
	if damage_filter.is_valid():
		amount = damage_filter.call(amount, source, hit_position)
	if not is_alive() or amount <= 0.0:
		return 0.0
	var dealt := minf(amount, current)
	_set_current(current - dealt, dealt, source, hit_position)
	return dealt


func heal(amount: float) -> void:
	if not is_multiplayer_authority() or not is_alive() or amount <= 0.0:
		return
	_set_current(minf(current + amount, max_health))


## Dà fuoco: damage_per_second per seconds secondi. Un nuovo fuoco allunga
## quello acceso e tiene il danno più alto, non si somma.
func ignite(damage_per_second: float, seconds: float, source: Node = null) -> void:
	if not is_multiplayer_authority() or not is_alive() or damage_per_second <= 0.0:
		return
	_burn_damage = maxf(_burn_damage, damage_per_second) if burning else damage_per_second
	_burn_left = maxf(_burn_left, seconds)
	_burn_source = source
	if not burning:
		_burn_tick_left = BURN_TICK
		_set_burning(true)


## Riporta la vita al massimo (per respawn e rinascite).
func reset() -> void:
	if is_multiplayer_authority():
		_set_current(max_health)


## Imposta la vita a value, anche da morti (per esempio quando si viene rianimati).
func restore(value: float) -> void:
	if is_multiplayer_authority():
		_set_current(clampf(value, 0.0, max_health))


## Cambia la vita, avvisa chi ascolta e, in rete, manda il cambiamento a tutti.
func _set_current(value: float, dealt := 0.0, source: Node = null, hit_position := Vector3.ZERO) -> void:
	_apply(value, dealt, source, hit_position)
	if NetSession.is_online():
		var source_path := source.get_path() if source and source.is_inside_tree() else NodePath()
		_receive.rpc(value, dealt, source_path, hit_position)


@rpc("authority", "call_remote", "reliable")
func _receive(value: float, dealt: float, source_path: NodePath, hit_position: Vector3) -> void:
	var source := get_node_or_null(source_path) if not source_path.is_empty() else null
	_apply(value, dealt, source, hit_position)


func _set_burning(on: bool) -> void:
	_apply_burning(on)
	if NetSession.is_online():
		_receive_burning.rpc(on)


@rpc("authority", "call_remote", "reliable")
func _receive_burning(on: bool) -> void:
	_apply_burning(on)


func _apply_burning(on: bool) -> void:
	if on == burning:
		return
	burning = on
	if on and _flames == null and get_parent() is Node3D:
		_flames = BurnFlames.new()
		get_parent().add_child(_flames)
	elif not on and _flames:
		_flames.queue_free()
		_flames = null
	burning_changed.emit(on)


func _apply(value: float, dealt: float, source: Node, hit_position: Vector3) -> void:
	var was_alive := is_alive()
	current = value
	if dealt > 0.0:
		damaged.emit(dealt, source, hit_position)
	changed.emit(current, max_health)
	if was_alive and not is_alive():
		if burning and is_multiplayer_authority():
			_set_burning(false)
		died.emit(source)
