extends SceneTree
# Personaggio N.1 sul giocatore: modello unico (una mesh, un materiale, nove
# clip), girato verso -Z, solo ombra per il giocatore locale; clip scelte dal
# movimento (fermo, avanti, scatto, indietro, lati, salto) e dallo stato (a
# terra, rialzato); pugno in prima persona con il braccio robotico.
var failures := 0
var level: Node
var p: FpsController
var body: PlayerModel


func check(name: String, ok: bool, info: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: failures += 1


func frames(n: int) -> void:
	for i in n: await physics_frame


func seconds(s: float) -> void:
	await frames(int(s * 60.0))


func move_to(where: Vector3, yaw := 0.0) -> void:
	p.global_position = where
	p.velocity = Vector3.ZERO
	p._yaw = yaw
	p._pitch = 0.0
	p.rotation.y = yaw
	p.reset_physics_interpolation()


func anim() -> AnimationPlayer:
	return body.find_child("AnimationPlayer") as AnimationPlayer


func _initialize() -> void:
	level = load("res://game/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	level.get_node("Waves").free()
	for d in level.get_node("Dummies").get_children(): d.free()
	p = level.get_node("Players/1")
	body = p.get_node("Body") as PlayerModel
	HealthComponent.of(p).damage_filter = func(_a, _s, _h): return 0.0
	await frames(5)
	test_model()
	await test_moves()
	await test_down()
	await test_fist()
	print("RISULTATO: %d errori" % failures)
	quit(1 if failures > 0 else 0)


func test_model() -> void:
	check("il giocatore ha il modello del Personaggio N.1", body != null)
	var meshes := body.find_children("*", "MeshInstance3D")
	check("una mesh sola", meshes.size() == 1, "%d" % meshes.size())
	var mesh := meshes[0] as MeshInstance3D
	check("un materiale solo", mesh.mesh.get_surface_count() == 1, "%d" % mesh.mesh.get_surface_count())
	var height := mesh.get_aabb().size.y
	check("alto circa 1,75 m", absf(height - 1.75) < 0.05, "%.3f" % height)
	var names := anim().get_animation_list()
	var all := ["Ferma", "Cammina", "Corsa", "Indietro", "Sinistra", "Destra", "Salto", "ATerra", "Rianima"]
	check("nove clip", all.all(func(n): return names.has(n)), str(names))
	check("i cicli si ripetono, il salto no", anim().get_animation(&"Cammina").loop_mode == Animation.LOOP_LINEAR \
			and anim().get_animation(&"Salto").loop_mode == Animation.LOOP_NONE)
	check("per sé si vede solo l'ombra",
			mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	# Guarda dove guarda il giocatore (-Z): la punta del piede è davanti al tallone.
	var skeleton := body.find_child("Skeleton3D") as Skeleton3D
	var toe := p.to_local(skeleton.to_global(skeleton.get_bone_global_rest(skeleton.find_bone("toe.L")).origin))
	var foot := p.to_local(skeleton.to_global(skeleton.get_bone_global_rest(skeleton.find_bone("foot.L")).origin))
	check("girato verso -Z", toe.z < foot.z - 0.05, "punta %.2f, caviglia %.2f" % [toe.z, foot.z])
	check("con i piedi a terra", absf(p.to_local(mesh.to_global(mesh.get_aabb().position)).y) < 0.03)


## Tiene premute le azioni per un po' e restituisce la clip e la velocità di riproduzione.
func hold(actions: Array, s: float) -> Array:
	for a in actions: Input.action_press(a)
	await seconds(s)
	var out := [body.current_clip(), anim().speed_scale]
	for a in actions: Input.action_release(a)
	await seconds(0.4)
	move_to(Vector3(0, 0.1, 0))
	await seconds(0.3)
	return out


func test_moves() -> void:
	move_to(Vector3(0, 0.1, 0))
	await seconds(0.6)
	check("fermo: Ferma", body.current_clip() == &"Ferma", body.current_clip())
	var r := await hold(["move_forward"], 0.5)
	check("avanti: Cammina, accelerata per i 7 m/s", r[0] == &"Cammina" and r[1] > 1.8, "%s %.2f" % r)
	r = await hold(["move_forward", "sprint"], 0.5)
	check("scatto: Corsa", r[0] == &"Corsa" and r[1] > 1.8, "%s %.2f" % r)
	r = await hold(["move_back"], 0.5)
	check("indietro: Indietro", r[0] == &"Indietro", "%s %.2f" % r)
	r = await hold(["move_left"], 0.5)
	check("a sinistra: Sinistra (velocità al limite)", r[0] == &"Sinistra" and is_equal_approx(r[1], 2.5), "%s %.2f" % r)
	r = await hold(["move_right"], 0.5)
	check("a destra: Destra", r[0] == &"Destra", "%s %.2f" % r)
	Input.action_press("jump")
	await seconds(0.3)
	Input.action_release("jump")
	check("salto: Salto, partito dallo stacco", body.current_clip() == &"Salto" \
			and anim().current_animation_position >= PlayerModel.JUMP_TAKEOFF, body.current_clip())
	await seconds(1.5)
	check("atterrato: di nuovo Ferma", body.current_clip() == &"Ferma", body.current_clip())


func test_down() -> void:
	# Da soli, a terra si perderebbe la run: qui serve solo la posa.
	RunManager.of(level).set_physics_process(false)
	p._host_set_life(FpsController.Life.DOWNED)
	await seconds(0.3)
	check("a terra: ATerra, ferma se non si striscia", body.current_clip() == &"ATerra" and anim().speed_scale < 0.05,
			"%s %.2f" % [body.current_clip(), anim().speed_scale])
	Input.action_press("move_forward")
	await seconds(0.6)
	check("strisciando la clip va (1,5 m/s = velocità nominale)", absf(anim().speed_scale - 1.0) < 0.15,
			"%.2f" % anim().speed_scale)
	Input.action_release("move_forward")
	p.host_revive()
	await seconds(0.4)
	check("rialzato: non più ATerra", body.current_clip() != &"ATerra" and p.is_standing(), body.current_clip())


func test_fist() -> void:
	var fist := p.get_node("Camera3D/Melee/Fist") as Node3D
	var arm := fist.find_children("*", "MeshInstance3D")
	check("pugno con il braccio robotico (una mesh)", arm.size() == 1, "%d" % arm.size())
	if arm.size() == 1:
		var mesh := arm[0] as MeshInstance3D
		check("senza ombra", mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var size := mesh.get_aabb().size
		check("avambraccio lungo circa 39 cm, verso la camera", size.z > 0.35 and size.x < 0.15, str(size))
	check("nascosto finché non si tira un pugno", not fist.visible)
	# Senza finestra il mouse non è catturato e il tasto non arriva: si lancia l'animazione.
	p._melee._animate()
	await frames(3)
	check("visibile durante il pugno", fist.visible)
