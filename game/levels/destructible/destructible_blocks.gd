@tool
class_name DestructibleBlocks
extends Node3D
## Struttura distruttibile fatta di blocchi: muri, colonne, coperture.
##
## Si piazza nell'editor e si dimensiona con size: i blocchi si generano da
## soli (e si vedono già nell'editor). Le granate, i pugni, il Bestione in
## carica e gli zombie scaraventati contro la struttura rompono i blocchi; i
## blocchi rimasti senza appoggio crollano. I pezzi volano come detriti fisici
## e, quando si fermano, restano a terra per sempre come macerie (RubbleField).
## I colpi delle armi da fuoco non la scalfiscono.
## Il punto di origine è al centro della base. Le collisioni sono divise in
## pezzi da CHUNK blocchi per lato (corpi figli): quando salta un blocco si
## ricostruisce solo il suo pezzo e non tutta la struttura.
## In rete danni e crolli li calcola solo l'host, che manda a tutti quali
## blocchi sono saltati; i detriti invece li crea ognuno per conto suo (stessa
## origine e spinta, forme a caso). Chi entra a partita iniziata riceve subito
## quali blocchi mancano.

## Mondo: la struttura protegge come un muro normale finché sta in piedi.
const LAYER_WORLD := 1
## Detriti: urtano solo il mondo, non giocatori, zombie e altri detriti.
const LAYER_DEBRIS := 8
## Blocchi per lato di ogni pezzo di collisione.
const CHUNK := 4

## Dimensioni della struttura, in metri.
@export var size := Vector3(4.0, 3.0, 0.5):
	set(value):
		size = value
		_rebuild()
## Lato di ogni blocco, in metri.
@export_range(0.1, 2.0, 0.05) var block_size := 0.25:
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
## Fessura visibile tra i blocchi, in metri (0 = muro compatto; i blocchi si
## distinguono solo dalle sfumature di colore).
@export var gap := 0.0:
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
## Pezzi lanciati al massimo da un singolo crollo: oltre questo numero gli altri
## si polverizzano in una nuvola di polvere, per non appesantire la fisica.
@export var max_debris_per_break := 100

var _counts := Vector3i.ONE
var _alive := PackedByteArray()
var _health := PackedFloat32Array()
var _shapes: Array[CollisionShape3D] = []
var _chunks: Array[StaticBody3D] = []
var _multimesh := MultiMesh.new()
var _material := StandardMaterial3D.new()
var _visual := MultiMeshInstance3D.new()


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("destructibles")
		if multiplayer.is_server():
			multiplayer.peer_connected.connect(_send_state)
	_rebuild()


## La struttura a cui appartiene il corpo colpito, o null se non è distruttibile.
static func from_collider(collider: Object) -> DestructibleBlocks:
	if collider is Node and collider.get_parent() is DestructibleBlocks:
		return collider.get_parent()
	return null


## Quanti blocchi sono ancora in piedi.
func blocks_left() -> int:
	return _alive.count(1)


func block_count() -> int:
	return _alive.size()


## Danno ad area (esplosioni, schianti): ogni blocco entro radius perde vita,
## tutta vicino al centro e sempre meno verso il bordo. I pezzi volano via dal
## centro a push_speed m/s. Restituisce quanti blocchi sono saltati.
func damage_sphere(center: Vector3, radius: float, amount: float, push_speed := 6.0) -> int:
	if not multiplayer.is_server():
		return 0
	var local_center := to_local(center)
	var broken: Array[int] = []
	# Si controllano solo le celle nel cubo attorno al raggio, non tutta la struttura.
	var low := _cell_at(local_center - Vector3.ONE * (radius + block_size))
	var high := _cell_at(local_center + Vector3.ONE * (radius + block_size))
	for z in range(low.z, high.z + 1):
		for y in range(low.y, high.y + 1):
			for x in range(low.x, high.x + 1):
				var i := _index(Vector3i(x, y, z))
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
	if not multiplayer.is_server():
		return 0
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
		# I colori delle istanze vengono letti come lineari: si convertono, così il
		# muro ha lo stesso colore scelto nell'Inspector (e dei suoi detriti).
		_multimesh.set_instance_color(i, Color(color.r * tint, color.g * tint, color.b * tint).srgb_to_linear())
	_visual.multimesh = _multimesh
	if _visual.get_parent() == null:
		add_child(_visual)

	for chunk in _chunks:
		chunk.queue_free()
	_chunks.clear()
	_shapes.clear()
	# Nell'editor bastano i blocchi da vedere; le collisioni servono solo in gioco.
	if Engine.is_editor_hint():
		return
	var chunk_counts := Vector3i(ceili(_counts.x / float(CHUNK)), ceili(_counts.y / float(CHUNK)),
			ceili(_counts.z / float(CHUNK)))
	for c in chunk_counts.x * chunk_counts.y * chunk_counts.z:
		var chunk := StaticBody3D.new()
		chunk.collision_layer = LAYER_WORLD
		add_child(chunk)
		_chunks.append(chunk)
	var block_shape := BoxShape3D.new()
	block_shape.size = Vector3.ONE * block_size
	for i in total:
		var cell := _cell(i) / CHUNK
		var shape := CollisionShape3D.new()
		shape.shape = block_shape
		shape.position = _block_center(i)
		_chunks[cell.x + cell.y * chunk_counts.x + cell.z * chunk_counts.x * chunk_counts.y].add_child(shape)
		_shapes.append(shape)


