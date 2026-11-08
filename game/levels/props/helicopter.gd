class_name Helicopter
extends Node3D
## L'elicottero per tornare a casa: la fine della run (provvisoria).
## Il nodo sta sull'eliporto; la radio dell'esercito è un po' più in là
## (radio_offset).
## 1. Alla radio chiunque versa soldi nella cassa comune, deposit alla volta,
##    fino a price.
## 2. Raggiunta la cifra l'elicottero è chiamato: bisogna resistere
##    arrival_time secondi; negli ultimi secondi scende sull'eliporto.
## 3. Atterrato, si sale con E (chi è in piedi). Dal primo che sale ci sono
##    boarding_time secondi per gli altri; se salgono tutti quelli in piedi
##    parte subito.
## 4. Riparte e la run è vinta per chi è a bordo (RunManager.host_win).
##
## La forma (greybox) si costruisce qui. In rete decide l'host; gli altri
## ricevono fase, soldi raccolti e secondi rimasti (anche chi entra dopo).

## La fase o i soldi raccolti sono cambiati.
signal state_changed

enum Phase { WAITING, INCOMING, LANDED, DEPARTING, GONE }

const BODY_COLOR := Color(0.33, 0.4, 0.27)
const DARK_COLOR := Color(0.14, 0.15, 0.16)
const GLASS_COLOR := Color(0.55, 0.75, 0.85)
const SEATS := [Vector3(-0.55, 0.45, 0.6), Vector3(0.55, 0.45, 0.6), Vector3(-0.55, 0.45, -0.6), Vector3(0.55, 0.45, -0.6)]

## Soldi da raccogliere tutti insieme per chiamarlo.
@export var price := 5000
## Soldi versati a ogni pressione di E (o quelli che restano, se meno).
@export var deposit := 500
## Secondi da resistere dopo la chiamata.
@export var arrival_time := 60.0
## Secondi in cui scende, alla fine dell'attesa.
@export var descent_time := 8.0
## Da dove scende, sopra l'eliporto.
@export var descent_height := 45.0
## Secondi per salire, dal primo che sale.
@export var boarding_time := 20.0
## Secondi della ripartenza prima della vittoria.
@export var departure_time := 4.0
## Posizione della radio rispetto all'elicottero.
@export var radio_offset := Vector3(-12.0, 0.0, 12.0)

var phase := Phase.WAITING
## Soldi raccolti finora.
var fund := 0

var _time_left := 0.0
var _body := Node3D.new()
var _rotor := Node3D.new()
var _cabin := HelicopterPart.new()
var _cabin_shape := CollisionShape3D.new()
var _seats: Array[Marker3D] = []


func _ready() -> void:
	add_to_group("helicopters")
	_build()
	_apply_phase()
	if multiplayer.is_server() and NetSession.is_online():
		multiplayer.peer_connected.connect(func(id: int): _receive_state.rpc_id(id, phase, fund, _time_left))


## L'elicottero del livello, o null.
static func of(node: Node) -> Helicopter:
	return node.get_tree().get_first_node_in_group("helicopters")


## Secondi rimasti nella fase in corso (arrivo, imbarco).
func seconds_left() -> float:
	return maxf(_time_left, 0.0)


## Testo per l'HUD: a che punto è l'elicottero ("" = niente da dire).
func status_text() -> String:
	match phase:
		Phase.WAITING:
			return "Elicottero: %d / %d €" % [fund, price] if fund > 0 else ""
		Phase.INCOMING:
			return "Elicottero in arrivo tra %s" % PlayerHud.format_time(ceilf(seconds_left()))
		Phase.LANDED:
			return "Elicottero sul tetto: salite!" + (" Parte tra %d" % ceili(seconds_left()) if _anyone_aboard() else "")
		Phase.DEPARTING:
			return "Si torna a casa!"
	return ""


