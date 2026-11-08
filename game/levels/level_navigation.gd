class_name LevelNavigation
extends NavigationRegion3D
## Calcola la mappa di navigazione dei nemici all'avvio del livello (pochi
## millisecondi), così si può modificare il livello nell'editor senza doversi
## ricordare di rifare il bake a mano. Quando un muro distruttibile crolla, la
## ricalcola in background: gli zombie passano dai buchi nuovi.
##
## La geometria si legge dai nodi del gruppo indicato dalla NavigationMesh:
## forme CSG con collisione, strutture distruttibili (solo i blocchi in piedi)
## e porte a pagamento chiuse (aprendole la mappa si ricalcola).
## Si usano le collisioni e non le mesh visive, che a runtime andrebbero rilette
## dalla scheda video. Quando arriveranno i livelli modellati in Blender si
## aggiungeranno qui le loro collisioni.

## Secondi di attesa dopo un crollo prima di ricalcolare: più crolli ravvicinati
## (es. una raffica di granate) si raccolgono in un solo ricalcolo.
@export var rebake_delay := 0.25

var _baking := false
var _dirty := false
var _rebake_timer := Timer.new()


func _ready() -> void:
	_rebake_timer.one_shot = true
	_rebake_timer.timeout.connect(_rebake)
	add_child(_rebake_timer)
	CombatEvents.bus.terrain_changed.connect(_on_terrain_changed)
	# Le CSG costruiscono la loro geometria alla fine del primo frame: si aspetta
	# che esista.
	await get_tree().process_frame
	# Nel frattempo il livello può essere già stato chiuso (es. partita che non
	# riesce a partire e torna al menu).
	if not is_inside_tree():
		return
	# Si cuoce una copia e la si assegna: è l'assegnazione ad aggiornare la mappa.
	var baked: NavigationMesh = navigation_mesh.duplicate()
	NavigationServer3D.bake_from_source_geometry_data(baked, _collect_geometry())
	navigation_mesh = baked


func is_rebaking() -> bool:
	return _baking or not _rebake_timer.is_stopped()


func _on_terrain_changed(_source: Node) -> void:
	# Gli zombie li muove solo l'host: agli altri la mappa aggiornata non serve.
	if not multiplayer.is_server():
		return
	if _rebake_timer.is_stopped():
		_rebake_timer.start(rebake_delay)


func _rebake() -> void:
	if _baking:
		_dirty = true
		return
	_baking = true
	var baked: NavigationMesh = navigation_mesh.duplicate()
	# La raccolta della geometria resta qui; il calcolo vero gira su un altro thread.
	NavigationServer3D.bake_from_source_geometry_data_async(baked, _collect_geometry(),
			_on_rebaked.bind(baked))


func _on_rebaked(baked: NavigationMesh) -> void:
	# Può arrivare da un altro thread: l'assegnazione si fa sul thread principale.
	_apply_rebake.call_deferred(baked)


func _apply_rebake(baked: NavigationMesh) -> void:
	navigation_mesh = baked
	_baking = false
	if _dirty:
		_dirty = false
		_rebake()


func _collect_geometry() -> NavigationMeshSourceGeometryData3D:
	var source := NavigationMeshSourceGeometryData3D.new()
	for node in get_tree().get_nodes_in_group(navigation_mesh.geometry_source_group_name):
		_add_geometry(node, source)
	return source


func _add_geometry(node: Node, source: NavigationMeshSourceGeometryData3D) -> void:
	# Strutture distruttibili (solo i blocchi in piedi) e porte a pagamento (solo chiuse).
	if node.has_method("add_navigation_geometry"):
		node.add_navigation_geometry(source)
		return
	if node is CSGShape3D and node.is_root_shape():
		if node.use_collision:
			source.add_faces(node.bake_collision_shape().get_faces(), node.global_transform)
		return
	for child in node.get_children():
		_add_geometry(child, source)
