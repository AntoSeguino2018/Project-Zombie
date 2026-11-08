class_name WeaponPickup
extends StaticBody3D
## Arma a terra che fluttua e gira su se stessa, con il nome e un fascio di
## luce del colore della rarità. Si raccoglie guardandola e premendo E.
## Può essere anche un'arma bianca (spec ["melee", id], vedi MeleeCatalog): va
## nel terzo slot, e quella che si aveva resta a terra.
##
## Sta sul layer degli oggetti interagibili: i giocatori ci passano attraverso,
## i colpi pure. In rete la crea e la toglie solo l'host (PickupReplicator).

## Secondi prima che un'arma lasciata a terra sparisca (0 = mai). Le armi
## delle casse le toglie la cassa quando si richiude.
@export var lifetime := 120.0

## Arma contenuta, come spec di WeaponCatalog (o di MeleeCatalog).
var spec: Array = ["pistol"]
var weapon_data: WeaponData
## L'arma bianca contenuta, se lo è (allora weapon_data è null).
var melee_data: MeleeWeaponData

var _taken := false
var _time := 0.0
var _start_time := 0.0

@onready var _model_pivot: Node3D = $ModelPivot
@onready var _label: Label3D = $Label
@onready var _beam: MeshInstance3D = $Beam


func _ready() -> void:
	add_to_group("weapon_pickups")
	if MeleeCatalog.is_spec(spec):
		_ready_melee()
		return
	weapon_data = WeaponCatalog.build(spec)
	var color := WeaponCatalog.rarity_color(weapon_data)
	if weapon_data.viewmodel:
		var model: Node3D = weapon_data.viewmodel.instantiate()
		# Il modello in prima persona punta in avanti: girato di lato si vede tutto.
		model.rotation.y = PI / 2.0
		_model_pivot.add_child(model)
		_model_pivot.scale *= weapon_data.pickup_scale
	_label.text = weapon_data.display_name
	_label.modulate = color
	var beam_material: StandardMaterial3D = _beam.material_override.duplicate()
	beam_material.albedo_color = Color(color, beam_material.albedo_color.a)
	_beam.material_override = beam_material
	_time = randf() * TAU
	_start_time = _time


func _ready_melee() -> void:
	melee_data = MeleeCatalog.data(str(spec[1]))
	var model := MeleeCatalog.build_model(melee_data)
	# Di traverso e centrato: si vede tutta mentre gira.
	model.rotation.z = PI / 2.0
	model.position.x = (melee_data.handle_length + melee_data.head_size.y * (1.0 if melee_data.bladed else 0.0)) / 2.0
	_model_pivot.add_child(model)
	_label.text = melee_data.display_name
	_label.modulate = MeleeCatalog.COLOR
	var beam_material: StandardMaterial3D = _beam.material_override.duplicate()
	beam_material.albedo_color = Color(MeleeCatalog.COLOR, beam_material.albedo_color.a)
	_beam.material_override = beam_material
	_time = randf() * TAU
	_start_time = _time


func _process(delta: float) -> void:
	_time += delta
	if lifetime > 0.0 and _time >= lifetime + _start_time and multiplayer.is_server():
		queue_free()
	_model_pivot.rotation.y = _time * 1.5
	_model_pivot.position.y = 0.08 * sin(_time * 2.0)


## Testo da mostrare quando il giocatore la guarda (con i colori della rarità).
func interaction_text(player: FpsController) -> String:
	if _taken:
		return ""
	if melee_data:
		var melee := player.melee()
		var melee_text := "Prendi [color=#%s]%s[/color]" % [MeleeCatalog.COLOR.to_html(false), melee_data.display_name]
		if melee.weapon:
			melee_text += "  [color=#aaaaaa](lasci %s)[/color]" % melee.weapon.display_name
		return melee_text
	var hex := WeaponCatalog.rarity_color(weapon_data).to_html(false)
	var text := "Prendi [color=#%s]%s[/color]" % [hex, weapon_data.display_name]
	var weapon := player.weapon()
	if weapon.loadout.size() >= Weapon.MAX_WEAPONS and weapon.data:
		text += "  [color=#aaaaaa](lasci %s)[/color]" % weapon.data.display_name
	return text


## Sull'host: il giocatore la raccoglie; se aveva le mani piene, l'arma che
## aveva in mano (slot) resta a terra ai suoi piedi.
func interact(player: FpsController, slot: int) -> void:
	if _taken:
		return
	_taken = true
	var dropped: Array = player.melee().host_set_weapon(melee_data.id) if melee_data 			else player.weapon().host_pick_up(spec, slot)
	if not dropped.is_empty():
		var replicator := PickupReplicator.of(self)
		if replicator:
			replicator.spawn_pickup(dropped, drop_point(player))
	queue_free()


## Dove lasciare un'arma: ai piedi del giocatore. Non dove era quella raccolta
## (sopra una cassa coprirebbe l'arma successiva) né davanti (starebbe tra il
## giocatore e quello che guarda).
static func drop_point(player: FpsController) -> Vector3:
	return player.global_position + Vector3.UP * 0.5