func part_text(role: HelicopterPart.Role, player: FpsController) -> String:
	if role == HelicopterPart.Role.RADIO:
		if phase != Phase.WAITING:
			return ""
		var give := mini(deposit, price - fund)
		var text := "Chiama l'elicottero: versa [color=#ffd24a]%d €[/color]  (%d / %d)" % [give, fund, price]
		if player.inventory().money <= 0:
			text += "  [color=#ff8877](non hai soldi)[/color]"
		return text
	if phase == Phase.LANDED and player.is_standing() and not player.is_boarded():
		return "Sali a bordo"
	return ""


## Sull'host.
func part_interact(role: HelicopterPart.Role, player: FpsController) -> void:
	if role == HelicopterPart.Role.RADIO:
		_host_deposit(player)
	elif phase == Phase.LANDED and player.is_standing() and not player.is_boarded():
		_host_board(player)


## Sull'host, a inizio run: niente soldi raccolti, nessun elicottero.
func host_reset() -> void:
	fund = 0
	_set_phase(Phase.WAITING, 0.0)


func _host_deposit(player: FpsController) -> void:
	if phase != Phase.WAITING:
		return
	var give := mini(mini(deposit, price - fund), player.inventory().money)
	if give <= 0 or not player.inventory().host_spend(give):
		return
	fund += give
	if fund >= price:
		_set_phase(Phase.INCOMING, arrival_time)
		for p in _players():
			p.inventory().host_notice("Elicottero chiamato! Resistete %d secondi" % roundi(arrival_time))
	else:
		_publish()


func _host_board(player: FpsController) -> void:
	var taken: Array[Node3D] = []
	for p in _players():
		if p.is_boarded():
			taken.append(p._seat)
	for seat in _seats:
		if not taken.has(seat):
			var first := taken.is_empty()
			player.host_board(seat)
			if first:
				_time_left = boarding_time
				_publish()
			return


func _physics_process(delta: float) -> void:
	_time_left -= delta
	match phase:
		Phase.INCOMING:
			var t := clampf(1.0 - _time_left / descent_time, 0.0, 1.0)
			_body.position.y = descent_height * (1.0 - t * t * (3.0 - 2.0 * t))
		Phase.DEPARTING:
			var t := clampf(1.0 - _time_left / departure_time, 0.0, 1.0)
			_body.position = Vector3(0.0, descent_height * t * t, -30.0 * t * t)
	if not multiplayer.is_server():
		return
	match phase:
		Phase.INCOMING:
			if _time_left <= 0.0:
				_set_phase(Phase.LANDED, 0.0)
		Phase.LANDED:
			if _anyone_aboard() and (_time_left <= 0.0 or _everyone_standing_aboard()):
				_set_phase(Phase.DEPARTING, departure_time)
		Phase.DEPARTING:
			if _time_left <= 0.0:
				var names: Array[String] = []
				for p in _players():
					if p.is_boarded():
						names.append(p.display_name())
				_set_phase(Phase.GONE, 0.0)
				var run := RunManager.of(self)
				if run:
					run.host_win(names)


func _process(delta: float) -> void:
	if phase != Phase.WAITING and phase != Phase.GONE:
		_rotor.rotate_y(delta * 18.0)


func _anyone_aboard() -> bool:
	return _players().any(func(p: FpsController): return p.is_boarded())


func _everyone_standing_aboard() -> bool:
	return _players().all(func(p: FpsController): return p.is_boarded() or not p.is_standing())


func _players() -> Array[FpsController]:
	var result: Array[FpsController] = []
	for p in get_tree().get_nodes_in_group("players"):
		if p is FpsController and not p.is_queued_for_deletion():
			result.append(p)
	return result


func _set_phase(new_phase: Phase, time_left: float) -> void:
	phase = new_phase
	_time_left = time_left
	_apply_phase()
	_publish()


func _publish() -> void:
	state_changed.emit()
	if NetSession.is_online():
		_receive_state.rpc(phase, fund, _time_left)


@rpc("authority", "call_remote", "reliable")
func _receive_state(new_phase: int, new_fund: int, time_left: float) -> void:
	phase = new_phase as Phase
	fund = new_fund
	_time_left = time_left
	_apply_phase()
	state_changed.emit()


