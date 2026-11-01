extends SceneTree
# Nel Complesso: il giocatore resta nell'atrio e uccide chi arriva entro 12 m.
# Le ondate devono continuare a finire (nessuno zombie incastrato per sempre).
# Segnala gli zombie vivi da più di 45 s e dove sono. (Chiavi per id, non per
# nodo: un dizionario con nodi liberati come chiavi può bloccarsi.)
func _initialize() -> void:
	var level: Node = load("res://game/levels/complex.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await process_frame
	var p: FpsController = level.get_node("Players/1")
	HealthComponent.of(p).damage_filter = func(_a, _s, _h): return 0.0
	var waves := WaveDirector.of(level)
	waves.break_time = 2.0
	waves._time_left = 1.0
	var born := {}
	var reported := {}
	var longest := [0.0]
	waves.wave_started.connect(func(w): print("t=%.0f inizio ondata %d (%d zombie)" % [Time.get_ticks_msec() / 1000.0, w, waves.remaining]))
	var i := 0
	while waves.wave < 10 and i < 60 * 420:
		await physics_frame
		i += 1
		for e in get_nodes_in_group("enemies"):
			var id: int = e.get_instance_id()
			if not HealthComponent.of(e).is_alive():
				continue
			if not born.has(id):
				born[id] = i
			var age: float = (i - born[id]) / 60.0
			longest[0] = maxf(longest[0], age)
			if e.global_position.distance_to(p.global_position) < 12.0:
				HealthComponent.of(e).take_damage(9999.0, p)
			elif age > 45.0 and not reported.has(id):
				reported[id] = true
				print("  LENTO %s %s vivo da 45 s, stato %d, prossimo punto %s" % [e.name,
						e.global_position.snapped(Vector3.ONE * 0.1), e._state,
						e._agent.get_next_path_position().snapped(Vector3.ONE * 0.1)])
	print("RISULTATO: arrivati all'ondata %d in %.0f s di gioco, zombie più longevo %.0f s, segnalati %d" % [
			waves.wave, i / 60.0, longest[0], reported.size()])
	quit()
