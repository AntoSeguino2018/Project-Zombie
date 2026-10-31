class_name NetSession
extends RefCounted
## Come avviare la prossima partita: da soli, come host o collegandosi a un
## host. Il menu sceglie la modalità, il livello avvia la connessione all'avvio
## (così il livello esiste già quando arrivano i giocatori dall'host).
## Modello di rete: ognuno muove il proprio giocatore, l'host decide tutto il
## resto (nemici, danni, distruzione, oggetti).

enum Mode { OFFLINE, HOST, JOIN }

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4
const MENU_SCENE := "res://game/ui/main_menu.tscn"

static var mode := Mode.OFFLINE
static var address := "127.0.0.1"
static var port := DEFAULT_PORT
## Messaggio da mostrare nel menu (es. il motivo di una disconnessione).
static var message := ""


## Avvia la sessione scelta sull'API multiplayer indicata.
static func start(api: MultiplayerAPI) -> Error:
	match mode:
		Mode.HOST:
			var peer := ENetMultiplayerPeer.new()
			var error := peer.create_server(port, MAX_PLAYERS - 1)
			if error != OK:
				return error
			api.multiplayer_peer = peer
		Mode.JOIN:
			var peer := ENetMultiplayerPeer.new()
			var error := peer.create_client(address, port)
			if error != OK:
				return error
			api.multiplayer_peer = peer
		_:
			api.multiplayer_peer = OfflineMultiplayerPeer.new()
	return OK


## Chiude la connessione e torna al menu, mostrando reason.
static func leave(tree: SceneTree, reason := "") -> void:
	message = reason
	mode = Mode.OFFLINE
	if tree.get_multiplayer().multiplayer_peer:
		tree.get_multiplayer().multiplayer_peer.close()
	tree.get_multiplayer().multiplayer_peer = OfflineMultiplayerPeer.new()
	tree.change_scene_to_file.call_deferred(MENU_SCENE)


static func is_online() -> bool:
	return mode != Mode.OFFLINE
