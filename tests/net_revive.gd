extends SceneTree
# Passo 3.3 in rete: chi entra vede chi è già a terra; il client rianima
# l'host tenendo premuto E; tutti a terra = run persa per tutti, poi si riparte.
# Uso: --script net_revive.gd -- host   oppure   -- client

const PORT := 17787

var failures := 0
var role := ""
var level: Node
var run: RunManager


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


## Clip del modello in terza persona del giocatore.
func body_clip(player: FpsController) -> StringName:
	return (player.get_node("Body") as PlayerModel).current_clip()


func move_to(player: FpsController, where: Vector3, yaw := 0.0) -> void:
	player.global_position = where
	player.velocity = Vector3.ZERO
	player._yaw = yaw
	player.rotation.y = yaw
	player.reset_physics_interpolation()


func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	NetSession.port = PORT
	NetSession.address = "127.0.0.1"
	NetSession.mode = NetSession.Mode.HOST if role == "host" else NetSession.Mode.JOIN
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	run = RunManager.of(level)
	var players: Node = level.get_node("Players")
	if role == "host":
		WaveDirector.of(level).host_pause()
		# L'host va a terra prima che entri il client (senza perdere la run da solo).
		run.set_physics_process(false)
		var me: FpsController = players.get_node("1")
		await wait_until(func(): return me.is_inside_tree(), 2.0)
		move_to(me, Vector3(0, 0.1, -4))
		await wait_seconds(0.3)
		HealthComponent.of(me).take_damage(1000.0)
	var ready := await wait_until(func(): return players.get_child_count() == 2 \
			and players.has_node(str(get_multiplayer().get_unique_id())), 15.0)
	check("due giocatori in partita", ready)
	if ready:
		if role == "host":
			await run_host(players)
		else:
			await run_client(players)
	print("[%s] RISULTATO: %d errori" % [role, failures])
	quit(1 if failures > 0 else 0)


func run_host(players: Node) -> void:
	var me: FpsController = players.get_node("1")
	var other: FpsController = players.get_children().filter(func(n): return n.name != "1")[0]
	run.set_physics_process(true)
	check("l'host è a terra", me.life == FpsController.Life.DOWNED)
	# L'host sa chi lo rianima: il modello del client fa la clip Rianima.
	var reviving := await wait_until(func(): return body_clip(other) == &"Rianima", 15.0)
	check("l'host vede il client che lo rianima", reviving, "clip=%s" % body_clip(other))
	var up := await wait_until(func(): return me.is_standing(), 15.0)
	check("il client rianima l'host", up and is_equal_approx(HealthComponent.of(me).current, 40.0),
			"vita=%.0f" % HealthComponent.of(me).current)
	check("non si è dissanguato", me.bleed_left > 20.0, "%.1f" % me.bleed_left)
	# Ora tutti a terra.
	await wait_seconds(1.0)
	me.weapon().host_set_loadout([["pistol"], ["smg"]], 1)
	HealthComponent.of(other).take_damage(1000.0)
	await wait_seconds(0.3)
	check("uno a terra: la run continua", not run.lost)
	HealthComponent.of(me).take_damage(1000.0)
	await wait_seconds(0.2)
	check("tutti a terra: run persa", run.lost)
	await wait_seconds(1.5)
	run._restart_left = 0.2
	var again := await wait_until(func(): return not run.lost, 2.0)
	check("si riparte", again and me.is_standing() and other.is_standing())
	var left := await wait_until(func(): return players.get_child_count() == 1, 20.0)
	check("il client esce", left)


func run_client(players: Node) -> void:
	var me: FpsController = players.get_node(str(get_multiplayer().get_unique_id()))
	var host: FpsController = players.get_node("1")
	var seen := await wait_until(func(): return host.life == FpsController.Life.DOWNED, 3.0)
	check("entrando si vede l'host già a terra", seen)
	await wait_seconds(0.2)
	check("disteso (clip ATerra)", body_clip(host) == &"ATerra", "clip=%s" % body_clip(host))
	check("con la scritta sopra la testa", host._name_tag.text.ends_with("A TERRA"), host._name_tag.text)
	await wait_seconds(0.5)
	move_to(me, host.global_position + Vector3(1.5, 0, 0), PI / 2.0)
	await wait_seconds(0.3)
	check("scritta: tieni premuto per rianimare", me._hud._prompt.text.contains("rianima Giocatore 1"), me._hud._prompt.text)
	Input.action_press("interact")
	await wait_seconds(1.5)
	check("barra della rianimazione a metà", me._hud._revive_bar.visible and me._hud._revive_bar.value > 0.25 \
			and me._hud._revive_bar.value < 0.75, "%.2f" % me._hud._revive_bar.value)
	check("in ginocchio a rianimare (clip Rianima)", body_clip(me) == &"Rianima", "clip=%s" % body_clip(me))
	var up := await wait_until(func(): return host.is_standing(), 3.0)
	Input.action_release("interact")
	check("l'host si rialza", up)
	await wait_seconds(0.3)
	check("il nome torna normale", host._name_tag.text == "Giocatore 1")
	# Tutti a terra.
	var lost := await wait_until(func(): return run.lost, 10.0)
	check("si vede la run persa", lost and run.lost_wave == 0)
	await wait_seconds(0.2)
	check("HUD: RUN PERSA", me._hud._death_label.visible and me._hud._death_label.text.begins_with("RUN PERSA"),
			me._hud._death_label.text.replace("\n", " | "))
	var again := await wait_until(func(): return not run.lost, 5.0)
	await wait_seconds(0.5)
	check("si riparte", again and me.is_standing() and HealthComponent.of(me).current == 100.0)
	check("HUD normale", not me._hud._death_label.visible and me._weapon.visible)
	check("al punto di partenza", me.global_position.distance_to(me._spawn_transform.origin) < 0.5, "pos=%s" % me.global_position)
	check("l'host ha di nuovo solo la pistola", host.weapon().specs() == [["pistol"]], str(host.weapon().specs()))
	NetSession.leave(self)
	await wait_seconds(0.5)
