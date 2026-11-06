extends SceneTree
# Test del passo 2.2 con due istanze: colpi, granate, pugni, morte e rinascita in rete.
# Uso: --script net_combat.gd -- host   oppure   -- client
# I due processi si coordinano guardando lo stato del gioco (vita dei
# manichini, vita del giocatore), senza altri canali.

const PORT := 17779

var failures := 0
var role := ""
var level: Node
## Nodi comparsi nel livello, per tipo: scie, proiettili, numeri di danno.
var added := {"Tracer": 0, "Projectile": 0, "DamageNumber": 0, "ExplosionEffect": 0}


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
	player.rotation.y = yaw
	player.reset_physics_interpolation()


func health_of(path: String) -> HealthComponent:
	return HealthComponent.of(level.get_node(path))


## Tre colpi a terra davanti a sé, per le scie viste dagli altri.
func fire_at_floor(player: FpsController) -> void:
	for i in 3:
		await wait_seconds(0.2)
		player._weapon._cooldown = 0.0
		player._weapon._ammo[player._weapon.current_slot()] = 30
		player._weapon.fire(player._head.global_position, aim(player, player.global_position + Vector3(0, 0, -3)), [player.get_rid()])


func aim(player: FpsController, target: Vector3) -> Vector3:
	return (target - player._head.global_position).normalized()


func _on_child_added(node: Node) -> void:
	for type in added:
		if node.get_script() and node.get_script().get_global_name() == type:
			added[type] += 1


func _initialize() -> void:
	role = OS.get_cmdline_user_args()[0]
	NetSession.port = PORT
	NetSession.address = "127.0.0.1"
	NetSession.mode = NetSession.Mode.HOST if role == "host" else NetSession.Mode.JOIN
	level = load("res://game/levels/test_level.tscn").instantiate()
	level.child_entered_tree.connect(_on_child_added)
	root.add_child(level)
	current_scene = level
	await process_frame
	# Niente zombie a caso: questo test prova solo colpi, vita e muri.
	WaveDirector.of(level).host_pause()
	var players: Node = level.get_node("Players")
	var ready := await wait_until(func(): return players.get_child_count() == 2 \
			and players.has_node(str(get_multiplayer().get_unique_id())), 15.0)
	check("due giocatori in partita", ready)
	if ready:
		await give_test_loadouts(players, 2)
		if role == "host":
			await run_host(players)
		else:
			await run_client(players)
	print("[%s] RISULTATO: %d errori" % [role, failures])
	quit(1 if failures > 0 else 0)


## L'host dà a tutti carabina e lanciagranate (come facevano i vecchi test);
## gli altri aspettano di riceverle.
func give_test_loadouts(players: Node, count: int) -> void:
	if role == "host":
		for player: FpsController in players.get_children():
			player.weapon().host_set_loadout([["carbine"], ["grenade_launcher"]], 0)
	var got := await wait_until(func(): return players.get_child_count() == count and players.get_children().all(
			func(pl): return pl.weapon().specs() == [["carbine"], ["grenade_launcher"]]), 15.0)
	check("armi di prova arrivate a tutti", got, str(players.get_children().map(func(pl): return pl.weapon().specs())))


