class_name WeaponCatalog
extends RefCounted
## Tutte le armi che si possono trovare e i tratti che le modificano.
##
## Un'arma trovata è descritta da uno "spec": l'arma base e la lista dei suoi
## tratti, per esempio ["carbine", "fast", "pierce"]. Lo spec è piccolo e si
## manda in rete; ogni partecipante ricostruisce la stessa arma con build().
## I tratti normali cambiano i numeri; i trucchi cambiano come si comporta il
## colpo e rendono l'arma "truccata".

## Armi base. Si caricano solo quando servono (con base()): precaricarle
## creerebbe un giro di dipendenze tra arma, proiettili ed esplosioni.
const BASES := {
	"pistol": "res://game/weapons/pistol.tres",
	"carbine": "res://game/weapons/carbine.tres",
	"shotgun": "res://game/weapons/shotgun.tres",
	"smg": "res://game/weapons/smg.tres",
	"grenade_launcher": "res://game/weapons/grenade_launcher.tres",
}

## Probabilità relativa di trovare ogni arma base in una cassa.
const BASE_WEIGHTS := {
	"pistol": 1.0,
	"carbine": 2.5,
	"shotgun": 2.5,
	"smg": 2.5,
	"grenade_launcher": 1.5,
}

## Nome da aggiungere all'arma: [maschile, femminile]. Gli aggettivi vengono
## prima delle frasi ("Carabina rapida con caricatore esteso").
const TRAITS := {
	"fast": {"name": ["rapido", "rapida"]},
	"heavy": {"name": ["pesante", "pesante"]},
	"precise": {"name": ["preciso", "precisa"]},
	"big_mag": {"name": ["con caricatore esteso", "con caricatore esteso"], "phrase": true},
	"quick_reload": {"name": ["a ricarica lampo", "a ricarica lampo"], "phrase": true},
	# Trucchi: solo per le armi a colpo istantaneo.
	"bouncy": {"name": ["rimbalzante", "rimbalzante"], "trick": true},
	"pierce": {"name": ["perforante", "perforante"], "trick": true},
	"explosive": {"name": ["esplosivo", "esplosiva"], "trick": true},
	"incendiary": {"name": ["incendiario", "incendiaria"], "trick": true},
	"double": {"name": ["a doppia canna", "a doppia canna"], "trick": true, "phrase": true},
}

## Probabilità di avere 0, 1 o 2 tratti.
const TRAIT_COUNT_WEIGHTS := [0.45, 0.4, 0.15]
## Probabilità che un tratto sia un trucco (al massimo uno per arma).
const TRICK_CHANCE := 0.3

const RARITY_NAMES := ["Comune", "Truccata", "Sbroccata"]
const RARITY_COLORS := [Color(0.82, 0.84, 0.86), Color(0.35, 0.8, 1.0), Color(1.0, 0.55, 0.15)]


## Ricostruisce l'arma descritta da spec. Uno spec sconosciuto dà la pistola.
static func build(spec: Array) -> WeaponData:
	var base_id: String = spec[0] if not spec.is_empty() and BASES.has(spec[0]) else "pistol"
	var data: WeaponData = base(base_id).duplicate()
	var adjectives := PackedStringArray()
	var phrases := PackedStringArray()
	for i in range(1, spec.size()):
		var trait_id: String = spec[i]
		if not TRAITS.has(trait_id) or data.traits.has(trait_id):
			continue
		var info: Dictionary = TRAITS[trait_id]
		if info.get("trick", false):
			data.rarity = WeaponData.Rarity.RIGGED
		_apply_trait(data, trait_id)
		data.traits.append(trait_id)
		var word: String = info.name[1 if data.feminine else 0]
		if info.get("phrase", false):
			phrases.append(word)
		else:
			adjectives.append(word)
	var parts := PackedStringArray([data.display_name])
	parts.append_array(adjectives)
	parts.append_array(phrases)
	data.display_name = " ".join(parts)
	return data


## Le armi descritte da specs, nello stesso ordine.
static func build_all(specs: Array) -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for spec in specs:
		result.append(build(spec))
	return result


## Un'arma a caso, come quelle nelle casse.
static func roll(rng: RandomNumberGenerator) -> Array:
	var base_id: String = _pick_weighted(rng, BASE_WEIGHTS)
	var spec: Array = [base_id]
	var hitscan := base(base_id).projectile_scene == null
	var count := _pick_index(rng, TRAIT_COUNT_WEIGHTS)
	var has_trick := false
	for i in count:
		var trick := hitscan and not has_trick and rng.randf() < TRICK_CHANCE
		var choices: Array = TRAITS.keys().filter(func(id): return not spec.has(id) \
				and TRAITS[id].get("trick", false) == trick)
		if choices.is_empty():
			continue
		spec.append(choices[rng.randi() % choices.size()])
		has_trick = has_trick or trick
	return spec


## L'arma base id, così com'è nel suo file (da non modificare).
static func base(id: String) -> WeaponData:
	return load(BASES[id])


static func rarity_color(data: WeaponData) -> Color:
	return RARITY_COLORS[data.rarity]


static func _apply_trait(data: WeaponData, trait_id: String) -> void:
	match trait_id:
		"fast":
			data.fire_rate *= 1.3
		"heavy":
			data.damage *= 1.35
			data.fire_rate *= 0.8
			data.recoil_pitch_degrees *= 1.3
		"precise":
			data.spread_degrees *= 0.4
			data.recoil_pitch_degrees *= 0.7
			data.recoil_yaw_degrees *= 0.7
		"big_mag":
			data.magazine_size = ceili(data.magazine_size * 1.5)
		"quick_reload":
			data.reload_time *= 0.55
		"bouncy":
			data.bounces = 2
		"pierce":
			data.pierce = 2
		"explosive":
			data.explosion_radius = 1.6 if data.pellets <= 1 else 1.0
			data.explosion_damage = data.damage * 0.6
			data.explosion_knockback = 3.0
		"incendiary":
			data.burn_damage = maxf(8.0, data.damage * 0.8)
		"double":
			data.pellets *= 2
			data.spread_degrees = maxf(data.spread_degrees * 1.5, 1.5)


static func _pick_weighted(rng: RandomNumberGenerator, weights: Dictionary) -> Variant:
	var keys := weights.keys()
	return keys[_pick_index(rng, keys.map(func(k): return weights[k]))]


static func _pick_index(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r < 0.0:
			return i
	return weights.size() - 1
