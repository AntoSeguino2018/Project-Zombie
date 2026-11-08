class_name HelicopterPart
extends StaticBody3D
## Un pezzo dell'elicottero che si guarda e si usa con E (la radio per
## chiamarlo, la cabina per salire): gira domande e azioni all'Helicopter.

enum Role { RADIO, CABIN }

var helicopter: Helicopter
var role := Role.RADIO


func interaction_text(player: FpsController) -> String:
	return helicopter.part_text(role, player) if helicopter else ""


func interact(player: FpsController, _slot: int) -> void:
	if helicopter:
		helicopter.part_interact(role, player)
