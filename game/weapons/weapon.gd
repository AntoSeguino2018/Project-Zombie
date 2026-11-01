class_name Weapon
extends Node3D
## Arma in mano al giocatore. A seconda dei suoi dati spara colpi istantanei
## (hitscan) oppure proiettili fisici. Tiene anche le armi portate (loadout),
## gestisce il cambio, i caricatori e la ricarica (automatica quando si svuota).
##
## Il nodo sta sotto la camera e contiene il modello in prima persona dell'arma
## equipaggiata: a ogni colpo arretra e si alza, poi torna in posizione.
## In rete chi spara vede subito i suoi colpi (scia, impatti, proiettili) e
## li manda agli altri, che li mostrano dall'arma del suo giocatore. Il danno
## invece lo decide l'host: riceve cosa ha colpito il tiratore, controlla che
## sia plausibile, applica il danno della sua copia dell'arma e rimanda al
## tiratore quanto ha inflitto (numeri e hitmarker).

signal fired
signal hit(collider: Object, position: Vector3, normal: Vector3)
## Un colpo (o un'esplosione) ha fatto danno a qualcosa con un HealthComponent.
signal dealt_damage(target: HealthComponent, amount: float, killed: bool)
## È stata presa in mano un'altra arma.
signal equipped(data: WeaponData)

## Mondo e nemici: colpi e proiettili attraversano i compagni (niente fuoco
## amico) e i detriti.
const TARGET_MASK := 1 | 4

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
## Colpi rimasti nel caricatore di ogni arma del loadout.
var _ammo: Array[int] = []
var _reload_left := 0.0
var _model: Node3D
var _cooldown := 0.0
var _kick := 0.0
var _switch_left := 0.0
var _rest_position := Vector3.ZERO


func _ready() -> void:
	_rest_position = position
	for weapon_data in loadout:
		_ammo.append(weapon_data.magazine_size)
	if not loadout.is_empty():
		equip(0)
		_switch_left = 0.0


func _physics_process(delta: float) -> void:
	# Il limite a -delta conserva al massimo un tick di "resto": la cadenza reale
	# resta quella impostata anche se non è un multiplo dei 60 Hz della fisica.
	_cooldown = maxf(_cooldown - delta, -delta)
	_switch_left = maxf(_switch_left - delta, 0.0)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			_ammo[_slot] = data.magazine_size


func _process(delta: float) -> void:
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-kick_recovery * delta))
	# Durante il cambio l'arma scende fuori dallo schermo e risale.
	var lowered := _switch_left / switch_time if switch_time > 0.0 else 0.0
	# In ricarica l'arma si abbassa e si inclina di lato, poi torna su.
	var reloading := sin(reload_progress() * PI) if is_reloading() else 0.0
	position = _rest_position + Vector3(0.0, -0.3 * lowered - 0.1 * reloading, _kick * kick_distance)
	rotation.x = deg_to_rad(_kick * kick_angle_degrees) - 0.6 * lowered - 0.3 * reloading
	rotation.z = 0.6 * reloading


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
	# Cambiare arma interrompe la ricarica.
	_reload_left = 0.0
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
	return data != null and _cooldown <= 0.0 and _switch_left <= 0.0 			and not is_reloading() and (ammo() > 0 or data.magazine_size <= 0)


## Colpi rimasti nel caricatore dell'arma in mano.
func ammo() -> int:
	return _ammo[_slot] if _slot >= 0 and _slot < _ammo.size() else 0


func is_reloading() -> bool:
	return _reload_left > 0.0


## Da 0 (appena iniziata) a 1 (finita).
func reload_progress() -> float:
	if not is_reloading() or data.reload_time <= 0.0:
		return 0.0
	return 1.0 - _reload_left / data.reload_time


## Inizia a ricaricare, se serve e se non si sta già ricaricando.
func start_reload() -> void:
	if data == null or data.magazine_size <= 0 or is_reloading() or _switch_left > 0.0:
		return
	if ammo() >= data.magazine_size:
		return
	_reload_left = maxf(data.reload_time, 0.01)


## Spara un colpo da origin verso direction. exclude: corpi da ignorare (chi spara).
## In rete lo chiama solo chi controlla il giocatore.
func fire(origin: Vector3, direction: Vector3, exclude: Array[RID] = []) -> void:
	_cooldown += 1.0 / data.fire_rate
	_kick = 1.0
	if data.magazine_size > 0 and _slot < _ammo.size():
		_ammo[_slot] = maxi(_ammo[_slot] - 1, 0)
	var shot_direction := _apply_spread(direction.normalized())
	if data.projectile_scene:
		_fire_projectile(origin, shot_direction, exclude)
	else:
		_fire_hitscan(origin, shot_direction, exclude)
	fired.emit()
	if data.magazine_size > 0 and ammo() == 0:
		start_reload()


func _fire_hitscan(origin: Vector3, direction: Vector3, exclude: Array[RID]) -> void:
	var end := origin + direction * data.max_range
	var result := _raycast(origin, end, exclude, TARGET_MASK)
	if result:
		end = result.position
		_spawn_impact(result.position, result.normal)
		hit.emit(result.collider, result.position, result.normal)
		_damage_target(result.collider, result.position)
	var from := muzzle.global_position if muzzle else origin
	_spawn_tracer(from, end)
	if NetSession.is_online():
		_show_remote_shot.rpc(from, end, result.normal if result else Vector3.ZERO)