func run_host(players: Node) -> void:
	var me: FpsController = players.get_node("1")
	var other: FpsController = players.get_children().filter(func(n): return n.name != "1")[0]
	var near := health_of("Dummies/DummyNear")
	var mid := health_of("Dummies/DummyMid")
	var far := health_of("Dummies/DummyFar")
	var wall: DestructibleBlocks = level.get_node("Destructibles/WallBehindSpawn")
	move_to(me, Vector3(8, 0.1, 3))

	# 1) Il client spara al manichino vicino: il danno lo applica l'host.
	var numbers_before: int = added.DamageNumber
	var hit := await wait_until(func(): return near.current < near.max_health, 20.0)
	check("il colpo del client danneggia il manichino sull'host", hit and is_equal_approx(near.current, 88.0), "vita=%.0f" % near.current)
	# Le scie viaggiano come pacchetti non garantiti (ENet può scartarne qualcuno,
	# soprattutto appena connessi e con il PC sotto carico): il client spara
	# altri tre colpi a terra, e ne basta una.
	var seen := await wait_until(func(): return added.Tracer >= 1, 3.0)
	check("l'host vede le scie dei colpi del client", seen, "scie=%d" % added.Tracer)
	check("l'host non vede numeri per i colpi del client", added.DamageNumber == numbers_before, "numeri=%d" % (added.DamageNumber - numbers_before))

	# 2) L'host spara al manichino a metà: lui vede il suo numero.
	await wait_seconds(1.0)
	move_to(me, Vector3(1, 0.1, -14))
	await physics_frame
	numbers_before = added.DamageNumber
	me._weapon.fire(me._head.global_position, aim(me, mid.get_parent().global_position + Vector3.UP), [me.get_rid()])
	check("il colpo dell'host danneggia il manichino", is_equal_approx(mid.current, 88.0), "vita=%.0f" % mid.current)
	check("l'host vede il numero del suo colpo", added.DamageNumber == numbers_before + 1)
	await fire_at_floor(me)

	# 3) Il client lancia una granata: il proiettile vero è quello dell'host.
	var boom := await wait_until(func(): return far.current < far.max_health, 20.0)
	check("la granata del client danneggia il manichino sull'host", boom, "vita=%.0f" % far.current)
	check("sull'host il proiettile del client è comparso", added.Projectile >= 1, "proiettili=%d" % added.Projectile)

	# 4) Il giocatore del client va a terra: decide l'host, e lo vede disteso.
	await wait_seconds(1.0)
	var other_health := HealthComponent.of(other)
	other_health.take_damage(1000.0)
	await wait_seconds(0.6)
	var body: PlayerModel = other.get_node("Body")
	check("il giocatore a terra è disteso", body.current_clip() == &"ATerra" and other.life == FpsController.Life.DOWNED, "clip=%s" % body.current_clip())
	# L'host lo rianima tenendo premuto E.
	move_to(me, other.global_position + Vector3(1.2, 0, 0))
	Input.action_press("interact")
	var revived := await wait_until(func(): return other_health.is_alive(), 4.0)
	Input.action_release("interact")
	check("l'host lo rianima in 3 s, con il 40% della vita", revived and is_equal_approx(other_health.current, 40.0), "vita=%.0f" % other_health.current)
	await wait_seconds(0.6)
	check("e si rialza", body.current_clip() != &"ATerra", "clip=%s" % body.current_clip())
	move_to(me, Vector3(0, 0.1, 0))

	# 5) Il client cade fuori dal livello: l'host lo fa morire, rinasce a fine ondata.
	var fell := await wait_until(func(): return other.life == FpsController.Life.DEAD, 15.0)
	check("chi cade fuori dal livello muore (lo decide l'host)", fell)
	await wait_seconds(0.5)
	WaveDirector.of(level).wave_cleared.emit(1)
	revived = await wait_until(func(): return other_health.is_alive(), 3.0)
	check("e rinasce a fine ondata", revived)

	# 6) Il client tira un pugno al muro: lo calcola l'host.
	var blocks := wall.blocks_left()
	var broke := await wait_until(func(): return wall.blocks_left() < blocks, 15.0)
	check("il pugno del client stacca un pezzo di muro sull'host", broke, "blocchi=%d" % wall.blocks_left())

	var left := await wait_until(func(): return players.get_child_count() == 1, 15.0)
	check("il client esce", left)


