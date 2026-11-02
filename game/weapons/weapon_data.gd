class_name WeaponData
extends Resource
## Parametri di un'arma. Ogni arma base del gioco è un file .tres con questi
## valori, così si bilancia dall'Inspector senza toccare il codice; le armi
## trovate nelle casse sono copie di quelle base modificate dai tratti
## (vedi WeaponCatalog).
## Senza projectile_scene l'arma è hitscan (il colpo arriva all'istante);
## con projectile_scene spara proiettili fisici che volano e cadono.

enum Rarity { COMMON, RIGGED, UNHINGED }

## Nome dell'arma base nel catalogo (WeaponCatalog.BASES).
@export var catalog_id := ""
@export var display_name := "Arma"
## Vero se il nome è femminile: serve ad accordare i tratti ("Carabina rapida").
@export var feminine := true
@export var rarity := Rarity.COMMON
## Modello in prima persona. Deve contenere un Marker3D "Muzzle" sulla bocca.
@export var viewmodel: PackedScene
## Danno di ogni colpo (per i proiettili: il colpo diretto).
@export var damage := 10.0
## Colpi al secondo.
@export var fire_rate := 8.0
## Se vero, tenendo premuto si continua a sparare.
@export var automatic := true
## Distanza massima del colpo, in metri.
@export var max_range := 200.0
## Dispersione massima di ogni colpo attorno al mirino, in gradi.
@export var spread_degrees := 0.6
## Pallini sparati a ogni colpo (fucili a pompa), ognuno con il danno pieno.
@export var pellets := 1
## Colpi nel caricatore (0 = infiniti). Per ora la riserva è infinita.
@export var magazine_size := 30
## Se vero, il caricatore non cambia mai: niente tratti né oggetti che lo
## allungano (es. la Magnum, sei colpi e basta).
@export var fixed_magazine := false
## Secondi per ricaricare.
@export var reload_time := 1.5

@export_group("Rinculo")
## Quanto sale la visuale a ogni colpo, in gradi.
@export var recoil_pitch_degrees := 1.0
## Spostamento laterale casuale massimo a ogni colpo, in gradi.
@export var recoil_yaw_degrees := 0.4
## Velocità con cui la visuale torna al punto di mira originale.
@export var recoil_recovery := 10.0

@export_group("Proiettile")
## Scena del proiettile. Vuota = arma hitscan.
@export var projectile_scene: PackedScene
## Velocità iniziale, in m/s.
@export var projectile_speed := 30.0
## Accelerazione verso il basso, in m/s² (0 = vola dritto).
@export var projectile_gravity := 0.0
## Secondi di volo prima che il proiettile sparisca (o esploda).
@export var projectile_lifetime := 4.0

@export_group("Esplosione")
## Raggio dell'esplosione all'impatto, in metri (0 = niente esplosione).
@export var explosion_radius := 0.0
## Danno al centro dell'esplosione: al bordo scende al 40%.
@export var explosion_damage := 0.0
## Velocità con cui l'esplosione scaraventa via gli zombie, in m/s.
@export var explosion_knockback := 0.0

@export_group("Trucchi")
## Quante volte un colpo rimbalza sui muri prima di fermarsi.
@export var bounces := 0
## Quanti nemici attraversa un colpo prima di fermarsi.
@export var pierce := 0
## Danno a ogni nemico attraversato, rispetto al precedente (1 = sempre pieno,
## 0.5 = si dimezza). Vale per le armi a un colpo solo (non a pallini).
@export_range(0.0, 1.0) var pierce_falloff := 1.0
## Sotto questo danno il colpo che attraversa non scende mai.
@export var pierce_min_damage := 0.0
## Danno al secondo del fuoco appiccato dai colpi (0 = niente fuoco).
@export var burn_damage := 0.0
## Secondi di fuoco dopo l'ultimo colpo.
@export var burn_time := 3.0

## Tratti applicati all'arma base, nell'ordine (vedi WeaponCatalog.TRAITS).
var traits := PackedStringArray()


## Descrizione compatta dell'arma, da mandare in rete: arma base e tratti.
func spec() -> Array:
	var result: Array = [catalog_id]
	result.append_array(traits)
	return result
