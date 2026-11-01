class_name Weapon
extends Node3D
## Arma in mano al giocatore. A seconda dei suoi dati spara colpi istantanei
## (hitscan, anche a pallini, rimbalzanti, perforanti, esplosivi o incendiari)
## oppure proiettili fisici. Tiene anche le armi portate (loadout, al massimo
## MAX_WEAPONS), gestisce il cambio, i caricatori e la ricarica (automatica
## quando si svuota).
##
## Il nodo sta sotto la camera e contiene il modello in prima persona dell'arma
## equipaggiata: a ogni colpo arretra e si alza, poi torna in posizione.
## In rete chi spara vede subito i suoi colpi (scia, impatti, proiettili) e
## li manda agli altri, che li mostrano dall'arma del suo giocatore. Il danno
## invece lo decide l'host: riceve cosa ha colpito il tiratore, controlla che
## sia plausibile, applica il danno della sua copia dell'arma e rimanda al
## tiratore quanto ha inflitto (numeri e hitmarker).
## Anche le armi portate le decide l'host (si raccolgono dalle casse): manda a
## tutti il nuovo loadout, così ognuno ha le stesse armi per ogni giocatore.

signal fired
signal hit(collider: Object, position: Vector3, normal: Vector3)
## Un colpo (o un'esplosione) ha fatto danno a qualcosa con un HealthComponent.
signal dealt_damage(target: HealthComponent, amount: float, killed: bool)
## È stata presa in mano un'altra arma.
signal equipped(data: WeaponData)
## Sono cambiate le armi portate.
signal loadout_changed

## Mondo e nemici: colpi e proiettili attraversano i compagni (niente fuoco
## amico) e i detriti.
const TARGET_MASK := 1 | 4
## Armi che si possono portare insieme.
const MAX_WEAPONS := 2

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
@export var explosion_scene: PackedScene

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
## Moltiplicatori di boost e oggetti (li imposta il giocatore).
var fire_rate_multiplier := 1.0
var reload_speed_multiplier := 1.0
var magazine_multiplier := 1.0

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
		_ammo.append(magazine_of(weapon_data))
	if not loadout.is_empty():
		equip(0)
		_switch_left = 0.0
	# Chi arriva a partita iniziata chiede all'host le armi già raccolte.
	if NetSession.is_online() and not multiplayer.is_server():
		_request_loadout.rpc_id(1)


func _physics_process(delta: float) -> void:
	# Il limite a -delta conserva al massimo un tick di "resto": la cadenza reale
	# resta quella impostata anche se non è un multiplo dei 60 Hz della fisica.
	_cooldown = maxf(_cooldown - delta, -delta)
	_switch_left = maxf(_switch_left - delta, 0.0)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			_ammo[_slot] = magazine_of(data)


func _process(delta: float) -> void:
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-kick_recovery * delta))
	# Durante il cambio l'arma scende fuori dallo schermo e risale.
	var lowered := _switch_left / switch_time if switch_time > 0.0 else 0.0
	# In ricarica l'arma si abbassa e si inclina di lato, poi torna su.
	var reloading := sin(reload_progress() * PI) if is_reloading() else 0.0
	position = _rest_position + Vector3(0.0, -0.3 * lowered - 0.1 * reloading, _kick * kick_distance)
	rotation.x = deg_to_rad(_kick * kick_angle_degrees) - 0.6 * lowered - 0.3 * reloading
	rotation.z = 0.6 * reloading


## Prende in mano l'arma nello slot indicato del loadout. Con force la
## riprende anche se è già quella in mano (per esempio dopo uno scambio).
func equip(slot: int, force := false) -> void:
	if slot < 0 or slot >= loadout.size() or (slot == _slot and not force):
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


## Gli spec delle armi portate (vedi WeaponCatalog).
func specs() -> Array:
	return loadout.map(func(weapon_data: WeaponData): return weapon_data.spec())


## Sull'host: il giocatore raccoglie l'arma spec. Se ha già le mani piene la
## scambia con quella nello slot indicato (quella in mano) e restituisce lo
## spec dell'arma lasciata, altrimenti un array vuoto.
func host_pick_up(spec: Array, slot: int) -> Array:
	var new_specs := specs()
	var dropped: Array = []
	if new_specs.size() < MAX_WEAPONS:
		new_specs.append(spec)
		slot = new_specs.size() - 1
	else:
		slot = clampi(slot, 0, new_specs.size() - 1)
		dropped = new_specs[slot]
		new_specs[slot] = spec
	host_set_loadout(new_specs, slot)
	return dropped


## Sull'host: cambia le armi portate e le manda a tutti; il giocatore prende
## in mano quella in equip_slot (-1 = resta quella che ha).
func host_set_loadout(new_specs: Array, equip_slot := -1) -> void:
	if not multiplayer.is_server():
		return
	_apply_loadout(new_specs, equip_slot)
	if NetSession.is_online():
		_receive_loadout.rpc(new_specs, equip_slot)


## Riempie i caricatori di tutte le armi (alla rinascita).
func refill() -> void:
	for i in loadout.size():
		_ammo[i] = magazine_of(loadout[i])
	_reload_left = 0.0


