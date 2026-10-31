@tool
class_name DestructibleBlocks
extends StaticBody3D
## Struttura distruttibile fatta di blocchi: muri, colonne, coperture.
##
## Si piazza nell'editor e si dimensiona con size: i blocchi si generano da
## soli (e si vedono già nell'editor). Le granate, i pugni, il Bestione in
## carica e gli zombie scaraventati contro la struttura rompono i blocchi; i
## blocchi rimasti senza appoggio crollano. I pezzi diventano detriti fisici
## che poi svaniscono. I colpi delle armi da fuoco non la scalfiscono.
## Il punto di origine è al centro della base.
## Predisposto per la rete: in multiplayer i danni li deciderà l'host e ai
## client basterà ricevere quali blocchi sono saltati.

## Mondo: la struttura protegge come un muro normale finché sta in piedi.
const LAYER_WORLD := 1
## Detriti: urtano solo il mondo e tra loro, non giocatori e zombie.
const LAYER_DEBRIS := 8
## Detriti presenti al massimo in tutto il livello, per non appesantire la fisica.
const MAX_DEBRIS := 80

static var _debris_alive := 0

## Dimensioni della struttura, in metri.
@export var size := Vector3(4.0, 3.0, 0.5):
	set(value):
		size = value
		_rebuild()
## Lato di ogni blocco, in metri.
@export_range(0.25, 2.0, 0.05) var block_size := 0.5:
	set(value):
		block_size = value
		_rebuild()
@export var color := Color(0.78, 0.45, 0.32):
	set(value):
		color = value
		_rebuild()
## Variazione casuale di luminosità tra un blocco e l'altro.
@export_range(0.0, 0.3) var color_variation := 0.08:
	set(value):
		color_variation = value
		_rebuild()
## Fessura visibile tra i blocchi, in metri.
@export var gap := 0.03:
	set(value):
		gap = value
		_rebuild()

@export_group("Resistenza")
## Punti vita di ogni blocco.
@export var block_health := 40.0
## Se vero, i blocchi della fila più bassa poggiano a terra e reggono il resto.
@export var anchored_bottom := true
## Se vero, regge anche la fila più alta (per strutture attaccate a un soffitto).
@export var anchored_top := false

@export_group("Detriti")
## Secondi prima che un detrito sparisca.
@export var debris_lifetime := 3.0

var _counts := Vector3i.ONE
var _alive := PackedByteArray()
var _health := PackedFloat32Array()
var _shapes: Array[CollisionShape3D] = []
var _multimesh := MultiMesh.new()
var _material := StandardMaterial3D.new()
var _visual := MultiMeshInstance3D.new()


func _ready() -> void:
	collision_layer = LAYER_WORLD
	if not Engine.is_editor_hint():
		add_to_group("destructibles")
	_rebuild()


## Quanti blocchi sono ancora in piedi.
func blocks_left() -> int:
	return _alive.count(1)


func block_count() -> int:
	return _alive.size()


## Danno ad area (esplosioni, schianti): ogni blocco entro radius perde vita,
## tutta vicino al centro e sempre meno verso il bordo. I pezzi volano via dal
## centro a push_speed m/s. Restituisce quanti blocchi sono saltati.
func damage_sphere(center: Vector3, radius: float, amount: float, push_speed := 6.0) -> int:
	var local_center := to_local(center)
	var broken: Array[int] = []
	for i in _alive.size():
		if _alive[i] == 0:
			continue
		var distance := maxf(_block_center(i).distance_to(local_center) - block_size * 0.5, 0.0)
		if distance > radius:
			continue
		_health[i] -= amount * (1.0 - distance / radius)
		if _health[i] <= 0.0:
			broken.append(i)
	_break(broken, center, push_speed)
	return broken.size()


## Danno a un solo blocco: quello più vicino a point (pugni). I pezzi partono
## con velocità push. Restituisce quanti blocchi sono saltati.
func damage_point(point: Vector3, amount: float, push := Vector3.ZERO) -> int:
	var local_point := to_local(point)
	var nearest := -1
	var nearest_distance := INF
	for i in _alive.size():
		if _alive[i] == 0:
			continue
		var distance := _block_center(i).distance_squared_to(local_point)
		if distance < nearest_distance:
			nearest = i
			nearest_distance = distance
	if nearest < 0:
		return 0
	_health[nearest] -= amount
	if _health[nearest] > 0.0:
		return 0
	var single: Array[int] = [nearest]
	_break(single, point - push.normalized(), push.length() if push != Vector3.ZERO else 3.0)
	return 1


