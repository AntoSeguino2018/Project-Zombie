class_name HealthComponent
extends Node
## Vita di qualsiasi cosa possa subire danni: giocatori, nemici, bersagli.
##
## Si aggiunge come nodo figlio del corpo che viene colpito; chi spara la trova
## con HealthComponent.of(corpo_colpito).
## Predisposto per la rete: in multiplayer solo l'host chiamerà take_damage()
## e i client riceveranno la vita sincronizzata.

signal damaged(amount: float, source: Node, hit_position: Vector3)
signal died(source: Node)
signal changed(current: float, maximum: float)

@export var max_health := 100.0

var current := 0.0


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


## Applica il danno e restituisce quanto ne è stato inflitto davvero
## (mai più della vita rimasta). source è chi ha causato il danno.
func take_damage(amount: float, source: Node = null, hit_position := Vector3.ZERO) -> float:
	if not is_alive() or amount <= 0.0:
		return 0.0
	var dealt := minf(amount, current)
	current -= dealt
	damaged.emit(dealt, source, hit_position)
	changed.emit(current, max_health)
	if not is_alive():
		died.emit(source)
	return dealt


func heal(amount: float) -> void:
	if not is_alive() or amount <= 0.0:
		return
	current = minf(current + amount, max_health)
	changed.emit(current, max_health)


## Riporta la vita al massimo (per respawn e rinascite).
func reset() -> void:
	current = max_health
	changed.emit(current, max_health)
