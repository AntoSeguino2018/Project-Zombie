class_name VendingMachine
extends StaticBody3D
## Macchinetta del caffè: guardandola e premendo E si compra il suo prodotto
## (un Boost) con i propri soldi. Ogni tanto si mangia i soldi, ogni tanto dà
## una dose doppia.
##
## In rete pagamento ed effetto li decide l'host; tutti vedono la macchinetta
## che erogando trema e si illumina.

## Prodotto venduto.
@export var boost: Boost
## Probabilità che si mangi i soldi senza dare nulla.
@export_range(0.0, 1.0) var jam_chance := 0.05
## Probabilità di una dose doppia (durata o cura raddoppiate).
@export_range(0.0, 1.0) var double_chance := 0.08

var _rng := RandomNumberGenerator.new()
var _base_position := Vector3.ZERO
var _vend_tween: Tween

@onready var _body: MeshInstance3D = $Body
@onready var _panel: MeshInstance3D = $Body/Panel
@onready var _label: Label3D = $Label
@onready var _light: OmniLight3D = $Glow


func _ready() -> void:
	_rng.randomize()
	_base_position = _body.position
	if boost == null:
		return
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = boost.color.darkened(0.35)
	body_material.roughness = 0.6
	_body.material_override = body_material
	var panel_material := StandardMaterial3D.new()
	panel_material.albedo_color = boost.color.lightened(0.4)
	panel_material.emission_enabled = true
	panel_material.emission = boost.color.lightened(0.3)
	panel_material.emission_energy_multiplier = 1.5
	_panel.material_override = panel_material
	_light.light_color = boost.color.lightened(0.3)
	_label.text = "%s\n%d €" % [boost.display_name, boost.price]
	_label.modulate = boost.color.lightened(0.5)


## Testo da mostrare quando il giocatore la guarda.
func interaction_text(player: FpsController) -> String:
	if boost == null:
		return ""
	var hex := boost.color.lightened(0.45).to_html(false)
	var text := "Compra [color=#%s]%s[/color] (%s)  [color=#ffd24a]%d €[/color]" % [
			hex, boost.display_name, boost.description, boost.price]
	var money := player.inventory().money
	if money < boost.price:
		text += "  [color=#ff8877](hai %d €)[/color]" % money
	return text


## Sull'host: il giocatore compra il prodotto, se ha abbastanza soldi.
func interact(player: FpsController, _slot: int) -> void:
	var inventory := player.inventory()
	if boost == null or not inventory.host_spend(boost.price):
		return
	var roll := _rng.randf()
	if roll < jam_chance:
		inventory.host_notice("La macchinetta si è mangiata i soldi!")
		_show_vend(false)
		return
	var potency := 2.0 if roll < jam_chance + double_chance else 1.0
	inventory.host_apply_boost(boost, potency)
	inventory.host_notice("%s%s: %s" % ["Doppia dose! " if potency > 1.0 else "", boost.display_name, boost.description])
	_show_vend(true)


func _show_vend(gave: bool) -> void:
	_play_vend(gave)
	if NetSession.is_online():
		_receive_vend.rpc(gave)


@rpc("authority", "call_remote", "reliable")
func _receive_vend(gave: bool) -> void:
	_play_vend(gave)


## Trema e il vetro si illumina; se si mangia i soldi trema e basta.
func _play_vend(gave: bool) -> void:
	if _vend_tween:
		_vend_tween.kill()
	_body.position = _base_position
	_vend_tween = create_tween()
	for i in 4:
		var side := Vector3(0.025 if i % 2 == 0 else -0.025, 0.0, 0.0)
		_vend_tween.tween_property(_body, "position", _base_position + side, 0.04)
	_vend_tween.tween_property(_body, "position", _base_position, 0.04)
	if gave:
		_light.light_energy = 3.0
		create_tween().tween_property(_light, "light_energy", 0.8, 0.5)