## Sull'host: toglie i blocchi indicati e quelli rimasti senza appoggio, qui
## e sugli altri partecipanti.
func _break(indices: Array[int], origin: Vector3, push_speed: float) -> void:
	if indices.is_empty():
		return
	var broken := PackedInt32Array(indices)
	for i in broken:
		_alive[i] = 0
	var loose := PackedInt32Array(_unsupported_blocks())
	_collapse(broken, loose, origin, push_speed)
	if NetSession.is_online():
		_receive_break.rpc(broken, loose, origin, push_speed)


@rpc("authority", "call_remote", "reliable")
func _receive_break(broken: PackedInt32Array, loose: PackedInt32Array, origin: Vector3,
		push_speed: float) -> void:
	_collapse(broken, loose, origin, push_speed)


## Toglie i blocchi saltati (che volano via da origin) e quelli crollati (che
## cadono e basta) e li trasforma in detriti (oltre il limite, in polvere).
func _collapse(broken: PackedInt32Array, loose: PackedInt32Array, origin: Vector3,
		push_speed: float) -> void:
	var budget := max_debris_per_break
	var dust_at := Vector3.ZERO
	var dust_count := 0
	for i in broken:
		_remove_block(i)
		var center := to_global(_block_center(i))
		var away := (center - origin).normalized() if center.distance_to(origin) > 0.01 else Vector3.UP
		if budget > 0 and _spawn_debris(center, away * push_speed + Vector3.UP * randf_range(1.0, 3.0)):
			budget -= 1
		else:
			dust_at += center
			dust_count += 1
	for i in loose:
		_remove_block(i)
		var center := to_global(_block_center(i))
		if budget > 0 and _spawn_debris(center, Vector3.ZERO):
			budget -= 1
		else:
			dust_at += center
			dust_count += 1
	if dust_count > 0:
		_spawn_dust(dust_at / dust_count, dust_count)
	CombatEvents.bus.terrain_changed.emit(self)


## Sull'host: manda a chi è appena entrato quali blocchi mancano già.
func _send_state(peer_id: int) -> void:
	if _alive.has(0):
		_receive_state.rpc_id(peer_id, _alive)


@rpc("authority", "call_remote", "reliable")
func _receive_state(alive: PackedByteArray) -> void:
	if alive.size() != _alive.size():
		return
	for i in alive.size():
		if alive[i] == 0 and _alive[i] == 1:
			_remove_block(i)
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


func _spawn_debris(at: Vector3, velocity: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var piece_color := color * (1.0 + randf_range(-color_variation, color_variation))
	piece_color.a = 1.0
	return RubbleField.of(self).spawn(Transform3D(global_basis, at), block_size * 0.95, piece_color, velocity)


## Nuvola di polvere per i blocchi che non diventano detriti.
func _spawn_dust(at: Vector3, amount: int) -> void:
	var dust := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * block_size * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = color.lightened(0.3)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	dust.mesh = mesh
	dust.amount = clampi(amount, 8, 48)
	dust.lifetime = 0.9
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 4.0
	dust.gravity = Vector3(0.0, -3.0, 0.0)
	dust.scale_amount_min = 0.4
	get_tree().current_scene.add_child(dust)
	dust.global_position = at
	dust.emitting = true
	dust.finished.connect(dust.queue_free)


func _block_center(i: int) -> Vector3:
	var cell := _cell(i)
	return Vector3(
			(cell.x - (_counts.x - 1) * 0.5) * block_size,
			(cell.y + 0.5) * block_size,
			(cell.z - (_counts.z - 1) * 0.5) * block_size)


@warning_ignore("integer_division")
func _cell(i: int) -> Vector3i:
	return Vector3i(i % _counts.x, (i / _counts.x) % _counts.y, i / (_counts.x * _counts.y))


## La cella che contiene il punto locale, limitata ai bordi della struttura.
func _cell_at(local_point: Vector3) -> Vector3i:
	return Vector3i(
			clampi(floori(local_point.x / block_size + _counts.x * 0.5), 0, _counts.x - 1),
			clampi(floori(local_point.y / block_size), 0, _counts.y - 1),
			clampi(floori(local_point.z / block_size + _counts.z * 0.5), 0, _counts.z - 1))


func _index(cell: Vector3i) -> int:
	return cell.x + cell.y * _counts.x + cell.z * _counts.x * _counts.y
