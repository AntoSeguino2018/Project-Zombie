class_name MapZone
extends Node3D
## Una zona della mappa (aula, viale, biblioteca…). È anche il "chunk" con cui
## si divide il lavoro: l'host fa uscire gli zombie solo nelle zone dove sono i
## giocatori e in quelle accanto, e ogni giocatore riceve dalla rete solo gli
## zombie vicini a lui (vedi ZoneManager).
##
## Una zona chiusa si apre comprando una delle sue porte (ZoneDoor). Va messa
## come figlia di ZoneManager; i suoi punti di comparsa stanno nel WaveDirector
## e le appartengono se cadono dentro i suoi volumi.

## Nome mostrato ai giocatori (porte, scritte).
@export var display_name := ""
## Aperta fin dall'inizio della run.
@export var start_unlocked := false
## Volumi della zona, in coordinate del livello: un punto è nella zona se sta
## in almeno uno di questi.
@export var bounds: Array[AABB] = []
## Zone confinanti (nomi dei nodi fratelli): gli zombie possono arrivare da lì.
@export var neighbors: Array[StringName] = []

## Aperta (su tutti i partecipanti; lo decide l'host).
var unlocked := false


func contains(point: Vector3) -> bool:
	for box in bounds:
		if box.has_point(point):
			return true
	return false


## Distanza orizzontale dal volume più vicino (0 se dentro).
func distance_to(point: Vector3) -> float:
	var best := INF
	for box in bounds:
		var closest := point.clamp(box.position, box.end)
		best = minf(best, Vector2(point.x - closest.x, point.z - closest.z).length())
	return best
