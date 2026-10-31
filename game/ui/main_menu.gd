extends Control
## Menu iniziale: giocare da soli, ospitare una partita o entrare in quella di
## un amico con il suo indirizzo IP.

const LEVEL_SCENE := "res://game/levels/test_level.tscn"

@onready var _address: LineEdit = %Address
@onready var _status: Label = %Status


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_address.text = NetSession.address
	_status.text = NetSession.message
	NetSession.message = ""
	%Solo.pressed.connect(_start.bind(NetSession.Mode.OFFLINE))
	%Host.pressed.connect(_start.bind(NetSession.Mode.HOST))
	%Join.pressed.connect(_start.bind(NetSession.Mode.JOIN))
	%Quit.pressed.connect(get_tree().quit)
	%Host.text = "Ospita partita (porta %d)" % NetSession.DEFAULT_PORT
	%Solo.grab_focus()


func _start(mode: NetSession.Mode) -> void:
	if mode == NetSession.Mode.JOIN and _address.text.strip_edges().is_empty():
		_status.text = "Scrivi l'indirizzo IP dell'host."
		return
	NetSession.mode = mode
	NetSession.address = _address.text.strip_edges()
	NetSession.port = NetSession.DEFAULT_PORT
	get_tree().change_scene_to_file(LEVEL_SCENE)
