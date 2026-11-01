class_name Explosion
extends RefCounted
## Esplosioni condivise da granate e colpi esplosivi.
##
## show() è la parte che vedono tutti (fiammata, macerie rilanciate);
## blast() è il danno, che in rete calcola solo l'host: pieno al centro, 40%
## al bordo, i muri riparano. Rompe anche le strutture distruttibili.

const LAYER_WORLD := 1


static func show(node: Node, effect_scene: PackedScene, center: Vector3, radius: float) -> void:
	if effect_scene:
		var effect: ExplosionEffect = effect_scene.instantiate()
		node.get_tree().current_scene.add_child(effect)
		effect.play(center, radius)
	# Le macerie ancora spostabili vengono rilanciate (sono di ognuno, non sincronizzate).
	RubbleField.of(node).push_sphere(center, radius * 1.5, 10.0)


## Danneggia tutto quello che è nel raggio. on_damage riceve
## (health, dealt, killed, number_position) per ogni bersaglio colpito.
static func blast(node: Node3D, center: Vector3, data: WeaponData, source: Node,
		mask: int, exclude: Array[RID], on_damage: Callable) -> void:
	var radius := data.explosion_radius
	for structure: DestructibleBlocks in node.get_tree().get_nodes_in_group("destructibles"):
		structure.damage_sphere(center, radius, data.explosion_damage, 8.0)
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = mask
	params.exclude = exclude
	var space := node.get_world_3d().direct_space_state
	var hit_bodies := {}
	for result in space.intersect_shape(params, 128):
		var body: Node3D = result.collider
		if hit_bodies.has(body):
			continue
		hit_bodies[body] = true
		var health := HealthComponent.of(body)
		if health == null or not health.is_alive():
			continue
		var body_center: Vector3 = body.center() if body is Enemy else body.global_position + Vector3.UP
		if _blocked(space, center, body_center, body):
			continue
		var closeness := clampf(1.0 - center.distance_to(body_center) / radius, 0.0, 1.0)
		# Il punto colpito è il centro dell'esplosione: le corazze capiscono da che lato arriva.
		var dealt := health.take_damage(data.explosion_damage * lerpf(0.4, 1.0, closeness), source, center)
		on_damage.call(health, dealt, not health.is_alive(), body_center)
		if body is Enemy and data.explosion_knockback > 0.0:
			var away := Vector3(body_center.x - center.x, 0.0, body_center.z - center.z).normalized()
			body.apply_knockback(away * data.explosion_knockback * lerpf(0.5, 1.0, closeness)
					+ Vector3.UP * minf(5.0, data.explosion_knockback), 0.0, source)


## Vero se tra il centro dell'esplosione e il bersaglio c'è un muro.
static func _blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, target: Node) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD)
	var result := space.intersect_ray(query)
	return not result.is_empty() and result.collider != target