func run_client(players: Node) -> void:
	var me: FpsController = players.get_node(str(get_multiplayer().get_unique_id()))
	var near := health_of("Dummies/DummyNear")
	var mid := health_of("Dummies/DummyMid")
	var far := health_of("Dummies/DummyFar")
	var wall: DestructibleBlocks = level.get_node("Destructibles/WallBehindSpawn")
	var my_health := HealthComponent.of(me)
	var confirmed: Array = []
	me._weapon.dealt_damage.connect(func(_t, amount, killed): confirmed.append([amount, killed]))
	var punched: Array = []
	me._melee.dealt_damage.connect(func(_t, amount, _k): punched.append(amount))

	check("da client la vita non si cambia da soli", near.take_damage(50.0) == 0.0 and near.current == near.max_health)

	# 1) Spara al manichino vicino.
	await wait_seconds(1.0)
	move_to(me, Vector3(-3, 0.1, -4))
	await physics_frame
	me._weapon.fire(me._head.global_position, aim(me, near.get_parent().global_position + Vector3.UP), [me.get_rid()])
	check("la scia del proprio colpo si vede subito", added.Tracer == 1)
	check("prima della conferma dell'host niente danno", near.current == near.max_health and confirmed.is_empty())
	var ok := await wait_until(func(): return not confirmed.is_empty(), 3.0)
	check("l'host conferma il danno (hitmarker)", ok and is_equal_approx(confirmed[0][0], 12.0), str(confirmed))
	check("compare il numero del danno", added.DamageNumber == 1, "numeri=%d" % added.DamageNumber)
	ok = await wait_until(func(): return is_equal_approx(near.current, 88.0), 3.0)
	check("la vita del manichino arriva dall'host", ok, "vita=%.0f" % near.current)
	await fire_at_floor(me)

	# 2) L'host spara al manichino a metà: niente numeri per noi, ma la vita cala.
	var numbers_before: int = added.DamageNumber
	var tracers_before: int = added.Tracer
	ok = await wait_until(func(): return mid.current < mid.max_health, 20.0)
	await wait_seconds(0.3)
	check("si vede il colpo dell'host sul manichino", ok and is_equal_approx(mid.current, 88.0), "vita=%.0f" % mid.current)
	# Come sopra: l'host spara altri tre colpi a terra, ne basta una scia.
	var seen := await wait_until(func(): return added.Tracer > tracers_before, 3.0)
	check("si vedono le scie dei colpi dell'host", seen)
	check("nessun numero per i colpi degli altri", added.DamageNumber == numbers_before)

	# 3) Granata sul manichino lontano.
	confirmed.clear()
	move_to(me, Vector3(-1, 0.1, -24))
	me._weapon.equip(1)
	await wait_seconds(0.5)
	me._weapon.fire(me._head.global_position, aim(me, far.get_parent().global_position + Vector3(0, 0.8, 0)), [me.get_rid()])
	check("il proprio proiettile parte subito", added.Projectile == 1)
	ok = await wait_until(func(): return not confirmed.is_empty(), 4.0)
	check("l'host conferma il danno della granata", ok, str(confirmed))
	ok = await wait_until(func(): return far.current < far.max_health, 3.0)
	check("la vita del manichino colpito arriva dall'host", ok, "vita=%.0f" % far.current)
	ok = await wait_until(func(): return added.ExplosionEffect >= 1, 2.0)
	check("si vede l'esplosione", ok)
	me._weapon.equip(0)

	# 4) L'host ci manda a terra, poi ci rianima.
	var dead := await wait_until(func(): return not my_health.is_alive(), 10.0)
	check("si va a terra per decisione dell'host", dead)
	await wait_seconds(0.2)
	check("schermata A TERRA e arma nascosta", me.life == FpsController.Life.DOWNED \
			and me._hud.get_node("DeathLabel").text.begins_with("A TERRA") and not me._weapon.visible)
	var helped := await wait_until(func(): return me.revive_progress > 0.3, 4.0)
	check("si vede la rianimazione dell'host", helped and me._hud._revive_bar.visible, "%.2f" % me.revive_progress)
	var revived := await wait_until(func(): return my_health.is_alive(), 4.0)
	check("rianimati con il 40% della vita", revived and is_equal_approx(my_health.current, 40.0), "vita=%.0f" % my_health.current)
	await wait_seconds(0.2)
	check("schermata nascosta e arma in mano", not me._hud.get_node("DeathLabel").visible and me._weapon.visible)

	# 5) Caduta fuori dal livello: morti, si rinasce a fine ondata vicino all'host.
	await wait_seconds(1.0)
	move_to(me, Vector3(0, -40, 0))
	dead = await wait_until(func(): return me.life == FpsController.Life.DEAD, 5.0)
	check("cadendo fuori dal livello si muore", dead and me._hud.get_node("DeathLabel").text.begins_with("SEI MORTO"))
	revived = await wait_until(func(): return my_health.is_alive(), 6.0)
	await wait_seconds(0.2)
	check("e si rinasce vicino all'host", revived and me.global_position.distance_to(Vector3(0, 0.1, 0)) < 2.0, "pos=%s" % me.global_position)

	# 6) Pugno al muro dietro la partenza.
	await wait_seconds(0.5)
	move_to(me, Vector3(0, 0.1, 5.8), PI)
	await wait_seconds(1.0)
	var blocks := wall.blocks_left()
	me._melee.attack(me._head.global_position, Vector3(0, 0, 1), me)
	check("il pugno non rompe il muro prima che decida l'host", wall.blocks_left() == blocks)
	var broke := await wait_until(func(): return wall.blocks_left() < blocks, 2.0)
	check("il pezzo staccato dall'host si vede anche qui", broke, "blocchi=%d" % wall.blocks_left())
	await wait_seconds(1.0)
	NetSession.leave(self)
	await wait_seconds(0.5)
