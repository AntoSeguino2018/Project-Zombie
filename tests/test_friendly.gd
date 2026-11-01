extends SceneTree
# I colpi della carabina e le granate attraversano i compagni: niente danni né numeri.
var failures := 0
func check(name: String, ok: bool, info: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: failures += 1

func _initialize() -> void:
	var level: Node = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	level.get_node("Waves").free()
	for s in level.get_node("Enemies").get_children(): s.free()
	var p: FpsController = level.get_node("Players/1")
	var mate: FpsController = load("res://game/player/player.tscn").instantiate()
	mate.name = "2"
	mate.player_number = 2
	mate.position = Vector3(25, 0.1, -5)
	level.get_node("Players").add_child(mate)
	for i in 10: await physics_frame
	p.global_position = Vector3(25, 0.1, 0)
	p.reset_physics_interpolation()
	for i in 3: await physics_frame
	var weapon: Weapon = p.get_node("Camera3D/Weapon")
	weapon.host_set_loadout([["carbine"], ["grenade_launcher"]], 0)
	weapon._switch_left = 0.0
	weapon.data.spread_degrees = 0.0
	var hits := []
	weapon.hit.connect(func(c, pos, _n): hits.append([c, pos]))
	var head: Vector3 = p.get_node("Head").global_position
	weapon._cooldown = 0.0
	weapon.fire(head, (mate.global_position + Vector3.UP * 1.2 - head).normalized(), [p.get_rid()])
	var numbers := level.get_children().filter(func(n): return n is DamageNumber).size()
	check("la carabina attraversa il compagno", hits.size() == 1 and hits[0][0] != mate and hits[0][1].z < -6.0, "colpito=%s" % (str(hits[0][1]) if hits else "niente"))
	check("nessun danno e nessun numero", HealthComponent.of(mate).current == 100.0 and numbers == 0, "vita=%s numeri=%d" % [HealthComponent.of(mate).current, numbers])
	weapon.equip(1)
	for i in 25: await physics_frame
	weapon._cooldown = 0.0
	weapon.muzzle = null
	weapon.fire(mate.global_position + Vector3(0, 1.0, 1.5), Vector3.DOWN, [p.get_rid()])
	for i in 30: await physics_frame
	check("la granata non ferisce il compagno", HealthComponent.of(mate).current == 100.0, "vita=%s" % HealthComponent.of(mate).current)
	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)