func _fire_projectile(origin: Vector3, direction: Vector3, exclude: Array[RID]) -> void:
	# Il proiettile parte dalla canna ma va verso il punto sotto il mirino.
	var target := origin + direction * data.max_range
	var aim := _raycast(origin, target, exclude, TARGET_MASK)
	if aim:
		target = aim.position
	var start := muzzle.global_position if muzzle else origin
	# Se la canna è dentro un muro, parte dalla testa: niente colpi attraverso i muri.
	if _raycast(origin, start, exclude, TARGET_MASK):
		start = origin
	var launch_direction := direction
	if start.distance_to(target) > 1.0:
		launch_direction = (target - start).normalized()

	_launch_projectile(data, start, launch_direction, exclude)
	if NetSession.is_online():
		_launch_remote_projectile.rpc(_slot, start, launch_direction)


## Fa partire un proiettile; solo quello dell'host fa danni.
func _launch_projectile(weapon_data: WeaponData, start: Vector3, direction: Vector3,
		exclude: Array[RID]) -> void:
	var projectile: Projectile = weapon_data.projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.dealt_damage.connect(_on_projectile_dealt_damage)
	projectile.launch(start, direction, weapon_data, owner, exclude, TARGET_MASK,
			multiplayer.is_server())


func _apply_spread(direction: Vector3) -> Vector3:
	var max_angle := deg_to_rad(data.spread_degrees)
	if max_angle <= 0.0:
		return direction
	var side_axis := Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
	var tilted := direction.rotated(direction.cross(side_axis).normalized(), randf() * max_angle)
	return tilted.rotated(direction, randf() * TAU)


## Il colpo ha preso qualcosa: il danno lo applica l'host (subito, se siamo noi).
func _damage_target(collider: Object, point: Vector3) -> void:
	var target := HealthComponent.of(collider)
	if not target or not target.is_alive():
		return
	if multiplayer.is_server():
		_host_damage(target, data.damage, point)
	else:
		_request_damage.rpc_id(1, target.get_path(), point, _slot)


func _host_damage(target: HealthComponent, amount: float, point: Vector3) -> void:
	var dealt := target.take_damage(amount, owner, point)
	_report_damage(target, dealt, not target.is_alive(), point)


func _on_projectile_dealt_damage(target: HealthComponent, amount: float, killed: bool,
		point: Vector3) -> void:
	_report_damage(target, amount, killed, point)


## Fa sapere a chi ha sparato quanto danno ha inflitto davvero (corazze e
## punti deboli lo cambiano): numero sul bersaglio e hitmarker solo per lui.
func _report_damage(target: HealthComponent, dealt: float, killed: bool, point: Vector3) -> void:
	if is_multiplayer_authority():
		_show_damage(target, dealt, killed, point)
	else:
		_confirm_damage.rpc_id(get_multiplayer_authority(), target.get_path(), dealt, killed, point)


func _show_damage(target: HealthComponent, dealt: float, killed: bool, point: Vector3) -> void:
	if dealt > 0.0:
		_spawn_damage_number(point, dealt, killed)
	dealt_damage.emit(target, dealt, killed)


## Sull'host: un colpo istantaneo del tiratore ha preso target_path.
@rpc("any_peer", "call_remote", "reliable")
func _request_damage(target_path: NodePath, point: Vector3, slot: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	var target := get_node_or_null(target_path) as HealthComponent
	if target == null or not target.is_alive() or not _shooter_alive() 			or slot < 0 or slot >= loadout.size():
		return
	# Niente colpi impossibili: il punto deve essere a portata dell'arma.
	if owner.global_position.distance_to(point) > loadout[slot].max_range + 5.0:
		return
	_host_damage(target, loadout[slot].damage, point)


## Sul tiratore: l'host conferma il danno di un suo colpo.
@rpc("any_peer", "call_remote", "reliable")
func _confirm_damage(target_path: NodePath, dealt: float, killed: bool, point: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	_show_damage(get_node_or_null(target_path) as HealthComponent, dealt, killed, point)


## Sugli altri: scia e impatto di un colpo istantaneo del tiratore.
## normal è zero se il colpo non ha preso niente.
@rpc("authority", "call_remote", "unreliable_ordered")
func _show_remote_shot(from: Vector3, to: Vector3, normal: Vector3) -> void:
	if normal != Vector3.ZERO:
		_spawn_impact(to, normal)
	_spawn_tracer(from, to)


## Sugli altri: lo stesso proiettile del tiratore, con la stessa partenza.
## Sull'host è quello vero, che fa danni.
@rpc("authority", "call_remote", "reliable")
func _launch_remote_projectile(slot: int, start: Vector3, direction: Vector3) -> void:
	if slot < 0 or slot >= loadout.size() or not loadout[slot].projectile_scene:
		return
	if multiplayer.is_server() and not _shooter_alive():
		return
	_launch_projectile(loadout[slot], start, direction, [])


func _shooter_alive() -> bool:
	var health := HealthComponent.of(owner)
	return health == null or health.is_alive()


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
