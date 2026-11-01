class_name WaveEnemy
extends Resource
## Un tipo di zombie che le ondate possono mandare: quanto costa del budget di
## pericolosità, da che ondata compare e quanto spesso viene scelto.

@export var scene: PackedScene
## Punti di pericolosità che spende l'ondata per mandarlo.
@export var cost := 1
## Prima ondata in cui può comparire.
@export var first_wave := 1
## Probabilità relativa di essere scelto, prima della variazione di ogni ondata.
@export var weight := 1.0
