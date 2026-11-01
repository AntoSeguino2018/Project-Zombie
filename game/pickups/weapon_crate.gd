class_name WeaponCrate
extends StaticBody3D
## Cassa delle armi: guardandola e premendo E la si apre pagando price e ne
## esce un'arma a caso (vedi WeaponCatalog.roll), che resta a fluttuare sopra
## finché qualcuno non la prende. Dopo refill_time secondi si richiude piena
## comunque: se l'arma è ancora lì, sparisce.
##
## In rete apertura, contenuto e richiusura li decide l'host; gli altri vedono
## il coperchio aprirsi e l'arma comparire (PickupReplicator).

## Soldi per aprirla (li paga chi la apre).
@export var price := 100
## Secondi dall'apertura prima che si richiuda (e si possa riaprire).
@export var refill_time := 60.0
## Altezza dell'arma che esce, sopra la base della cassa.
@export var pickup_height := 1.15
## Di quanto si apre il coperchio, in gradi.
@export var open_angle_degrees := 110.0

var is_open := false

var _refill_left := 0.0
var _pickup_id := 0
var _rng := RandomNumberGenerator.new()
var _lid_tween: Tween

@onready var _lid: Node3D = $LidPivot


func _ready() -> void:
	add_to_group("weapon_crates")
	_rng.randomize()
	if multiplayer.is_server() and NetSession.is_online():
		# Chi entra a partita iniziata vede le casse già aperte.
		multiplayer.peer_connected.connect(func(id: int): _receive_open.rpc_id(id, is_open))


func _physics_process(delta: float) -> void:
	if not is_open or not multiplayer.is_server():
		return
	_refill_left -= delta
	if _refill_left <= 0.0:
		var pickup := instance_from_id(_pickup_id) as Node
		if pickup and not pickup.is_queued_for_deletion():
			pickup.queue_free()
		_pickup_id = 0
		_set_open(false)


## Testo da mostrare quando il giocatore la guarda; vuoto = niente da fare.
func interaction_text(player: FpsController) -> String:
	if is_open:
		return ""
	var text := "Apri la cassa  [color=#ffd24a]%d €[/color]" % price
	var money := player.inventory().money
	if money < price:
		text += "  [color=#ff8877](hai %d €)[/color]" % money
	return text


## Sull'host: il giocatore apre la cassa, se ha abbastanza soldi.
func interact(player: FpsController, _slot: int) -> void:
	if is_open or not player.inventory().host_spend(price):
		return
	_set_open(true)
	_refill_left = refill_time
	var spec := WeaponCatalog.roll(_rng)
	var at := global_position + Vector3.UP * pickup_height
	var replicator := PickupReplicator.of(self)
	var pickup: WeaponPickup = replicator.spawn_pickup(spec, at) if replicator else null
	if pickup:
		# La toglie la cassa quando si richiude.
		pickup.lifetime = 0.0
	_pickup_id = pickup.get_instance_id() if pickup else 0


## Sull'host, a inizio run: di nuovo chiusa e piena.
func host_reset() -> void:
	_pickup_id = 0
	if is_open:
		_set_open(false)


func _set_open(open: bool) -> void:
	_apply_open(open)
	if NetSession.is_online():
		_receive_open.rpc(open)


@rpc("authority", "call_remote", "reliable")
func _receive_open(open: bool) -> void:
	_apply_open(open)


func _apply_open(open: bool) -> void:
	if open == is_open and _lid_tween:
		return
	is_open = open
	if _lid_tween:
		_lid_tween.kill()
	_lid_tween = create_tween()
	_lid_tween.tween_property(_lid, "rotation:x", deg_to_rad(open_angle_degrees) if open else 0.0, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
