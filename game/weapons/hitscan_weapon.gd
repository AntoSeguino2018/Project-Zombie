class_name HitscanWeapon
extends Node3D
## Arma hitscan: il colpo arriva istantaneamente nel punto mirato.
##
## Il nodo è anche il modello in prima persona (viewmodel): sta sotto la camera
## e a ogni colpo arretra e si alza, poi torna in posizione.
## Predisposto per la rete: fire() riceve origine e direzione come parametri,
## così in futuro potrà essere eseguito o validato dall'host.

signal fired
signal hit(collider: Object, position: Vector3, normal: Vector3)
## Un colpo ha fatto danno a qualcosa con un HealthComponent.
signal dealt_damage(target: HealthComponent, amount: float, killed: bool)

@export var data: WeaponData
## Punto da cui parte la scia del colpo (la bocca dell'arma).
@export var muzzle: Node3D
@export var impact_scene: PackedScene
@export var tracer_scene: PackedScene
@export var damage_number_scene: PackedScene

@export_group("Animazione")
## Di quanto arretra l'arma a ogni colpo, in metri.
@export var kick_distance := 0.05
## Di quanto si alza la canna a ogni colpo, in gradi.
@export var kick_angle_degrees := 4.0
## Velocità con cui l'arma torna in posizione.
@export var kick_recovery := 18.0

var _cooldown := 0.0
var _kick := 0.0
var _rest_position := Vector3.ZERO


func _ready() -> void:
	_rest_position = position


func _physics_process(delta: float) -> void:
	# Il limite a -delta conserva al massimo un tick di "resto": la cadenza reale
	# resta quella impostata anche se non è un multiplo dei 60 Hz della fisica.
	_cooldown = maxf(_cooldown - delta, -delta)


func _process(delta: float) -> void:
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-kick_recovery * delta))
	position = _rest_position + Vector3(0.0, 0.0, _kick * kick_distance)
	rotation.x = deg_to_rad(_kick * kick_angle_degrees)


func can_fire() -> bool:
	return _cooldown <= 0.0


## Spara un colpo da origin verso direction. exclude: corpi da ignorare (chi spara).
func fire(origin: Vector3, direction: Vector3, exclude: Array[RID] = []) -> void:
	_cooldown += 1.0 / data.fire_rate
	_kick = 1.0

	var shot_direction := _apply_spread(direction.normalized())
	var end := origin + shot_direction * data.max_range
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = exclude
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		end = result.position
		_spawn_impact(result.position, result.normal)
		hit.emit(result.collider, result.position, result.normal)
		_apply_damage(result.collider, result.position)

	_spawn_tracer(muzzle.global_position if muzzle else origin, end)
	fired.emit()


func _apply_spread(direction: Vector3) -> Vector3:
	var max_angle := deg_to_rad(data.spread_degrees)
	if max_angle <= 0.0:
		return direction
	var side_axis := Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
	var tilted := direction.rotated(direction.cross(side_axis).normalized(), randf() * max_angle)
	return tilted.rotated(direction, randf() * TAU)


func _apply_damage(collider: Object, point: Vector3) -> void:
	var target := HealthComponent.of(collider)
	if not target or not target.is_alive():
		return
	target.take_damage(data.damage, owner, point)
	var killed := not target.is_alive()
	_spawn_damage_number(point, data.damage, killed)
	dealt_damage.emit(target, data.damage, killed)


func _spawn_damage_number(point: Vector3, amount: float, killed: bool) -> void:
	if not damage_number_scene:
		return
	var number: DamageNumber = damage_number_scene.instantiate()
	get_tree().current_scene.add_child(number)
	number.show_value(amount, point, killed)


func _spawn_impact(point: Vector3, normal: Vector3) -> void:
	if not impact_scene:
		return
	var impact: ImpactEffect = impact_scene.instantiate()
	get_tree().current_scene.add_child(impact)
	impact.place(point, normal)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	if not tracer_scene or from.distance_to(to) < 0.1:
		return
	var tracer: Tracer = tracer_scene.instantiate()
	get_tree().current_scene.add_child(tracer)
	tracer.stretch(from, to)
