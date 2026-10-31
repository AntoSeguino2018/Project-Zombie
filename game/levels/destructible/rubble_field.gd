class_name RubbleField
extends Node3D
## Macerie del livello. I pezzi delle strutture distrutte volano come corpi
## fisici; quando si fermano diventano macerie permanenti, disegnate tutte
## insieme (MultiMesh) e senza più costo per la fisica. Così restano a terra
## per sempre senza appesantire il gioco.
## Ce n'è una per livello, creata alla prima distruzione: RubbleField.of(nodo).
## Le macerie ferme sono solo visive: giocatori e zombie ci passano attraverso,
## come già succede con i pezzi in volo.

## Pezzi in volo al massimo nello stesso momento (contando quelli in coda).
const MAX_FLYING := 160
## Pezzi creati al massimo per tick: un grosso crollo si distribuisce su qualche
## tick invece di bloccare un singolo frame.
const SPAWN_PER_TICK := 30
## Macerie ferme per ogni MultiMesh; quando è piena se ne crea un'altra.
const BATCH_SIZE := 2048
## Un pezzo si considera fermo sotto questa velocità, in m/s...
const REST_SPEED := 0.15
## ...e comunque diventa maceria dopo questi secondi di volo.
const MAX_FLIGHT_TIME := 6.0
## Sotto questa quota il pezzo è caduto fuori dal livello: non diventa maceria.
const LOST_HEIGHT := -50.0

## Pezzi in volo: [corpo, colore, lato, secondi di volo].
var _flying: Array = []
## Pezzi in attesa di essere creati: [trasformazione, lato, colore, velocità].
var _pending: Array = []
## Lato del pezzo -> MultiMeshInstance3D delle macerie ferme di quel lato.
var _batches := {}
## Colore -> materiale dei pezzi in volo (pochi colori, materiali condivisi).
var _materials := {}


## Il campo macerie del livello in cui si trova node (lo crea se non c'è).
static func of(node: Node) -> RubbleField:
	var scene := node.get_tree().current_scene
	var field: RubbleField = scene.get_node_or_null("RubbleField")
	if field == null:
		field = RubbleField.new()
		field.name = "RubbleField"
		scene.add_child(field)
	return field


func can_spawn() -> bool:
	return _flying.size() + _pending.size() < MAX_FLYING


## Pezzi in volo, compresi quelli in coda.
func flying_count() -> int:
	return _flying.size() + _pending.size()


func rubble_count() -> int:
	var total := 0
	for batches in _batches.values():
		for batch: MultiMeshInstance3D in batches:
			total += batch.multimesh.visible_instance_count
	return total


## Lancia un pezzo cubico di lato size dalla posizione e rotazione indicate
## (entro pochi tick). Restituisce falso se ci sono già troppi pezzi in volo.
func spawn(start: Transform3D, size: float, color: Color, velocity: Vector3) -> bool:
	if not can_spawn():
		return false
	_pending.append([start, size, color, velocity])
	return true


func _create_piece(start: Transform3D, size: float, color: Color, velocity: Vector3) -> void:
	var body := RigidBody3D.new()
	body.collision_layer = DestructibleBlocks.LAYER_DEBRIS
	body.collision_mask = DestructibleBlocks.LAYER_WORLD
	body.mass = 1.0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3.ONE * size
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * size
	box.material = _material_for(color)
	mesh.mesh = box
	body.add_child(mesh)
	add_child(body)
	body.global_transform = start
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	_flying.append([body, color, size, 0.0])


func _physics_process(delta: float) -> void:
	for n in mini(SPAWN_PER_TICK, _pending.size()):
		var piece: Array = _pending.pop_front()
		_create_piece(piece[0], piece[1], piece[2], piece[3])
	for i in range(_flying.size() - 1, -1, -1):
		var item: Array = _flying[i]
		var body: RigidBody3D = item[0]
		item[3] += delta
		var resting: bool = item[3] > 0.5 and (body.sleeping or (body.linear_velocity.length() < REST_SPEED
				and body.angular_velocity.length() < REST_SPEED * 4.0))
		if resting or item[3] > MAX_FLIGHT_TIME or body.global_position.y < LOST_HEIGHT:
			if body.global_position.y >= LOST_HEIGHT:
				_add_rubble(body.global_transform, item[2], item[1])
			body.queue_free()
			_flying.remove_at(i)


func _add_rubble(where: Transform3D, size: float, color: Color) -> void:
	var multimesh := _batch_for(size).multimesh
	var i := multimesh.visible_instance_count
	multimesh.set_instance_transform(i, where)
	# I colori delle istanze vengono letti come lineari: stessa tinta dei pezzi in volo.
	multimesh.set_instance_color(i, color.srgb_to_linear())
	multimesh.visible_instance_count = i + 1


func _batch_for(size: float) -> MultiMeshInstance3D:
	var batches: Array = _batches.get(size, [])
	if batches.is_empty() or batches[-1].multimesh.visible_instance_count >= BATCH_SIZE:
		var box := BoxMesh.new()
		box.size = Vector3.ONE * size
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		box.material = material
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = box
		multimesh.instance_count = BATCH_SIZE
		multimesh.visible_instance_count = 0
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multimesh
		# Le macerie possono finire ovunque nel livello: niente scarto per visibilità.
		batch.custom_aabb = AABB(Vector3(-1000.0, -100.0, -1000.0), Vector3(2000.0, 400.0, 2000.0))
		add_child(batch)
		batches.append(batch)
		_batches[size] = batches
	return batches[-1]


func _material_for(color: Color) -> StandardMaterial3D:
	# Sfumature arrotondate: pochi materiali condivisi invece di uno per pezzo.
	var key := Color(snappedf(color.r, 0.05), snappedf(color.g, 0.05), snappedf(color.b, 0.05))
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = key
		_materials[key] = material
	return _materials[key]
