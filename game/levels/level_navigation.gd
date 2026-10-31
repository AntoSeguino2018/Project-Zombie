class_name LevelNavigation
extends NavigationRegion3D
## Calcola la mappa di navigazione dei nemici all'avvio del livello (pochi
## millisecondi), così si può modificare il livello nell'editor senza doversi
## ricordare di rifare il bake a mano.
##
## La geometria si legge dalle forme CSG con collisione dentro i nodi del gruppo
## indicato dalla NavigationMesh. Si usano le loro collisioni e non le mesh
## visive, che a runtime andrebbero rilette dalla scheda video.
## Quando arriveranno i livelli modellati in Blender si aggiungeranno qui le
## loro collisioni.


func _ready() -> void:
	# Le CSG costruiscono la loro geometria alla fine del primo frame: si aspetta
	# che esista.
	await get_tree().process_frame
	var source := NavigationMeshSourceGeometryData3D.new()
	for node in get_tree().get_nodes_in_group(navigation_mesh.geometry_source_group_name):
		_add_csg_faces(node, source)
	# Si cuoce una copia e la si assegna: è l'assegnazione ad aggiornare la mappa.
	var baked: NavigationMesh = navigation_mesh.duplicate()
	NavigationServer3D.bake_from_source_geometry_data(baked, source)
	navigation_mesh = baked


func _add_csg_faces(node: Node, source: NavigationMeshSourceGeometryData3D) -> void:
	if node is CSGShape3D and node.is_root_shape():
		if node.use_collision:
			source.add_faces(node.bake_collision_shape().get_faces(), node.global_transform)
		return
	for child in node.get_children():
		_add_csg_faces(child, source)
