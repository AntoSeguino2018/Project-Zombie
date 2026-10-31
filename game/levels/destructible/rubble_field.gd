class_name RubbleField
extends Node3D
## Macerie del livello. I pezzi delle strutture distrutte sono corpi fisici:
## volano, cadono e, dopo aver toccato terra, restano spostabili per
## SETTLE_TIME secondi (giocatori e zombie li spingono camminando, le
## esplosioni li rilanciano). Poi diventano macerie immobili e permanenti,
## disegnate tutte insieme (MultiMesh) senza più costo per la fisica.
## Ce n'è una per livello, creata alla prima distruzione: RubbleField.of(nodo).
## I pezzi non bloccano mai giocatori e zombie: ci passano attraverso spingendoli.

## Pezzi fisici al massimo nello stesso momento (contando quelli in coda).
const MAX_ACTIVE := 300
## Pezzi creati al massimo per tick: un grosso crollo si distribuisce su qualche
## tick invece di bloccare un singolo frame.
const SPAWN_PER_TICK := 30
## Pezzi trasformati in macerie al massimo per tick, per lo stesso motivo.
const SETTLE_PER_TICK := 30
## Secondi in cui un pezzo resta spostabile dopo aver toccato terra.
const SETTLE_TIME := 10.0
## Un pezzo che non tocca mai nulla (es. incastrato in aria) si ferma comunque dopo
## questi secondi.
const MAX_LIFETIME := 30.0
## Macerie ferme per ogni MultiMesh; quando è piena se ne crea un'altra.
const BATCH_SIZE := 2048
## Sotto questa quota il pezzo è caduto fuori dal livello: non diventa maceria.
const LOST_HEIGHT := -50.0
## I pezzi urtano il mondo e vengono spinti da giocatori e zombie (che invece
## non urtano i pezzi). Tra loro non si urtano, per non appesantire la fisica.
const PIECE_MASK := 1 | 2 | 4

## Pezzi fisici: [corpo, colore, lato, secondi di vita, secondi da quando ha
## toccato terra (-1 = non ancora)].
var _active: Array = []
## Pezzi in attesa di essere creati: [trasformazione, lato, colore, velocità].
var _pending: Array = []
## Lato del pezzo -> MultiMeshInstance3D delle macerie ferme di quel lato.
var _batches := {}
## Colore -> materiale dei pezzi fisici (pochi colori, materiali condivisi).
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
	return _active.size() + _pending.size() < MAX_ACTIVE


## Pezzi ancora fisici (in volo o spostabili a terra), compresi quelli in coda.
func active_count() -> int:
	return _active.size() + _pending.size()


## Macerie diventate immobili.
func rubble_count() -> int:
	var total := 0
	for batches in _batches.values():
		for batch: MultiMeshInstance3D in batches:
			total += batch.multimesh.visible_instance_count
	return total


## Lancia un pezzo cubico di lato size dalla posizione e rotazione indicate
## (entro pochi tick). Restituisce falso se ci sono già troppi pezzi fisici.
func spawn(start: Transform3D, size: float, color: Color, velocity: Vector3) -> bool:
	if not can_spawn():
		return false
	_pending.append([start, size, color, velocity])
	return true


## Spinge via dal centro i pezzi ancora fisici entro radius (esplosioni):
## velocità speed vicino al centro, sempre meno verso il bordo.
func push_sphere(center: Vector3, radius: float, speed: float) -> void:
	for item in _active:
		var body: RigidBody3D = item[0]
		var offset := body.global_position - center
		var distance := offset.length()
		if distance > radius:
			continue
		var away := offset / distance if distance > 0.01 else Vector3.UP
		# Un impulso sveglia anche i pezzi fermi (una velocità impostata a mano no).
		body.apply_central_impulse((away + Vector3.UP * 0.5) * speed * (1.0 - distance / radius) * body.mass)


func _create_piece(start: Transform3D, size: float, color: Color, velocity: Vector3) -> void:
	var body := RigidBody3D.new()
	body.collision_layer = DestructibleBlocks.LAYER_DEBRIS
	body.collision_mask = PIECE_MASK
	body.mass = 1.0
	# Serve per sapere quando tocca terra.
	body.contact_monitor = true
	body.max_contacts_reported = 1
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
	_active.append([body, color, size, 0.0, -1.0])


func _physics_process(delta: float) -> void:
	for n in mini(SPAWN_PER_TICK, _pending.size()):
		var piece: Array = _pending.pop_front()
		_create_piece(piece[0], piece[1], piece[2], piece[3])
	var settled := 0
	for i in range(_active.size() - 1, -1, -1):
		var item: Array = _active[i]
		var body: RigidBody3D = item[0]
		item[3] += delta
		if item[4] < 0.0 and body.get_contact_count() > 0:
			item[4] = 0.0
		elif item[4] >= 0.0:
			item[4] += delta
		var lost := body.global_position.y < LOST_HEIGHT
		if (item[4] >= SETTLE_TIME or item[3] >= MAX_LIFETIME or lost) and settled < SETTLE_PER_TICK:
			settled += 1
			if not lost:
				_add_rubble(body.global_transform, item[2], item[1])
			body.queue_free()
			_active.remove_at(i)


func _add_rubble(where: Transform3D, size: float, color: Color) -> void:
	var multimesh := _batch_for(size).multimesh
	var i := multimesh.visible_instance_count
	multimesh.set_instance_transform(i, where)
	# I colori delle istanze vengono letti come lineari: stessa tinta dei pezzi fisici.
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
