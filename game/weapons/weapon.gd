class_name Weapon
extends Node3D
## Arma in mano al giocatore. A seconda dei suoi dati spara colpi istantanei
## (hitscan) oppure proiettili fisici. Tiene anche le armi portate (loadout) e
## gestisce il cambio.
##
## Il nodo sta sotto la camera e contiene il modello in prima persona dell'arma
## equipaggiata: a ogni colpo arretra e si alza, poi torna in posizione.
## Predisposto per la rete: fire() riceve origine e direzione come parametri,
## così in futuro potrà essere eseguito o validato dall'host.

signal fired
signal hit(collider: Object, position: Vector3, normal: Vector3)
## Un colpo (o un'esplosione) ha fatto danno a qualcosa con un HealthComponent.
signal dealt_damage(target: HealthComponent, amount: float, killed: bool)
## È stata presa in mano un'altra arma.
signal equipped(data: WeaponData)

## Mondo e nemici: i proiettili non colpiscono i compagni.
const PROJECTILE_MASK := 1 | 4

## Armi portate; si parte con la prima.
@export var loadout: Array[WeaponData] = []:
	set(value):
		loadout = value
		# I dati dell'arma iniziale sono leggibili subito, anche prima di _ready.
		if data == null and not loadout.is_empty():
			data = loadout[0]
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
## Secondi per cambiare arma; nel frattempo non si spara.
@export var switch_time := 0.3

## Dati dell'arma in mano.
var data: WeaponData
## Punto da cui partono scia e proiettili (la bocca dell'arma in mano).
var muzzle: Node3D

var _slot := -1
var _model: Node3D
var _cooldown := 0.0
var _kick := 0.0
var _switch_left := 0.0
var _rest_position := Vector3.ZERO


func _ready() -> void:
	_rest_position = position
	if not loadout.is_empty():
		equip(0)
		_switch_left = 0.0


func _physics_process(delta: float) -> void:
	# Il limite a -delta conserva al massimo un tick di "resto": la cadenza reale
	# resta quella impostata anche se non è un multiplo dei 60 Hz della fisica.
	_cooldown = maxf(_cooldown - delta, -delta)
	_switch_left = maxf(_switch_left - delta, 0.0)


func _process(delta: float) -> void:
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-kick_recovery * delta))
	# Durante il cambio l'arma scende fuori dallo schermo e risale.
	var lowered := _switch_left / switch_time if switch_time > 0.0 else 0.0
	position = _rest_position + Vector3(0.0, -0.3 * lowered, _kick * kick_distance)
	rotation.x = deg_to_rad(_kick * kick_angle_degrees) - 0.6 * lowered


## Prende in mano l'arma nello slot indicato del loadout.
func equip(slot: int) -> void:
	if slot < 0 or slot >= loadout.size() or slot == _slot:
		return
	_slot = slot
	data = loadout[slot]
	if _model:
		_model.queue_free()
	_model = data.viewmodel.instantiate() if data.viewmodel else null
	muzzle = null
	if _model:
		add_child(_model)
		muzzle = _model.get_node_or_null("Muzzle")
	_switch_left = switch_time
	_cooldown = maxf(_cooldown, 0.0)
	_kick = 0.0
	equipped.emit(data)


## Passa all'arma successiva (step = 1) o precedente (step = -1).
func cycle(step: int) -> void:
	if not loadout.is_empty():
		equip(posmod(_slot + step, loadout.size()))


func current_slot() -> int:
	return _slot


func can_fire() -> bool:
	return data != null and _cooldown <= 0.0 and _switch_left <= 0.0


## Spara un colpo da origin verso direction. exclude: corpi da ignorare (chi spara).
func fire(origin: Vector3, direction: Vector3, exclude: Array[RID] = []) -> void:
	_cooldown += 1.0 / data.fire_rate
	_kick = 1.0
	var shot_direction := _apply_spread(direction.normalized())
	if data.projectile_scene:
		_fire_projectile(origin, shot_direction, exclude)
	else:
		_fire_hitscan(origin, shot_direction, exclude)
	fired.emit()


func _fire_hitscan(origin: Vector3, direction: Vector3, exclude: Array[RID]) -> void:
	var end := origin + direction * data.max_range
	var result := _raycast(origin, end, exclude, 0xFFFFFFFF)
	if result:
		end = result.position
		_spawn_impact(result.position, result.normal)
		hit.emit(result.collider, result.position, result.normal)
		_apply_damage(result.collider, result.position)
	_spawn_tracer(muzzle.global_position if muzzle else origin, end)


func _fire_projectile(origin: Vector3, direction: Vector3, exclude: Array[RID]) -> void:
	# Il proiettile parte dalla canna ma va verso il punto sotto il mirino.
	var target := origin + direction * data.max_range
	var aim := _raycast(origin, target, exclude, PROJECTILE_MASK)
	if aim:
		target = aim.position
	var start := muzzle.global_position if muzzle else origin
	# Se la canna è dentro un muro, parte dalla testa: niente colpi attraverso i muri.
	if _raycast(origin, start, exclude, PROJECTILE_MASK):
		start = origin
	var launch_direction := direction
	if start.distance_to(target) > 1.0:
		launch_direction = (target - start).normalized()

	var projectile: Projectile = data.projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.dealt_damage.connect(_on_projectile_dealt_damage)
	projectile.launch(start, launch_direction, data, owner, exclude, PROJECTILE_MASK)


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
	# Si mostra il danno inflitto davvero: corazze e punti deboli lo cambiano.
	var dealt := target.take_damage(data.damage, owner, point)
	var killed := not target.is_alive()
	_spawn_damage_number(point, dealt, killed)
	dealt_damage.emit(target, dealt, killed)


func _on_projectile_dealt_damage(target: HealthComponent, amount: float, killed: bool) -> void:
	dealt_damage.emit(target, amount, killed)


func _raycast(from: Vector3, to: Vector3, exclude: Array[RID], mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query)


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