func _apply_loadout(new_specs: Array, equip_slot: int) -> void:
	var old_specs := specs()
	var old_ammo := _ammo.duplicate()
	loadout = WeaponCatalog.build_all(new_specs)
	_ammo.clear()
	for i in loadout.size():
		# Le armi che restano uguali tengono i colpi rimasti; quelle nuove sono piene.
		var same: bool = i < old_specs.size() and old_specs[i] == new_specs[i]
		_ammo.append(old_ammo[i] if same else magazine_of(loadout[i]))
	var changed_in_hand: bool = _slot < 0 or _slot >= loadout.size() \
			or _slot >= old_specs.size() or old_specs[_slot] != new_specs[_slot]
	if equip_slot >= 0:
		equip(equip_slot, true)
	elif changed_in_hand:
		equip(clampi(_slot, 0, loadout.size() - 1), true)
	loadout_changed.emit()


## Sull'host: un partecipante chiede le armi di questo giocatore.
@rpc("any_peer", "call_remote", "reliable")
func _request_loadout() -> void:
	if multiplayer.is_server():
		_receive_loadout.rpc_id(multiplayer.get_remote_sender_id(), specs(), -1)


@rpc("any_peer", "call_remote", "reliable")
func _receive_loadout(new_specs: Array, equip_slot: int) -> void:
	if multiplayer.get_remote_sender_id() == 1:
		_apply_loadout(new_specs, equip_slot)


func can_fire() -> bool:
	return data != null and _cooldown <= 0.0 and _switch_left <= 0.0 \
			and not is_reloading() and (ammo() > 0 or data.magazine_size <= 0)


## Colpi rimasti nel caricatore dell'arma in mano.
func ammo() -> int:
	return _ammo[_slot] if _slot >= 0 and _slot < _ammo.size() else 0


func is_reloading() -> bool:
	return _reload_left > 0.0


## Da 0 (appena iniziata) a 1 (finita).
func reload_progress() -> float:
	if not is_reloading() or data.reload_time <= 0.0:
		return 0.0
	return 1.0 - _reload_left / (data.reload_time / reload_speed_multiplier)


## Inizia a ricaricare, se serve e se non si sta già ricaricando.
func start_reload() -> void:
	if data == null or data.magazine_size <= 0 or is_reloading() or _switch_left > 0.0:
		return
	if ammo() >= magazine_of(data):
		return
	_reload_left = maxf(data.reload_time / reload_speed_multiplier, 0.01)


## Colpi in un caricatore pieno di weapon_data, con gli oggetti del giocatore
## (0 o meno = munizioni infinite).
func magazine_of(weapon_data: WeaponData) -> int:
	if weapon_data.magazine_size <= 0:
		return weapon_data.magazine_size
	return ceili(weapon_data.magazine_size * magazine_multiplier - 0.001)


## Spara un colpo da origin verso direction. exclude: corpi da ignorare (chi spara).
## In rete lo chiama solo chi controlla il giocatore.
func fire(origin: Vector3, direction: Vector3, exclude: Array[RID] = []) -> void:
	_cooldown += 1.0 / (data.fire_rate * fire_rate_multiplier)
	_kick = 1.0
	if data.magazine_size > 0 and _slot < _ammo.size():
		_ammo[_slot] = maxi(_ammo[_slot] - 1, 0)
	if data.projectile_scene:
		_fire_projectile(origin, _apply_spread(direction.normalized()), exclude)
	else:
		_fire_hitscan(origin, direction.normalized(), exclude)
	fired.emit()
	if data.magazine_size > 0 and ammo() == 0:
		start_reload()


func _fire_hitscan(origin: Vector3, direction: Vector3, exclude: Array[RID]) -> void:
	var shot := {
		# Coppie di punti: inizio e fine di ogni tratto da disegnare.
		"segments": PackedVector3Array(),
		# Per ogni tratto la normale di quello che ha preso (zero = niente).
		"normals": PackedVector3Array(),
		# [HealthComponent, punto] per ogni bersaglio colpito.
		"hits": [],
		"blasts": PackedVector3Array(),
	}
	var from := muzzle.global_position if muzzle else origin
	for i in data.pellets:
		_trace(origin, _apply_spread(direction), exclude, from, shot)
	_show_shot(shot.segments, shot.normals, shot.blasts, data.explosion_radius)
	if NetSession.is_online():
		_show_remote_shot.rpc(shot.segments, shot.normals, shot.blasts, data.explosion_radius)
	if multiplayer.is_server():
		_host_shot_damage(data, shot.hits, shot.blasts)
	elif not shot.hits.is_empty() or not shot.blasts.is_empty():
		var paths: Array[NodePath] = []
		var points := PackedVector3Array()
		for target_hit in shot.hits:
			paths.append(target_hit[0].get_path())
			points.append(target_hit[1])
		_request_damage.rpc_id(1, paths, points, shot.blasts, _slot)


