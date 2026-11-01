class_name HealthComponent
extends Node
## Vita di qualsiasi cosa possa subire danni: giocatori, nemici, bersagli.
##
## Si aggiunge come nodo figlio del corpo che viene colpito; chi spara la trova
## con HealthComponent.of(corpo_colpito).
## In rete la vita la decide solo l'host, anche quella dei giocatori: sugli
## altri take_damage(), heal() e reset() non fanno nulla, e ogni cambiamento
## arriva dall'host con gli stessi segnali (lampi, barra della vita, morte).

signal damaged(amount: float, source: Node, hit_position: Vector3)
signal died(source: Node)
signal changed(current: float, maximum: float)

@export var max_health := 100.0

var current := 0.0
## Se impostato, modifica ogni danno in arrivo prima di applicarlo (corazze,
## punti deboli...). Riceve (amount, source, hit_position) e restituisce il
## danno da applicare.
var damage_filter: Callable


func _enter_tree() -> void:
	# Il corpo può appartenere a un altro partecipante (il giocatore), ma la
	# sua vita resta dell'host.
	set_multiplayer_authority(1, false)


func _ready() -> void:
	current = max_health


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


## Riporta la vita al massimo (per respawn e rinascite).
func reset() -> void:
	if is_multiplayer_authority():
		_set_current(max_health)


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


func _apply(value: float, dealt: float, source: Node, hit_position: Vector3) -> void:
	var was_alive := is_alive()
	current = value
	if dealt > 0.0:
		damaged.emit(dealt, source, hit_position)
	changed.emit(current, max_health)
	if was_alive and not is_alive():
		died.emit(source)
