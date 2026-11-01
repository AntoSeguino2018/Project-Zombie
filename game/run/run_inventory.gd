class_name RunInventory
extends Node
## Quello che un giocatore accumula durante la run: i suoi soldi (personali),
## i boost delle macchinette ancora attivi e gli oggetti passivi raccolti
## (ogni copia somma di nuovo il suo effetto). Si azzera quando la run riparte.
##
## Lo decide l'host, come la vita: sugli altri i metodi host_* non fanno nulla
## e i cambiamenti arrivano dall'host con gli stessi segnali. I timer dei boost
## scorrono su tutti allo stesso modo.

## I soldi sono cambiati di delta (positivo = guadagnati).
signal money_changed(money: int, delta: int)
signal boosts_changed
## È arrivato un oggetto (o una sua copia in più).
signal items_changed
## Un messaggio per chi controlla il giocatore (es. "Servono 100 €").
signal notice(text: String)

var money := 0
## Boost attivi: percorso della risorsa Boost -> secondi rimasti.
var boosts := {}
## Oggetti passivi: percorso della risorsa PassiveItem -> copie.
var items := {}

## Risorse di oggetti e boost già caricate (percorso -> risorsa). Vanno tenute:
## altrimenti Godot le scarica e ogni load() le rilegge dal disco, che a ogni
## tick e per ogni oggetto faceva crollare gli FPS.
var _resources := {}
## Totale degli oggetti per ogni statistica, ricalcolato quando cambiano.
var _stats := {}


func _enter_tree() -> void:
	# Il giocatore appartiene al suo partecipante, l'inventario resta dell'host.
	set_multiplayer_authority(1, false)


func _ready() -> void:
	if not multiplayer.is_server():
		# Chi entra a partita iniziata chiede soldi e boost di questo giocatore.
		_request_state.rpc_id(1)


## L'inventario figlio diretto di node, o null se non c'è.
static func of(node: Node) -> RunInventory:
	for child in node.get_children():
		if child is RunInventory:
			return child
	return null


func _process(delta: float) -> void:
	if boosts.is_empty():
		return
	var expired := false
	for path in boosts.keys():
		boosts[path] -= delta
		if boosts[path] <= 0.0:
			boosts.erase(path)
			expired = true
	if expired:
		boosts_changed.emit()


## Sull'host: aggiunge (o toglie, se negativo) soldi.
func host_add_money(amount: int) -> void:
	if is_multiplayer_authority() and amount != 0:
		_set_money(maxi(money + amount, 0), amount)


## Sull'host: spende amount se bastano; altrimenti avvisa il giocatore e
## restituisce false.
func host_spend(amount: int) -> bool:
	if not is_multiplayer_authority():
		return false
	if money < amount:
		host_notice("Servono %d € (ne hai %d)" % [amount, money])
		return false
	_set_money(money - amount, -amount)
	return true


## Sull'host: attiva boost (potency 2 = dose doppia). La cura è subito.
func host_apply_boost(boost: Boost, potency := 1.0) -> void:
	if not is_multiplayer_authority():
		return
	if boost.heal > 0.0:
		var health := HealthComponent.of(get_parent())
		if health:
			health.heal(boost.heal * potency)
	if boost.duration > 0.0:
		boosts[boost.resource_path] = boosts.get(boost.resource_path, 0.0) + boost.duration * potency
		_publish_boosts()


## Sull'host: aggiunge una copia di item e avvisa il giocatore.
func host_add_item(item: PassiveItem) -> void:
	if not is_multiplayer_authority():
		return
	items[item.resource_path] = items.get(item.resource_path, 0) + 1
	_publish_items()
	var count: int = items[item.resource_path]
	host_notice("%s%s: %s" % [item.display_name, " ×%d" % count if count > 1 else "", item.summary(count)])


## Copie possedute di item.
func item_count(item: PassiveItem) -> int:
	return items.get(item.resource_path, 0)


## Somma degli effetti degli oggetti sulla statistica stat_name (vedi PassiveItem).
func stat(stat_name: String) -> float:
	return _stats.get(stat_name, 0.0)


## La risorsa (PassiveItem o Boost) di path, caricata una volta sola.
func resource_for(path: String) -> Resource:
	if not _resources.has(path):
		_resources[path] = load(path)
	return _resources[path]


func _recompute_stats() -> void:
	_stats.clear()
	for path in items:
		var item: PassiveItem = resource_for(path)
		_stats[item.stat] = _stats.get(item.stat, 0.0) + item.per_stack * items[path]


## Sull'host: a inizio run, niente soldi, boost né oggetti.
func host_reset() -> void:
	if not is_multiplayer_authority():
		return
	_set_money(0, 0)
	boosts.clear()
	_publish_boosts()
	items.clear()
	_publish_items()


## Sull'host: mostra text a chi controlla questo giocatore.
func host_notice(text: String) -> void:
	var owner_id := get_parent().get_multiplayer_authority()
	if owner_id == multiplayer.get_unique_id():
		notice.emit(text)
	elif NetSession.is_online():
		_receive_notice.rpc_id(owner_id, text)


## Cadenza: boost attivi per oggetti.
func fire_rate_multiplier() -> float:
	var result := 1.0 + stat("fire_rate")
	for boost in active_boosts():
		result *= boost.fire_rate_multiplier
	return result


func reload_speed_multiplier() -> float:
	var result := 1.0 + stat("reload_speed")
	for boost in active_boosts():
		result *= boost.reload_speed_multiplier
	return result


## I boost attivi, come risorse.
func active_boosts() -> Array[Boost]:
	var result: Array[Boost] = []
	for path in boosts:
		result.append(resource_for(path))
	return result


func _set_money(value: int, delta: int) -> void:
	_apply_money(value, delta)
	if NetSession.is_online():
		_receive_money.rpc(value, delta)


@rpc("authority", "call_remote", "reliable")
func _receive_money(value: int, delta: int) -> void:
	_apply_money(value, delta)


func _apply_money(value: int, delta: int) -> void:
	money = value
	money_changed.emit(money, delta)


func _publish_boosts() -> void:
	boosts_changed.emit()
	if NetSession.is_online():
		_receive_boosts.rpc(boosts)


@rpc("authority", "call_remote", "reliable")
func _receive_boosts(new_boosts: Dictionary) -> void:
	# Solo boost delle macchinette: niente risorse caricate da percorsi qualsiasi.
	boosts = {}
	for path in new_boosts:
		if path is String and path.begins_with("res://game/boosts/"):
			boosts[path] = float(new_boosts[path])
	boosts_changed.emit()


func _publish_items() -> void:
	_recompute_stats()
	items_changed.emit()
	if NetSession.is_online():
		_receive_items.rpc(items)


@rpc("authority", "call_remote", "reliable")
func _receive_items(new_items: Dictionary) -> void:
	items = {}
	for path in new_items:
		if ItemCatalog.is_item(path):
			items[path] = int(new_items[path])
	_recompute_stats()
	items_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _receive_notice(text: String) -> void:
	notice.emit(text)


@rpc("any_peer", "call_remote", "reliable")
func _request_state() -> void:
	if multiplayer.is_server():
		var peer := multiplayer.get_remote_sender_id()
		_receive_money.rpc_id(peer, money, 0)
		_receive_boosts.rpc_id(peer, boosts)
		_receive_items.rpc_id(peer, items)
