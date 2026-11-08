class_name WallWeapon
extends StaticBody3D
## Arma bianca appesa al muro, come gli acquisti a muro di Black Ops: una
## tavola con l'arma e il prezzo scritto. Guardandola e premendo E la si compra
## (MeleeWeaponData.price, la paga chi la compra) e va nel terzo slot; l'arma
## bianca che si aveva resta a terra ai propri piedi. Resta sempre lì: la
## possono comprare tutti, anche più volte.
##
## Il nodo guarda verso +Z (la faccia con l'arma). La forma si costruisce qui.
## In rete decide l'host, come per le casse.

const BOARD_COLOR := Color(0.18, 0.2, 0.19)
const FRAME_COLOR := Color(0.95, 0.7, 0.15)

## Id dell'arma bianca (MeleeCatalog).
@export var weapon_id := "martello"

var weapon: MeleeWeaponData


func _ready() -> void:
	weapon = MeleeCatalog.data(weapon_id)
	collision_layer = 1 | 16
	collision_mask = 0
	var width := maxf(weapon.handle_length + (weapon.head_size.y if weapon.bladed else weapon.head_size.x) + 0.4, 0.9)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.8, 0.2)
	shape.shape = box
	add_child(shape)
	_box(Vector3.ZERO, Vector3(width, 0.8, 0.05), BOARD_COLOR)
	_box(Vector3(0, 0.42, 0), Vector3(width + 0.06, 0.04, 0.07), FRAME_COLOR)
	_box(Vector3(0, -0.42, 0), Vector3(width + 0.06, 0.04, 0.07), FRAME_COLOR)
	# L'arma di traverso sulla tavola, impugnatura a sinistra.
	var model := MeleeCatalog.build_model(weapon)
	model.rotation.z = -PI / 2.0
	model.position = Vector3(-width / 2.0 + 0.2, 0.0, 0.08)
	add_child(model)
	var label := Label3D.new()
	label.text = "%s\n%d €" % [weapon.display_name, weapon.price]
	label.font_size = 56
	label.outline_size = 12
	label.pixel_size = 0.005
	label.position = Vector3(0, 0.75, 0.05)
	add_child(label)


func interaction_text(player: FpsController) -> String:
	var melee := player.melee()
	if melee.weapon == weapon:
		return "Hai già: %s" % weapon.display_name
	var text := "Compra [color=#%s]%s[/color]  [color=#ffd24a]%d €[/color]" % [
			MeleeCatalog.COLOR.to_html(false), weapon.display_name, weapon.price]
	if melee.weapon:
		text += "  [color=#aaaaaa](lasci %s)[/color]" % melee.weapon.display_name
	if player.inventory().money < weapon.price:
		text += "  [color=#ff8877](hai %d €)[/color]" % player.inventory().money
	return text


## Sull'host: il giocatore la compra, se non ce l'ha già e ha i soldi.
func interact(player: FpsController, _slot: int) -> void:
	if player.melee().weapon == weapon or not player.inventory().host_spend(weapon.price):
		return
	var dropped := player.melee().host_set_weapon(weapon.id)
	if not dropped.is_empty():
		var replicator := PickupReplicator.of(self)
		if replicator:
			replicator.spawn_pickup(dropped, WeaponPickup.drop_point(player))


func _box(at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	node.mesh = mesh
	node.position = at
	add_child(node)
