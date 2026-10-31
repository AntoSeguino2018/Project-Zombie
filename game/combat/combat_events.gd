class_name CombatEvents
extends RefCounted
## Bacheca degli eventi di combattimento, con un'unica istanza condivisa:
## CombatEvents.bus. Chi deve contare o reagire (HUD, statistiche, in futuro il
## director e gli oggetti della run) si collega qui invece di cercare i singoli
## nemici.

## Un nemico è morto. killer è chi l'ha ucciso (anche indirettamente, es. con
## un'esplosione o lanciandogli contro un altro zombie); può essere null.
signal enemy_killed(enemy: Node, killer: Node)

static var bus := CombatEvents.new()
