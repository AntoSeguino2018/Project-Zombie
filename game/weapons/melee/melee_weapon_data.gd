class_name MeleeWeaponData
extends Resource
## Un'arma bianca (terzo slot, tasto 3): martello, martellone, katana.
## Il colpo segue le regole del pugno (MeleeAttack): colpisce gli zombie davanti,
## entro reach e arc_degrees, al massimo max_targets, e li spinge; con launch li
## scaraventa come la Mano pesante.

enum Swing { OVERHEAD, SLASH }

## Id nel catalogo (MeleeCatalog) e nelle spec delle armi a terra.
@export var id := ""
@export var display_name := "Arma bianca"
## Prezzo all'acquisto al muro.
@export var price := 250

@export_group("Colpo")
@export var damage := 40.0
## Distanza massima dal centro del bersaglio, in metri.
@export var reach := 2.4
## Angolo massimo, in gradi, tra dove si guarda e il bersaglio.
@export var arc_degrees := 50.0
## Zombie colpiti al massimo da un colpo (i più vicini).
@export var max_targets := 3
## Secondi tra un colpo e l'altro.
@export var cooldown := 0.6
## Spinta (o lancio) in m/s, in avanti e verso l'alto.
@export var push_speed := 5.0
@export var push_up := 2.0
## Scaraventa lo zombie: in volo fa launch_impact_damage agli altri e a sé contro i muri.
@export var launch := false
@export var launch_impact_damage := 20.0
## Danno ai blocchi distruttibili colpiti (0 = non li rompe) e raggio (0 = un blocco solo).
@export var structure_damage := 0.0
@export var structure_radius := 0.0
## È un martello: serve per far partire i proiettili da carro armato (passo 3.10).
@export var is_hammer := false

@export_group("Aspetto")
## Come si muove: dall'alto in basso (martelli) o di taglio (katana).
@export var swing := Swing.OVERHEAD
## Lunghezza del manico e misure della testa (o della lama), in metri.
@export var handle_length := 0.35
@export var head_size := Vector3(0.12, 0.06, 0.06)
@export var handle_color := Color(0.45, 0.28, 0.15)
@export var head_color := Color(0.3, 0.31, 0.33)
## Lama invece della testa (katana): head_size è la lama, lunga in Y.
@export var bladed := false
