class_name Projectile
extends Node3D
## Proiettile fisico: vola con la sua velocità, cade con la gravità e colpisce
## la prima cosa che incontra. Se l'arma lo prevede, all'impatto esplode.
##
## A ogni tick si controlla con un raggio il tratto tra la posizione vecchia e
## quella nuova: così anche i proiettili velocissimi non attraversano i muri.
## Predisposto per la rete: in multiplayer i proiettili li simulerà l'host.

## Il proiettile (o la sua esplosione) ha fatto danno a qualcosa.
signal dealt_damage(target: HealthComponent, amount: float, killed: bool)

const LAYER_WORLD := 1

@export var impact_scene: PackedScene
@export var explosion_scene: PackedScene
@export var damage_number_scene: PackedScene

var velocity := Vector3.ZERO
var _data: WeaponData
var _source: Node
var _exclude: Array[RID] = []
var _mask := 0
var _life := 0.0

@onready var _trail: CPUParticles3D = get_node_or_null("Trail")


## Fa partire il proiettile da start verso direction. source è chi ha sparato;
## exclude sono i corpi da ignorare; mask sono i layer che può colpire.
func launch(start: Vector3, direction: Vector3, data: WeaponData, source: Node,
		exclude: Array[RID], mask: int) -> void:
	_data = data
	_source = source
	_exclude = exclude
	_mask = mask
	_life = data.projectile_lifetime
	velocity = direction.normalized() * data.projectile_speed
	global_position = start
	_face_velocity()
	reset_physics_interpolation()
	# La scia parte solo ora, già nel punto giusto (vedi le scintille dei colpi).
	if _trail:
		_trail.restart()
		_trail.emitting = true


func _physics_process(delta: float) -> void:
	if _data == null:
		return
	velocity.y -= _data.projectile_gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, _mask, _exclude)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		global_position = result.position
		_impact(result.collider, result.position, result.normal)
		return
	global_position = to
	_face_velocity()
	_life -= delta
	if _life <= 0.0:
		if _data.explosion_radius > 0.0:
			_explode(global_position)
		queue_free()


func _impact(collider: Object, point: Vector3, normal: Vector3) -> void:
	if _data.damage > 0.0:
		_damage(HealthComponent.of(collider), _data.damage, point, point)
	if _data.explosion_radius > 0.0:
		_explode(point + normal * 0.1)
	elif impact_scene:
		var impact: ImpactEffect = impact_scene.instantiate()
		get_tree().current_scene.add_child(impact)
		impact.place(point, normal)
	queue_free()


## Danno ad area: pieno al centro, 40% al bordo; i muri riparano.
func _explode(center: Vector3) -> void:
	if explosion_scene:
		var effect: ExplosionEffect = explosion_scene.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.play(center, _data.explosion_radius)

	var sphere := SphereShape3D.new()
	sphere.radius = _data.explosion_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = _mask
	params.exclude = _exclude
	# Le strutture distruttibili controllano da sole quali blocchi sono nel raggio.
	for structure: DestructibleBlocks in get_tree().get_nodes_in_group("destructibles"):
		structure.damage_sphere(center, _data.explosion_radius, _data.explosion_damage, 8.0)
	var hit_bodies := {}
	for result in get_world_3d().direct_space_state.intersect_shape(params, 128):
		var body: Node3D = result.collider
		if hit_bodies.has(body):
			continue
		hit_bodies[body] = true
		var health := HealthComponent.of(body)
		if health == null or not health.is_alive():
			continue
		var body_center: Vector3 = body.center() if body is Enemy else body.global_position + Vector3.UP
		if _blocked(center, body_center, body):
			continue
		var closeness := clampf(1.0 - center.distance_to(body_center) / _data.explosion_radius, 0.0, 1.0)
		# Il punto colpito è il centro dell'esplosione: le corazze capiscono da che lato arriva.
		_damage(health, _data.explosion_damage * lerpf(0.4, 1.0, closeness), center, body_center)
		if body is Enemy and _data.explosion_knockback > 0.0:
			var away := Vector3(body_center.x - center.x, 0.0, body_center.z - center.z).normalized()
			body.apply_knockback(away * _data.explosion_knockback * lerpf(0.5, 1.0, closeness)
					+ Vector3.UP * 5.0, 0.0, _source)


func _damage(health: HealthComponent, amount: float, hit_position: Vector3, number_position: Vector3) -> void:
	if health == null or not health.is_alive():
		return
	var dealt := health.take_damage(amount, _source, hit_position)
	var killed := not health.is_alive()
	if damage_number_scene and dealt > 0.0:
		var number: DamageNumber = damage_number_scene.instantiate()
		get_tree().current_scene.add_child(number)
		number.show_value(dealt, number_position, killed)
	dealt_damage.emit(health, dealt, killed)


## Vero se tra il centro dell'esplosione e il bersaglio c'è un muro.
func _blocked(from: Vector3, to: Vector3, target: Node) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.collider != target


func _face_velocity() -> void:
	if velocity.length() < 0.01:
		return
	var up := Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.FORWARD
	global_basis = Basis.looking_at(velocity, up)
