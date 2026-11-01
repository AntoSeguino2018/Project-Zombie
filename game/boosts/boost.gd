class_name Boost
extends Resource
## Un prodotto delle macchinette del caffè: costa soldi e dà un effetto
## immediato (cura) o a tempo (cadenza, ricarica). Comprarlo di nuovo mentre
## è attivo ne allunga la durata, non lo rende più forte.

@export var display_name := "Espresso"
## Cosa fa, in poche parole (per la scritta della macchinetta e dell'HUD).
@export var description := ""
@export var price := 40
## Secondi di effetto; 0 = solo effetto immediato.
@export var duration := 60.0
## Colore della macchinetta e del nome nell'HUD.
@export var color := Color(0.55, 0.32, 0.18)

@export_group("Effetti")
@export var fire_rate_multiplier := 1.0
@export var reload_speed_multiplier := 1.0
## Vita ridata subito.
@export var heal := 0.0
