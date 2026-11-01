extends SceneTree
# 35 secondi di partita nel poligono con le ondate: il giocatore tira pugni e spara a caso.
# Non controlla nulla: serve a vedere che non escano errori.
func _initialize() -> void:
	var level: Node = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var p: FpsController = level.get_node("Players/1")
	var melee: MeleeAttack = p.get_node("Camera3D/Melee")
	var weapon: Weapon = p.get_node("Camera3D/Weapon")
	weapon.host_set_loadout([["carbine"], ["grenade_launcher"]], 0)
	weapon._switch_left = 0.0
	var kinds := {}
	var deaths := [0]
	HealthComponent.of(p).died.connect(func(_s): deaths[0] += 1)
	for i in 35 * 60:
		await physics_frame
		for e in get_nodes_in_group("enemies"):
			kinds[e.get_script().get_global_name()] = true
		if i % 20 == 0 and HealthComponent.of(p).is_alive():
			var target: Enemy = null
			for e in get_nodes_in_group("enemies"):
				if HealthComponent.of(e).is_alive() and (target == null or e.global_position.distance_to(p.global_position) < target.global_position.distance_to(p.global_position)):
					target = e
			if target:
				var head: Vector3 = p.get_node("Head").global_position
				var dir := (target.center() - head).normalized()
				p._yaw = atan2(-dir.x, -dir.z)
				weapon._cooldown = 0.0
				weapon.fire(head, dir, [p.get_rid()])
				if melee.can_attack(): melee.attack(head, dir, p)
	print("tipi visti: ", kinds.keys(), "  morti del giocatore: ", deaths[0], "  zombie vivi: ", get_nodes_in_group("enemies").size())
	quit()
