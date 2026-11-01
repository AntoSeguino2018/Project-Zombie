extends SceneTree
# Passo 3.6 in rete: host e client nel Complesso; partenza nell'atrio, prima
# ondata vista da entrambi, il client apre la cassa sul soppalco.
# Uso: --script net_complex.gd -- host   oppure   -- client

const PORT := 17790

var failures := 0
var role := ""
var level: Node


func check(name: String, ok: bool, info: String = "") -> void:
	print("[%s] %s %s  %s" % [role, "PASS" if ok else "FAIL", name, info])
	if not ok:
		failures += 1


func wait_until(cond: Callable, max_seconds: float) -> bool:
	for i in int(max_seconds * 60.0):
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func wait_seconds(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await physics_frame


func zombies() -> Array:
	return level.get_node("Enemies").get_children().filter(func(n): return n is Enemy)


func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	NetSession.port = PORT
	NetSession.address = "127.0.0.1"
	NetSession.mode = NetSession.Mode.HOST if role == "host" else NetSession.Mode.JOIN
	level = load("res://game/levels/complex.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var players: Node = level.get_node("Players")
	var ready := await wait_until(func(): return players.get_child_count() == 2 \
			and players.has_node(str(get_multiplayer().get_unique_id())), 15.0)
	check("due giocatori nel Complesso", ready)
	if ready:
		var me: FpsController = players.get_node(str(get_multiplayer().get_unique_id()))
		await wait_seconds(0.5)
		check("si parte nell'atrio", me.global_position.distance_to(Vector3(0, 0, 15)) < 4.0, str(me.global_position))
		for player in players.get_children():
			if role == "host":
				HealthComponent.of(player).damage_filter = func(_a, _s, _h): return 0.0
		var waves := WaveDirector.of(level)
		if role == "host":
			waves._time_left = 0.5
		var seen := await wait_until(func(): return waves.wave == 1 and zombies().size() >= 6, 15.0)
		check("prima ondata: zombie visti qui", seen, "ondata %d, zombie %d" % [waves.wave, zombies().size()])
		var crate: WeaponCrate = level.get_node("Crates/CassaSoppalco")
		if role == "host":
			var other: FpsController = players.get_children().filter(func(n): return n.name != "1")[0]
			other.inventory().host_add_money(100)
			var opened := await wait_until(func(): return crate.is_open, 15.0)
			check("il client apre la cassa sul soppalco (sull'host)", opened)
			await wait_until(func(): return players.get_child_count() == 1, 20.0)
		else:
			await wait_until(func(): return me.inventory().money == 100, 5.0)
			me.global_position = crate.global_position + Vector3(0, 0.1, 1.6)
			me.velocity = Vector3.ZERO
			me.reset_physics_interpolation()
			await wait_seconds(0.5)
			check("sul soppalco (3 m)", me.global_position.y > 2.5, str(me.global_position))
			me.interact_with(crate)
			var opened := await wait_until(func(): return crate.is_open, 3.0)
			check("la cassa si apre anche qui", opened)
			NetSession.leave(self)
			await wait_seconds(0.5)
	print("[%s] RISULTATO: %d errori" % [role, failures])
	quit(1 if failures > 0 else 0)
