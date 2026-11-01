class_name PassiveItem
extends Resource
## Un oggetto passivo della run. Ogni copia raccolta somma di nuovo il suo
## effetto (per esempio due "Grilletto unto" = cadenza +20%). Gli oggetti
## valgono fino alla fine della run.
##
## L'effetto è sempre "stat aumenta di per_stack a copia": chi deve usarlo
## chiede il totale a RunInventory.stat(nome).

@export var display_name := "Oggetto"
## Statistica che aumenta.
@export_enum("damage", "fire_rate", "reload_speed", "magazine", "move_speed", "max_health",
		"kill_money", "kill_heal", "melee_damage", "revive_speed") var stat := "damage"
## Aumento per ogni copia: frazione (0.1 = +10%) se percent, altrimenti un numero.
@export var per_stack := 0.1
@export var percent := true
## Cosa aumenta, in parole ("cadenza di fuoco", "vita massima"...).
@export var effect_label := ""
@export var color := Color(0.9, 0.9, 0.9)
## Probabilità relativa di trovarlo.
@export var weight := 1.0


## Effetto totale di count copie, in parole: "+20% cadenza di fuoco".
func summary(count := 1) -> String:
	var value := per_stack * count
	var amount := "%d%%" % roundi(value * 100.0) if percent else "%d" % roundi(value)
	return "+%s %s" % [amount, effect_label]