## Forma e collisione secondo la fase: in attesa e ripartito non c'è; in
## arrivo scende; atterrato blocca il passaggio e si può salire.
func _apply_phase() -> void:
	_body.visible = phase != Phase.WAITING and phase != Phase.GONE
	_cabin_shape.set_deferred("disabled", phase != Phase.LANDED)
	match phase:
		Phase.WAITING, Phase.GONE:
			_body.position = Vector3(0.0, descent_height, 0.0)
		Phase.LANDED:
			_body.position = Vector3.ZERO
		Phase.INCOMING:
			_body.position.y = descent_height


## I pezzi che si usano in rete (radio, cabina, posti) hanno nomi fissi: le
## richieste dei client e i posti a bordo si ritrovano per percorso.
func _build() -> void:
	_body.name = "Corpo"
	_rotor.name = "Rotore"
	add_child(_body)
	_box(_body, Vector3(0, 1.3, 0), Vector3(2.6, 2.2, 5.0), BODY_COLOR)          # cabina
	_box(_body, Vector3(0, 1.6, -2.7), Vector3(2.2, 1.4, 0.6), GLASS_COLOR)      # vetro davanti
	_box(_body, Vector3(0, 1.6, 5.0), Vector3(0.7, 0.7, 5.5), BODY_COLOR)        # coda
	_box(_body, Vector3(0, 2.6, 7.4), Vector3(0.15, 1.6, 0.9), BODY_COLOR)       # deriva
	for x in [-1.1, 1.1]:
		_box(_body, Vector3(x, 0.08, 0), Vector3(0.15, 0.15, 4.4), DARK_COLOR)  # pattini
	_rotor.position = Vector3(0, 2.75, 0)
	_body.add_child(_rotor)
	_box(_rotor, Vector3.ZERO, Vector3(0.4, 0.3, 0.4), DARK_COLOR)
	for angle in [0.0, PI / 2.0]:
		var blade := _box(_rotor, Vector3(0, 0.12, 0), Vector3(0.3, 0.05, 11.0), DARK_COLOR)
		blade.rotation.y = angle
	for i in SEATS.size():
		var seat := Marker3D.new()
		seat.name = "Posto%d" % (i + 1)
		seat.position = SEATS[i]
		_body.add_child(seat)
		_seats.append(seat)
	# La cabina: si guarda per salire, e da atterrato blocca.
	_cabin.name = "Cabina"
	_cabin.helicopter = self
	_cabin.role = HelicopterPart.Role.CABIN
	_cabin.collision_layer = 1 | 16
	_cabin.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 2.2, 5.0)
	_cabin_shape.shape = shape
	_cabin_shape.position.y = 1.3
	_cabin.add_child(_cabin_shape)
	_body.add_child(_cabin)
	# La radio dell'esercito, sempre lì.
	var radio := HelicopterPart.new()
	radio.name = "Radio"
	radio.helicopter = self
	radio.role = HelicopterPart.Role.RADIO
	radio.collision_layer = 1 | 16
	radio.collision_mask = 0
	radio.position = radio_offset
	var radio_shape := CollisionShape3D.new()
	var radio_box := BoxShape3D.new()
	radio_box.size = Vector3(1.0, 1.4, 0.6)
	radio_shape.shape = radio_box
	radio_shape.position.y = 0.7
	radio.add_child(radio_shape)
	add_child(radio)
	_box(radio, Vector3(0, 0.7, 0), Vector3(1.0, 1.4, 0.6), BODY_COLOR)
	_box(radio, Vector3(0, 1.2, -0.31), Vector3(0.7, 0.35, 0.04), Color(0.2, 0.9, 0.5))
	_box(radio, Vector3(0.3, 2.0, 0), Vector3(0.05, 1.2, 0.05), DARK_COLOR)       # antenna
	var label := Label3D.new()
	label.text = "Radio dell'esercito\nElicottero: %d €" % price
	label.font_size = 64
	label.outline_size = 12
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.4, 0)
	radio.add_child(label)


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	mesh.material = material
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	return node
