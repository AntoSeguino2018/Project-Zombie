extends SceneTree
# Passo 3.2 in rete: le ondate le decide l'host, il client vede numero,
# zombie rimasti, scritte e pause; entrando a ondata iniziata riceve lo stato.
# Uso: --script net_waves.gd -- host   oppure   -- client

const PORT := 17786

var failures := 0
var role := ""
var level: Node
var waves: WaveDirector


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
	return level.get_node("Enemies").get_children().filter(func(n): return n is Enemy \
			and HealthComponent.of(n).is_alive())


func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	NetSession.port = PORT
	NetSession.address = "127.0.0.1"
	NetSession.mode = NetSession.Mode.HOST if role == "host" else NetSession.Mode.JOIN
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	waves = WaveDirector.of(level)
	if role == "host":
		# Prima ondata subito: il client entra a ondata iniziata.
		waves._time_left = 0.5
	var players: Node = level.get_node("Players")
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
	for player in players.get_children():
		HealthComponent.of(player).damage_filter = func(_a, _s, _h): return 0.0
	var budget := waves.budget_for(2, 2)
	check("il secondo giocatore alza il budget", budget > waves.budget_for(2, 1), str(budget))
	var out := await wait_until(func(): return waves._queue.is_empty() and zombies().size() == 6, 10.0)
	check("ondata 1: 6 zombie in campo", out, "in campo=%d" % zombies().size())
	await wait_seconds(2.0)
	HealthComponent.of(zombies()[0]).take_damage(999.0, players.get_node("1"))
	await wait_seconds(1.5)
	for z in zombies():
		HealthComponent.of(z).take_damage(999.0, players.get_node("1"))
	var cleared := await wait_until(func(): return waves.phase == WaveDirector.Phase.BREAK, 3.0)
	check("ondata 1 finita sull'host", cleared)
	await wait_seconds(2.0)
	waves._time_left = 0.5
	var second := await wait_until(func(): return waves.wave == 2 and waves.phase == WaveDirector.Phase.ACTIVE, 3.0)
	check("parte l'ondata 2, con budget per due", second and waves.remaining >= 8, "rimasti=%d" % waves.remaining)
	var left := await wait_until(func(): return players.get_child_count() == 1, 20.0)
	check("il client esce", left)


func run_client(players: Node) -> void:
	var me: FpsController = players.get_node(str(get_multiplayer().get_unique_id()))
	var hud: PlayerHud = me._hud
	var started: Array = []
	var cleared: Array = []
	waves.wave_started.connect(func(w): started.append(w))
	waves.wave_cleared.connect(func(w): cleared.append(w))
	var got := await wait_until(func(): return waves.wave == 1 and waves.phase == WaveDirector.Phase.ACTIVE, 3.0)
	check("entrando a ondata iniziata si riceve lo stato", got, "ondata=%d fase=%d" % [waves.wave, waves.phase])
	check("da client il director non manda zombie da solo", waves._queue.is_empty())
	var all := await wait_until(func(): return zombies().size() == 6 and waves.remaining == 6, 10.0)
	check("si vedono i 6 zombie e il conto", all, "in campo=%d rimasti=%d" % [zombies().size(), waves.remaining])
	await wait_seconds(0.1)
	check("HUD: ondata 1 e 6 zombie", hud._wave_label.text == "Ondata 1   ·   6 zombie", hud._wave_label.text)
	var one := await wait_until(func(): return waves.remaining == 5, 5.0)
	check("ne muore uno: il conto scende anche qui", one)
	var done := await wait_until(func(): return cleared == [1], 5.0)
	check("si vede la fine dell'ondata 1", done and waves.phase == WaveDirector.Phase.BREAK)
	await wait_seconds(0.1)
	check("HUD: scritta e pausa", hud._wave_banner.text == "Ondata 1 superata!" \
			and hud._wave_label.text.begins_with("Ondata 2 tra "), hud._wave_label.text)
	# Il conto alla rovescia scende anche qui.
	var before := waves.seconds_to_next_wave()
	await wait_seconds(1.0)
	check("il conto alla rovescia scende", waves.seconds_to_next_wave() < before - 0.8,
			"%.1f -> %.1f" % [before, waves.seconds_to_next_wave()])
	var second := await wait_until(func(): return started == [2], 5.0)
	check("si vede partire l'ondata 2", second and hud._wave_banner.text == "ONDATA 2")
	await wait_seconds(0.3)
	check("con lo stesso numero di zombie dell'host", waves.remaining >= 8, "rimasti=%d" % waves.remaining)
	NetSession.leave(self)
	await wait_seconds(0.5)
