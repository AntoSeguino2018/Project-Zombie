class_name ZoneDoor
extends StaticBody3D
## Porta a pagamento tra due zone, come gli sblocchi di Black Ops: guardandola
## e premendo E la si compra (price, da chi la apre) e si abbassa nel
## pavimento; le zone in opens diventano aperte (ZoneManager), quindi lì
## possono uscire gli zombie. Chiusa blocca giocatori, zombie, colpi e la mappa
## di navigazione; aperta la navigazione si ricalcola e gli zombie ci passano.
##
## La forma si costruisce qui da size, così nel livello basta il nodo con lo
## script. In rete decide l'host; chi entra a partita iniziata riceve lo stato.

const DOOR_COLOR := Color(0.95, 0.7, 0.15)
const STRIPE_COLOR := Color(0.12, 0.12, 0.13)

## Soldi per aprirla.
@export var price := 250
## Zone che si aprono comprandola (nomi dei nodi MapZone).
@export var opens: Array[StringName] = []
## Larghezza, altezza e spessore della porta.
@export var size := Vector3(4.0, 3.2, 0.3)
## Testo sulla porta; vuoto = il nome della prima zona che apre.
@export var label := ""

var is_open := false

var _shape := CollisionShape3D.new()
var _panel := Node3D.new()
var _tween: Tween


func _ready() -> void:
	add_to_group("zone_doors")
	add_to_group("navigation_source")
	collision_layer = 1 | 16
	collision_mask = 0
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.position.y = size.y / 2.0
	add_child(_shape)
	_build_panel()
	if multiplayer.is_server() and NetSession.is_online():
		multiplayer.peer_connected.connect(func(id: int): _receive_open.rpc_id(id, is_open))


## Testo da mostrare quando il giocatore la guarda.
func interaction_text(player: FpsController) -> String:
	if is_open:
		return ""
	var text := "Apri: %s  [color=#ffd24a]%d €[/color]" % [_title(), price]
	var money := player.inventory().money
	if money < price:
		text += "  [color=#ff8877](hai %d €)[/color]" % money
	return text


## Sull'host: il giocatore la compra, se ha abbastanza soldi.
func interact(player: FpsController, _slot: int) -> void:
	if is_open or not player.inventory().host_spend(price):
		return
	_set_open(true)
	var zones := ZoneManager.of(self)
	if zones:
		for zone_name in opens:
			zones.host_unlock(zone_name)


## Sull'host, a inizio run: di nuovo chiusa.
func host_reset() -> void:
	if is_open:
		_set_open(false)


## Per la mappa di navigazione: chiusa è un muro.
func add_navigation_geometry(source: NavigationMeshSourceGeometryData3D) -> void:
	if is_open:
		return
	# Le facce calcolate qui (sulla CPU), non lette dalla scheda video.
	var mesh := BoxMesh.new()
	mesh.size = size
	source.add_mesh_array(mesh.get_mesh_arrays(), global_transform * Transform3D(Basis(), Vector3(0.0, size.y / 2.0, 0.0)))


func _title() -> String:
	if not label.is_empty():
		return label
	var zones := ZoneManager.of(self)
	var zone := zones.zone(opens[0]) if zones and not opens.is_empty() else null
	return zone.display_name if zone else "passaggio"


func _set_open(open: bool) -> void:
	_apply_open(open)
	if NetSession.is_online():
		_receive_open.rpc(open)


@rpc("authority", "call_remote", "reliable")
func _receive_open(open: bool) -> void:
	_apply_open(open)


func _apply_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	_shape.set_deferred("disabled", open)
	if _tween:
		_tween.kill()
	_panel.visible = true
	_tween = create_tween()
	# Scende nel pavimento (o risale), poi sparisce.
	_tween.tween_property(_panel, "position:y", -size.y - 0.1 if open else 0.0, 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if open else Tween.EASE_OUT)
	if open:
		_tween.tween_callback(func(): _panel.visible = false)
	# La navigazione la ricalcola l'host (gli zombie li muove lui).
	CombatEvents.bus.terrain_changed.emit(self)


func _build_panel() -> void:
	add_child(_panel)
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = DOOR_COLOR
	material.roughness = 0.7
	mesh.material = material
	body.mesh = mesh
	body.position.y = size.y / 2.0
	_panel.add_child(body)
	# Strisce scure in diagonale non servono in greybox: due fasce orizzontali.
	for y in [size.y * 0.25, size.y * 0.75]:
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(size.x + 0.02, 0.18, size.z + 0.02)
		var stripe_material := StandardMaterial3D.new()
		stripe_material.albedo_color = STRIPE_COLOR
		stripe_mesh.material = stripe_material
		stripe.mesh = stripe_mesh
		stripe.position.y = y
		_panel.add_child(stripe)
	# Il prezzo scritto su tutte e due le facce.
	for side in [1.0, -1.0]:
		var text := Label3D.new()
		text.text = "%s\n%d €" % [_title(), price]
		text.font_size = 72
		text.outline_size = 14
		text.modulate = Color(1, 1, 1)
		text.pixel_size = 0.006
		text.position = Vector3(0.0, size.y * 0.5, side * (size.z / 2.0 + 0.02))
		text.rotation.y = 0.0 if side > 0.0 else PI
		_panel.add_child(text)
