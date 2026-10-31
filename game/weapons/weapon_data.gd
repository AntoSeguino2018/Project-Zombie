class_name WeaponData
extends Resource
## Parametri di un'arma hitscan. Ogni arma del gioco è un file .tres con questi
## valori, così si bilancia dall'Inspector senza toccare il codice.

@export var display_name := "Arma"
## Danno di ogni colpo.
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
