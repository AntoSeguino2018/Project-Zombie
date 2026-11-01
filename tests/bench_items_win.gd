extends SceneTree
# In finestra, senza vsync: FPS con N tipi di oggetti raccolti e 10 zombie.
func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var level: Node = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	level.get_node("Waves").free()
	var p: FpsController = level.get_node("Players/1")
	HealthComponent.of(p).damage_filter = func(a, s, h): return 0.0
	for i in 10:
		var e: Enemy = load("res://game/enemies/walker.tscn").instantiate()
		level.get_node("Enemies").add_child(e)
		e.global_position = Vector3(-20 + i * 3, 0, -25)
	for count in [0, 3, 6, 10]:
		for path in ItemCatalog.ITEMS.slice(0, count):
			if p.inventory().items.get(path, 0) == 0:
				p.inventory().host_add_item(load(path))
		for i in 60:
			await process_frame
		var f0 := Engine.get_process_frames()
		var t0 := Time.get_ticks_usec()
		while Time.get_ticks_usec() - t0 < 3000000:
			await process_frame
		var fps := (Engine.get_process_frames() - f0) / ((Time.get_ticks_usec() - t0) / 1000000.0)
		print("%2d tipi di oggetti: %.0f FPS" % [count, fps])
	quit()
