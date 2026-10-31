class_name PlayerSpawner
extends MultiplayerSpawner
## Avvia la sessione di rete all'apertura del livello e fa comparire un
## giocatore per ogni partecipante (da soli: uno solo).
##
## Solo l'host crea e toglie i giocatori; MultiplayerSpawner li replica sugli
## altri, con lo stesso nome (l'id del partecipante, che ne è il proprietario)
## e la stessa posizione di partenza. Va messo per primo nel livello: così la
## connessione esiste già quando si preparano gli altri nodi.

@export var player_scene: PackedScene
## Punto di partenza del primo giocatore; gli altri accanto, a spacing metri.
@export var spawn_origin := Vector3(0.0, 0.1, 0.0)
@export var spawn_spacing := 1.5

var _waiting: CanvasLayer


func _ready() -> void:
	spawn_function = _create_player
	var error := NetSession.start(multiplayer)
	if error != OK:
		NetSession.leave(get_tree(), "Impossibile avviare la partita (errore %d)." % error)
		return
	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_add_player)
		multiplayer.peer_disconnected.connect(_remove_player)
		_add_player(multiplayer.get_unique_id())
	else:
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
		spawned.connect(_on_spawned)
		_show_waiting("Connessione a %s:%d…" % [NetSession.address, NetSession.port])


func _add_player(peer_id: int) -> void:
	var players := get_node(spawn_path)
	if players.has_node(str(peer_id)):
		return
	var number := players.get_child_count() + 1
	var offset := Vector3((number - 1) * spawn_spacing, 0.0, 0.0)
	spawn([peer_id, number, spawn_origin + offset])


func _remove_player(peer_id: int) -> void:
	var player := get_node(spawn_path).get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


## Crea il giocatore su tutti i partecipanti, con gli stessi dati.
func _create_player(data: Array) -> Node:
	var player: FpsController = player_scene.instantiate()
	player.name = str(data[0])
	player.player_number = data[1]
	player.position = data[2]
	return player


func _on_spawned(node: Node) -> void:
	if node.name == str(multiplayer.get_unique_id()) and _waiting:
		_waiting.queue_free()
		_waiting = null


func _on_connection_failed() -> void:
	NetSession.leave(get_tree(), "Impossibile collegarsi a %s:%d." % [NetSession.address, NetSession.port])


func _on_server_disconnected() -> void:
	NetSession.leave(get_tree(), "L'host ha chiuso la partita.")


## Scritta al centro dello schermo mentre il client aspetta il suo giocatore.
func _show_waiting(text: String) -> void:
	_waiting = CanvasLayer.new()
	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	_waiting.add_child(label)
	add_child(_waiting)
