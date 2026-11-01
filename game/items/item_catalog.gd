class_name ItemCatalog
extends RefCounted
## Tutti gli oggetti passivi che si possono trovare. In rete un oggetto si
## manda come percorso della sua risorsa; si accettano solo quelli di questa
## lista.

const ITEMS: Array[String] = [
	"res://game/items/peperoncino.tres",
	"res://game/items/grilletto_unto.tres",
	"res://game/items/dita_da_pianista.tres",
	"res://game/items/caricatore_xl.tres",
	"res://game/items/scarpe_da_ginnastica.tres",
	"res://game/items/felpa_imbottita.tres",
	"res://game/items/salvadanaio.tres",
	"res://game/items/cerotto.tres",
	"res://game/items/guanto_da_forno.tres",
	"res://game/items/defibrillatore.tres",
]


## Gli oggetti caricati, tenuti in memoria (vedi all()).
static var _loaded: Array[PassiveItem] = []


## Tutti gli oggetti, caricati la prima volta e poi tenuti.
static func all() -> Array[PassiveItem]:
	if _loaded.is_empty():
		for path in ITEMS:
			_loaded.append(load(path))
	return _loaded


## Vero se path è un oggetto del catalogo.
static func is_item(path: Variant) -> bool:
	return path is String and ITEMS.has(path)


## Un oggetto a caso, secondo i pesi.
static func roll(rng: RandomNumberGenerator) -> PassiveItem:
	var items := all()
	var total := 0.0
	for item in items:
		total += item.weight
	var r := rng.randf() * total
	for item in items:
		r -= item.weight
		if r < 0.0:
			return item
	return items.back()
