extends SceneTree
# Passo 3.9 in rete: il client compra il martello al muro (decide l'host, che
# gli toglie i soldi e gli dà l'arma: la sanno tutti e due), lo prende in mano
# col tasto 3 e colpisce uno zombie: il danno lo applica l'host (45) e il
# client riceve la conferma per numero e hitmarker.
# Uso: --script net_melee.gd -- host   oppure   -- client

const PORT := 17794
const AT_WALL := Vector3(12, 0.1, 57.8)
const SWING_FROM := Vector3(12, 0.1, 50)
const ZOMBIE_AT := Vector3(12, 0.1, 48.4)

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


func move_to(player: FpsController, where: Vector3, yaw := 0.0) -> void:
	player.global_position = where
	player.velocity = Vector3.ZERO
	player._yaw = yaw
	player._pitch = 0.0
	player.rotation.y = yaw
	player.reset_physics_interpolation()


func wall() -> WallWeapon:
	return level.get_node("WallWeapons/MartelloCentri") as WallWeapon


func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	NetSession.port = PORT
	NetSession.address = "127.0.0.1"
	NetSession.mode = NetSession.Mode.HOST if role == "host" else NetSession.Mode.JOIN
	level = load("res://game/levels/campus.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var players: Node = level.get_node("Players")
	if role == "host":
		WaveDirector.of(level).host_pause()
		RunManager.of(level).set_physics_process(false)
	var ready := await wait_until(func(): return players.get_child_count() == 2 \
			and players.has_node(str(get_multiplayer().get_unique_id())), 15.0)
	check("due giocatori nel campus", ready)
	if ready:
		for player in players.get_children():
			HealthComponent.of(player).damage_filter = func(_a, _s, _h): return 0.0
		if role == "host":
			await run_host(players)
		else:
			await run_client(players)
	print("[%s] RISULTATO: %d errori" % [role, failures])
	quit(1 if failures > 0 else 0)


func run_host(players: Node) -> void:
	var other: FpsController = players.get_children().filter(func(n): return n.name != "1")[0]
	other.inventory().host_add_money(700)
	var bought := await wait_until(func(): return other.melee().weapon != null, 15.0)
	check("il client compra il martello: per l'host ce l'ha", bought and other.melee().weapon.id == "martello")
	check("pagato 250 €", other.inventory().money == 450, "%d €" % other.inventory().money)
	await wait_seconds(1.0)
	var zombie: Enemy = EnemyReplicator.of(level).spawn_enemy(EnemyReplicator.of(level).enemy_scenes[0], ZOMBIE_AT, PI)
	zombie.set_physics_process(false)
	var health := HealthComponent.of(zombie)
	health.max_health = 1000.0
	health.current = 1000.0
	var hit := await wait_until(func(): return health.current < 1000.0, 15.0)
	check("la martellata del client fa 45 (l'host la applica)", hit and is_equal_approx(1000.0 - health.current, 45.0),
			"%.0f" % (1000.0 - health.current))
	var left := await wait_until(func(): return players.get_child_count() == 1, 20.0)
	check("il client esce", left)


func run_client(players: Node) -> void:
	var me: FpsController = players.get_node(str(get_multiplayer().get_unique_id()))
	var rich := await wait_until(func(): return me.inventory().money >= 700, 10.0)
	check("il client ha i soldi", rich)
	move_to(me, AT_WALL, PI)
	await wait_seconds(0.5)
	me.interact_with(wall())
	var got := await wait_until(func(): return me.melee().weapon != null, 5.0)
	check("il martello arriva al client", got and me.melee().weapon.id == "martello")
	me._select_melee()
	check("tasto 3: in mano", me.melee().active and not me.weapon().visible)
	move_to(me, SWING_FROM, 0.0)
	var confirmed := [false]
	me.melee().dealt_damage.connect(func(_t, amount, _k): confirmed[0] = amount > 0.0)
	var zombie_seen := await wait_until(func(): return level.get_node("Enemies").get_child_count() > 0, 15.0)
	await wait_seconds(0.8)
	me.melee()._cooldown_left = 0.0
	me.melee().swing(me._head.global_position, -me._aim_basis().z, me)
	var ok := await wait_until(func(): return confirmed[0], 3.0)
	check("colpo confermato dall'host (numero e hitmarker)", zombie_seen and ok)
	await wait_seconds(1.0)
