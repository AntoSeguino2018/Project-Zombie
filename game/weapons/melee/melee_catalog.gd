class_name MeleeCatalog
extends RefCounted
## Le armi bianche: dati (file .tres in questa cartella), estrazione dalle casse
## e modelli in greybox. A terra un'arma bianca è la spec ["melee", id].

const IDS: Array[String] = ["martello", "martellone", "katana"]
## Probabilità che una cassa dia un'arma bianca invece di un'arma da fuoco.
const CRATE_CHANCE := 0.12
## Pesi all'uscita dalle casse.
const CRATE_WEIGHTS := {"martello": 5.0, "katana": 3.0, "martellone": 2.0}
## Colore delle armi bianche (nomi, fasci di luce).
const COLOR := Color(0.85, 0.9, 1.0)

static var _cache := {}


static func data(id: String) -> MeleeWeaponData:
	if not IDS.has(id):
		return null
	if not _cache.has(id):
		_cache[id] = load("res://game/weapons/melee/%s.tres" % id)
	return _cache[id]


## Vero se spec (di un'arma a terra) è un'arma bianca.
static func is_spec(spec: Array) -> bool:
	return spec.size() == 2 and spec[0] == "melee" and IDS.has(str(spec[1]))


static func spec_for(id: String) -> Array:
	return ["melee", id]


## Un'arma bianca a caso, per le casse.
static func roll_spec(rng: RandomNumberGenerator) -> Array:
	var total := 0.0
	for id in CRATE_WEIGHTS:
		total += CRATE_WEIGHTS[id]
	var r := rng.randf() * total
	for id in CRATE_WEIGHTS:
		r -= CRATE_WEIGHTS[id]
		if r < 0.0:
			return spec_for(id)
	return spec_for(IDS[0])


## Modello in greybox: l'impugnatura nell'origine, l'arma verso +Y.
static func build_model(weapon: MeleeWeaponData) -> Node3D:
	var root := Node3D.new()
	root.name = "Modello"
	_box(root, Vector3(0, weapon.handle_length / 2.0, 0),
			Vector3(0.035, weapon.handle_length, 0.035) * (1.4 if weapon.handle_length > 0.6 else 1.0), weapon.handle_color)
	if weapon.bladed:
		var guard_y := weapon.handle_length
		_box(root, Vector3(0, guard_y, 0), Vector3(0.1, 0.02, 0.08), Color(0.65, 0.55, 0.2))
		_box(root, Vector3(0, guard_y + weapon.head_size.y / 2.0, 0), weapon.head_size, weapon.head_color)
	else:
		_box(root, Vector3(0, weapon.handle_length - weapon.head_size.y / 2.0, 0), weapon.head_size, weapon.head_color)
	return root


static func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	material.metallic = 0.6 if color.v > 0.6 else 0.0
	mesh.material = material
	node.mesh = mesh
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
