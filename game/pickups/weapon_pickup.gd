class_name WeaponPickup
extends StaticBody3D
## Arma a terra che fluttua e gira su se stessa, con il nome e un fascio di
## luce del colore della rarità. Si raccoglie guardandola e premendo E.
##
## Sta sul layer degli oggetti interagibili: i giocatori ci passano attraverso,
## i colpi pure. In rete la crea e la toglie solo l'host (PickupReplicator).

## Arma contenuta, come spec di WeaponCatalog.
var spec: Array = ["pistol"]
var weapon_data: WeaponData

var _taken := false
var _time := 0.0

@onready var _model_pivot: Node3D = $ModelPivot
@onready var _label: Label3D = $Label
@onready var _beam: MeshInstance3D = $Beam


func _ready() -> void:
	add_to_group("weapon_pickups")
	weapon_data = WeaponCatalog.build(spec)
	var color := WeaponCatalog.rarity_color(weapon_data)
	if weapon_data.viewmodel:
		var model: Node3D = weapon_data.viewmodel.instantiate()
		# Il modello in prima persona punta in avanti: girato di lato si vede tutto.
		model.rotation.y = PI / 2.0
		_model_pivot.add_child(model)
	_label.text = weapon_data.display_name
	_label.modulate = color
	var beam_material: StandardMaterial3D = _beam.material_override.duplicate()
	beam_material.albedo_color = Color(color, beam_material.albedo_color.a)
	_beam.material_override = beam_material
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	_model_pivot.rotation.y = _time * 1.5
	_model_pivot.position.y = 0.08 * sin(_time * 2.0)


## Testo da mostrare quando il giocatore la guarda (con i colori della rarità).
func interaction_text(player: FpsController) -> String:
	if _taken:
		return ""
	var hex := WeaponCatalog.rarity_color(weapon_data).to_html(false)
	var text := "Prendi [color=#%s]%s[/color]" % [hex, weapon_data.display_name]
	var weapon := player.weapon()
	if weapon.loadout.size() >= Weapon.MAX_WEAPONS and weapon.data:
		text += "  [color=#aaaaaa](lasci %s)[/color]" % weapon.data.display_name
	return text


## Sull'host: il giocatore la raccoglie; se aveva le mani piene, l'arma che
## aveva in mano (slot) resta a terra al suo posto.
func interact(player: FpsController, slot: int) -> void:
	if _taken:
		return
	_taken = true
	var dropped := player.weapon().host_pick_up(spec, slot)
	if not dropped.is_empty():
		var replicator := PickupReplicator.of(self)
		if replicator:
			replicator.spawn_pickup(dropped, global_position)
	queue_free()
