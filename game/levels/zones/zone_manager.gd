class_name ZoneManager
extends Node3D
## Le zone della mappa (figlie MapZone) e quali sono aperte. Divide il lavoro
## in "chunk": con al massimo 4 giocatori si lavora su al massimo 4 zone (più
## quelle accanto), anche se la mappa è grande.
## - Ondate: gli zombie escono solo nelle zone aperte dove c'è un giocatore o
##   accanto (nearby_zones); quelli rimasti lontani da tutti tornano in coda e
##   rinascono vicino ai giocatori (vedi WaveDirector).
## - Rete: ogni partecipante riceve solo gli zombie della zona del suo
##   giocatore, di quelle accanto e quelli entro relevance_radius (is_relevant).
##
## Le zone le apre l'host (porte comprate); gli altri ricevono l'elenco delle
## zone aperte, anche chi entra a partita iniziata.

## L'elenco delle zone aperte è cambiato.
signal unlocked_changed

## Entro questa distanza da un giocatore uno zombie gli arriva sempre in rete,
## anche se è in una zona non confinante (per esempio visto da una terrazza).
@export var relevance_radius := 45.0


func _ready() -> void:
	add_to_group("zone_manager")
	for zone in zones():
		zone.unlocked = zone.start_unlocked
	if multiplayer.is_server() and NetSession.is_online():
		multiplayer.peer_connected.connect(func(id: int): _receive_unlocked.rpc_id(id, unlocked_names()))


## Il gestore delle zone del livello, o null se il livello non ha zone.
static func of(node: Node) -> ZoneManager:
	if not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group("zone_manager")


func zones() -> Array[MapZone]:
	var result: Array[MapZone] = []
	for child in get_children():
		if child is MapZone:
			result.append(child)
	return result


func zone(zone_name: StringName) -> MapZone:
	return get_node_or_null(NodePath(zone_name)) as MapZone


## La zona che contiene point, o null.
func zone_at(point: Vector3) -> MapZone:
	for z in zones():
		if z.contains(point):
			return z
	return null


func unlocked_names() -> Array[StringName]:
	var result: Array[StringName] = []
	for z in zones():
		if z.unlocked:
			result.append(StringName(z.name))
	return result


## La zona di point e quelle confinanti (vuoto se point è fuori da tutte).
func nearby_zones(point: Vector3) -> Array[MapZone]:
	var result: Array[MapZone] = []
	var here := zone_at(point)
	if here == null:
		return result
	result.append(here)
	for neighbor_name in here.neighbors:
		var neighbor := zone(neighbor_name)
		if neighbor and not result.has(neighbor):
			result.append(neighbor)
	return result


## Le zone dove gli zombie possono uscire adesso: aperte e con un giocatore
## vivo dentro o accanto. Con 4 giocatori sono al massimo 4 zone più le vicine.
func spawn_zones(players: Array[Node3D]) -> Array[MapZone]:
	var result: Array[MapZone] = []
	for player in players:
		for z in nearby_zones(player.global_position):
			if z.unlocked and not result.has(z):
				result.append(z)
	return result


## Sull'host: vero se lo zombie in point deve arrivare in rete al partecipante
## peer (il suo giocatore è nella stessa zona, in una accanto o abbastanza vicino).
func is_relevant(peer: int, point: Vector3) -> bool:
	var player := _player_of(peer)
	if player == null:
		return true
	if player.global_position.distance_to(point) <= relevance_radius:
		return true
	var there := zone_at(point)
	return there == null or nearby_zones(player.global_position).has(there)


## Sull'host: apre la zona e lo dice a tutti.
func host_unlock(zone_name: StringName) -> void:
	var z := zone(zone_name)
	if z == null or z.unlocked:
		return
	z.unlocked = true
	unlocked_changed.emit()
	if NetSession.is_online():
		_receive_unlocked.rpc(unlocked_names())


## Sull'host, a inizio run: aperte solo le zone di partenza, porte chiuse.
func host_reset() -> void:
	for z in zones():
		z.unlocked = z.start_unlocked
	for door in get_tree().get_nodes_in_group("zone_doors"):
		door.host_reset()
	unlocked_changed.emit()
	if NetSession.is_online():
		_receive_unlocked.rpc(unlocked_names())


@rpc("authority", "call_remote", "reliable")
func _receive_unlocked(names: Array) -> void:
	for z in zones():
		z.unlocked = names.has(StringName(z.name)) or names.has(String(z.name))
	unlocked_changed.emit()


func _player_of(peer: int) -> Node3D:
	for player in get_tree().get_nodes_in_group("players"):
		if player.get_multiplayer_authority() == peer:
			return player
	return null
