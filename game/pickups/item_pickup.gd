class_name ItemPickup
extends StaticBody3D
## Oggetto passivo a terra (lasciato da uno zombie): un cubetto colorato che
## fluttua e gira, con il nome. Lo prende chi lo guarda e preme E.
##
## Come le armi a terra, sta sul layer degli oggetti interagibili e in rete lo
## crea e lo toglie solo l'host (PickupReplicator).

## Secondi prima che sparisca se nessuno lo prende (0 = mai).
@export var lifetime := 120.0

## Percorso della risorsa PassiveItem contenuta (vedi ItemCatalog).
var item_path := ""
var item: PassiveItem

var _taken := false
var _time := 0.0
var _start_time := 0.0

@onready var _cube: MeshInstance3D = $Cube
@onready var _label: Label3D = $Label
@onready var _beam: MeshInstance3D = $Beam


func _ready() -> void:
	add_to_group("item_pickups")
	item = load(item_path)
	var material := StandardMaterial3D.new()
	material.albedo_color = item.color
	material.emission_enabled = true
	material.emission = item.color
	material.emission_energy_multiplier = 0.6
	_cube.material_override = material
	_label.text = item.display_name
	_label.modulate = item.color.lightened(0.3)
	var beam_material: StandardMaterial3D = _beam.material_override.duplicate()
	beam_material.albedo_color = Color(item.color, beam_material.albedo_color.a)
	_beam.material_override = beam_material
	_time = randf() * TAU
	_start_time = _time


func _process(delta: float) -> void:
	_time += delta
	if lifetime > 0.0 and _time >= lifetime + _start_time and multiplayer.is_server():
		queue_free()
	_cube.rotation = Vector3(0.5, _time * 1.8, 0.3)
	_cube.position.y = 0.08 * sin(_time * 2.0)


## Testo da mostrare quando il giocatore lo guarda.
func interaction_text(player: FpsController) -> String:
	if _taken:
		return ""
	var count := player.inventory().item_count(item) + 1
	return "Prendi [color=#%s]%s[/color] (%s)" % [item.color.lightened(0.3).to_html(false),
			item.display_name, item.summary(count) if count == 1 else "%s in tutto" % item.summary(count)]


## Sull'host: il giocatore lo raccoglie.
func interact(player: FpsController, _slot: int) -> void:
	if _taken:
		return
	_taken = true
	player.inventory().host_add_item(item)
	queue_free()