## Segue un pallino: se l'arma lo prevede rimbalza sui muri, attraversa i
## nemici o esplode. Aggiunge a shot i tratti da disegnare, i bersagli e le
## esplosioni. visual_from è da dove si disegna il primo tratto (la canna).
func _trace(origin: Vector3, direction: Vector3, exclude: Array[RID], visual_from: Vector3,
		shot: Dictionary) -> void:
	var skip := exclude.duplicate()
	var from := origin
	var remaining := data.max_range
	var bounces_left := data.bounces
	var pierce_left := data.pierce
	while remaining > 0.1:
		var result := _raycast(from, from + direction * remaining, skip, TARGET_MASK)
		var end: Vector3 = result.position if result else from + direction * remaining
		shot.segments.append(visual_from)
		shot.segments.append(end)
		shot.normals.append(result.normal if result else Vector3.ZERO)
		if not result:
			return
		remaining -= from.distance_to(end)
		hit.emit(result.collider, end, result.normal)
		var target := HealthComponent.of(result.collider)
		if target and target.is_alive():
			shot.hits.append([target, end])
		if data.explosion_radius > 0.0:
			shot.blasts.append(end + result.normal * 0.1)
			return
		if target and pierce_left > 0:
			pierce_left -= 1
			skip.append(result.rid)
			from = end
		elif target == null and bounces_left > 0:
			bounces_left -= 1
			direction = direction.bounce(result.normal)
			from = end + result.normal * 0.02
		else:
			return
		visual_from = end


## Scie, impatti ed esplosioni di un colpo istantaneo (anche di un altro).
func _show_shot(segments: PackedVector3Array, normals: PackedVector3Array,
		blasts: PackedVector3Array, blast_radius: float) -> void:
	for i in normals.size():
		var to := segments[i * 2 + 1]
		if normals[i] != Vector3.ZERO and blasts.is_empty():
			_spawn_impact(to, normals[i])
		_spawn_tracer(segments[i * 2], to)
	for center in blasts:
		Explosion.show(self, explosion_scene, center, blast_radius)


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


## Sull'host: applica i danni di un colpo (tutti i pallini, il fuoco, le
## esplosioni) e fa sapere al tiratore quanto ha inflitto, un numero per bersaglio.
func _host_shot_damage(weapon_data: WeaponData, hits: Array, blasts: PackedVector3Array) -> void:
	var totals := {}
	var add := func(target: HealthComponent, dealt: float, _killed: bool, point: Vector3) -> void:
		var total: float = totals[target][0] if totals.has(target) else 0.0
		totals[target] = [total + dealt, point]
	for target_hit in hits:
		var target: HealthComponent = target_hit[0]
		if not target.is_alive():
			continue
		add.call(target, target.take_damage(weapon_data.damage, owner, target_hit[1]), false, target_hit[1])
		target.ignite(weapon_data.burn_damage, weapon_data.burn_time, owner)
	var no_exclude: Array[RID] = []
	for center in blasts:
		Explosion.blast(self, center, weapon_data, owner, TARGET_MASK, no_exclude, add)
	for target: HealthComponent in totals:
		_report_damage(target, totals[target][0], not target.is_alive(), totals[target][1])


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


## Sull'host: un colpo istantaneo del tiratore ha preso i bersagli in
## target_paths (nei punti points) e ha fatto esplodere blasts.
@rpc("any_peer", "call_remote", "reliable")
func _request_damage(target_paths: Array, points: PackedVector3Array, blasts: PackedVector3Array,
		slot: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	if not _shooter_alive() or slot < 0 or slot >= loadout.size() or target_paths.size() != points.size():
		return
	var weapon_data := loadout[slot]
	# Niente colpi impossibili: non più bersagli ed esplosioni di quanti ne
	# può fare l'arma, e tutti a portata.
	var max_blasts := weapon_data.pellets if weapon_data.explosion_radius > 0.0 else 0
	if points.size() > weapon_data.pellets * (weapon_data.pierce + 1) or blasts.size() > max_blasts:
		return
	var reach := weapon_data.max_range + 5.0
	var hits := []
	for i in points.size():
		var target := get_node_or_null(target_paths[i]) as HealthComponent
		if target and owner.global_position.distance_to(points[i]) <= reach:
			hits.append([target, points[i]])
	var valid_blasts := PackedVector3Array()
	for center in blasts:
		if owner.global_position.distance_to(center) <= reach:
			valid_blasts.append(center)
	_host_shot_damage(weapon_data, hits, valid_blasts)


## Sul tiratore: l'host conferma il danno di un suo colpo.
@rpc("any_peer", "call_remote", "reliable")
func _confirm_damage(target_path: NodePath, dealt: float, killed: bool, point: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	_show_damage(get_node_or_null(target_path) as HealthComponent, dealt, killed, point)


## Sugli altri: scie, impatti ed esplosioni di un colpo istantaneo del tiratore.
@rpc("authority", "call_remote", "unreliable_ordered")
func _show_remote_shot(segments: PackedVector3Array, normals: PackedVector3Array,
		blasts: PackedVector3Array, blast_radius: float) -> void:
	if segments.size() == normals.size() * 2:
		_show_shot(segments, normals, blasts, blast_radius)


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
