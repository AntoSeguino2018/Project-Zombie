class_name WeaponData
extends Resource
## Parametri di un'arma. Ogni arma del gioco è un file .tres con questi valori,
## così si bilancia dall'Inspector senza toccare il codice.
## Senza projectile_scene l'arma è hitscan (il colpo arriva all'istante);
## con projectile_scene spara proiettili fisici che volano e cadono.

@export var display_name := "Arma"
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