## Aggiunge i blocchi in piedi alla geometria della mappa di navigazione.
func add_navigation_geometry(source: NavigationMeshSourceGeometryData3D) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * block_size
	var faces := box.get_faces()
	for i in _alive.size():
		if _alive[i] == 1:
			source.add_faces(faces, global_transform * Transform3D(Basis.IDENTITY, _block_center(i)))


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_counts = Vector3i(
			maxi(roundi(size.x / block_size), 1),
			maxi(roundi(size.y / block_size), 1),
			maxi(roundi(size.z / block_size), 1))
	var total := _counts.x * _counts.y * _counts.z
	_alive.resize(total)
	_alive.fill(1)
	_health.resize(total)
	_health.fill(block_health)

	var box := BoxMesh.new()
	box.size = Vector3.ONE * maxf(block_size - gap, 0.01)
	_material.albedo_color = Color.WHITE
	_material.vertex_color_use_as_albedo = true
	box.material = _material
	_multimesh.mesh = box
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.instance_count = total
	# Stesso seme per ogni struttura: i colori non cambiano a ogni avvio.
	var random := RandomNumberGenerator.new()
	random.seed = hash(name)
	for i in total:
		_multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, _block_center(i)))
		var tint := 1.0 + random.randf_range(-color_variation, color_variation)
		_multimesh.set_instance_color(i, Color(color.r * tint, color.g * tint, color.b * tint))
	_visual.multimesh = _multimesh
	if _visual.get_parent() == null:
		add_child(_visual)

	for shape in _shapes:
		shape.queue_free()
	_shapes.clear()
	# Nell'editor bastano i blocchi da vedere; le collisioni servono solo in gioco.
	if Engine.is_editor_hint():
		return
	var block_shape := BoxShape3D.new()
	block_shape.size = Vector3.ONE * block_size
	for i in total:
		var shape := CollisionShape3D.new()
		shape.shape = block_shape
		shape.position = _block_center(i)
		add_child(shape)
		_shapes.append(shape)


## Toglie i blocchi indicati, fa crollare quelli rimasti senza appoggio e
## trasforma tutto in detriti.
func _break(indices: Array[int], origin: Vector3, push_speed: float) -> void:
	if indices.is_empty():
		return
	for i in indices:
		_remove_block(i)
		var center := to_global(_block_center(i))
		var away := (center - origin).normalized() if center.distance_to(origin) > 0.01 else Vector3.UP
		_spawn_debris(center, away * push_speed + Vector3.UP * randf_range(1.0, 3.0))
	for i in _unsupported_blocks():
		_remove_block(i)
		_spawn_debris(to_global(_block_center(i)), Vector3.ZERO)
	CombatEvents.bus.terrain_changed.emit(self)


func _remove_block(i: int) -> void:
	_alive[i] = 0
	_multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), _block_center(i)))
	if i < _shapes.size():
		_shapes[i].set_deferred("disabled", true)


## Blocchi in piedi non più collegati a un blocco d'appoggio (riempimento a
## partire dalle file ancorate, passando solo tra blocchi vicini).
func _unsupported_blocks() -> Array[int]:
	var reached := PackedByteArray()
	reached.resize(_alive.size())
	var queue: Array[int] = []
	for i in _alive.size():
		var y := _cell(i).y
		var anchored := (anchored_bottom and y == 0) or (anchored_top and y == _counts.y - 1)
		if _alive[i] == 1 and anchored:
			reached[i] = 1
			queue.append(i)
	while not queue.is_empty():
		var cell := _cell(queue.pop_back())
		for offset in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var next: Vector3i = cell + offset
			if next.x < 0 or next.y < 0 or next.z < 0 \
					or next.x >= _counts.x or next.y >= _counts.y or next.z >= _counts.z:
				continue
			var j := _index(next)
			if _alive[j] == 1 and reached[j] == 0:
				reached[j] = 1
				queue.append(j)
	var loose: Array[int] = []
	for i in _alive.size():
		if _alive[i] == 1 and reached[i] == 0:
			loose.append(i)
	return loose


func _spawn_debris(at: Vector3, velocity: Vector3) -> void:
	if _debris_alive >= MAX_DEBRIS or not is_inside_tree():
		return
	_debris_alive += 1
	var debris := RigidBody3D.new()
	debris.collision_layer = LAYER_DEBRIS
	debris.collision_mask = LAYER_WORLD | LAYER_DEBRIS
	debris.mass = 2.0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3.ONE * block_size * 0.85
	debris.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = shape.shape.size
	var debris_material := StandardMaterial3D.new()
	debris_material.albedo_color = color
	box.material = debris_material
	mesh.mesh = box
	debris.add_child(mesh)
	get_tree().current_scene.add_child(debris)
	debris.global_transform = Transform3D(global_basis, at)
	debris.linear_velocity = velocity
	debris.angular_velocity = Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
	debris.tree_exited.connect(DestructibleBlocks._release_debris)
	var tween := debris.create_tween()
	tween.tween_interval(debris_lifetime * randf_range(0.8, 1.2))
	tween.tween_property(mesh, "scale", Vector3.ONE * 0.01, 0.4)
	tween.tween_callback(debris.queue_free)


static func _release_debris() -> void:
	_debris_alive -= 1


func _block_center(i: int) -> Vector3:
	var cell := _cell(i)
	return Vector3(
			(cell.x - (_counts.x - 1) * 0.5) * block_size,
			(cell.y + 0.5) * block_size,
			(cell.z - (_counts.z - 1) * 0.5) * block_size)


@warning_ignore("integer_division")
func _cell(i: int) -> Vector3i:
	return Vector3i(i % _counts.x, (i / _counts.x) % _counts.y, i / (_counts.x * _counts.y))


func _index(cell: Vector3i) -> int:
	return cell.x + cell.y * _counts.x + cell.z * _counts.x * _counts.y
