"""Fase 10 del Personaggio N.1: export per Godot (skill blender-export-pipelines, preset godot).

Produce due file in assets/models/characters/:
- personaggio_n1.glb: il personaggio visto dagli altri giocatori. Tutte le mesh in una sola, legata
  allo scheletro da gioco, con le 9 clip cotte della fase 9.
- personaggio_n1_pugno.glb: avambraccio e mano sinistra chiusa a pugno, mesh fissa per la prima persona.

Prima dell'export, solo in memoria (il .blend non si salva):
- ogni oggetto diventa la sua mesh valutata senza l'Armature: maschere (le facce coperte spariscono
  davvero), sfaccettatura, spessori e smussi applicati, pesi compresi;
- le mesh si uniscono in una sola (`N1_Personaggio`);
- tavolozza (skill blender-game-optimization, riduzione delle chiamate di disegno): i 16 materiali
  diventano uno solo, `M_N1`. Il colore viene da una texture 256 x 256 di 4 x 4 quadrati (64 px) e
  ogni faccia ha le UV al centro del quadrato del suo colore. Metallo e ruvidità vengono da una seconda
  texture (G = ruvidità, B = metallo, come vuole glTF). Con le UV tutte uguali su una faccia la
  texture si legge sempre al livello pieno, senza mescolare i colori vicini;
- i vincoli dello scheletro da gioco verso il rig di controllo si spengono: le pose vengono solo dalle
  azioni cotte, che si rinominano con il nome della clip (`Cammina`, `Corsa`…). Le azioni del rig
  di controllo si tolgono, perché l'export non le prenda per lo scheletro da gioco.

    python -B .claude/skills/blender-core/scripts/run_in_blender.py --blend blender/personaggi/personaggio_n1.blend blender/personaggi/script/fase10_export.py
"""
import bpy, bmesh, json, math, os, sys
from mathutils import Matrix, Quaternion, Vector

PROGETTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
sys.path.insert(0, os.path.join(PROGETTO, ".claude", "skills", "blender-export-pipelines", "scripts"))
import export_asset      # noqa: E402

GAME = "GAME_RIG_N1_Corpo"
USCITA = os.path.join(PROGETTO, "assets", "models", "characters")
ESCLUSE = ("N1_Riferimenti", "N1_Guide", "N1_Alto")
CELLE = 4                # quadrati per lato della tavolozza
LATO = 256               # pixel della tavolozza
# dita chiuse a pugno: gradi di rotazione attorno all'asse X locale (positivo: la punta va verso il palmo)
PUGNO_DITA = {"01": 75.0, "02": 95.0, "03": 70.0}
PUGNO_POLLICE = {"01": 10.0, "02": 35.0, "03": 45.0}
PUGNO_OSSA = ("forearm", "hand", "palm", "f_", "thumb")


def srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def principled(m):
    return next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m.node_tree else None


def oggetti():
    return [o for c in bpy.data.collections if c.name.startswith("N1_") and c.name not in ESCLUSE
            for o in c.all_objects if o.type == "MESH" and not o.name.startswith("WGT-") and o.visible_get()]


def mesh_valutata(ob, collezione, armatura=False):
    """Copia di ob con i modificatori applicati (senza l'Armature, salvo armatura=True) e gli stessi gruppi."""
    arm = [m for m in ob.modifiers if m.type == "ARMATURE"]
    for m in arm:
        m.show_viewport = armatura
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    for m in arm:
        m.show_viewport = True
    nuovo = bpy.data.objects.new(ob.name + "_export", me)
    collezione.objects.link(nuovo)
    nuovo.matrix_world = ob.matrix_world.copy()
    for vg in ob.vertex_groups:            # stesso ordine: i pesi della mesh puntano agli indici dei gruppi
        nuovo.vertex_groups.new(name=vg.name)
    return nuovo


def tavolozza(materiali):
    """Le due texture e il materiale unico. materiali: nomi nell'ordine dei quadrati."""
    colore = bpy.data.images.new("T_N1_Tavolozza", LATO, LATO, alpha=False)
    mr = bpy.data.images.new("T_N1_MetalloRuvido", LATO, LATO, alpha=False)
    mr.colorspace_settings.name = "Non-Color"
    px_c, px_m = [0.0] * (LATO * LATO * 4), [0.0] * (LATO * LATO * 4)
    cella = LATO // CELLE
    valori = {}
    for i, nome in enumerate(materiali):
        m = bpy.data.materials[nome]
        b = principled(m)
        lin = b.inputs["Base Color"].default_value[:3] if b else m.diffuse_color[:3]
        metallo = b.inputs["Metallic"].default_value if b else m.metallic
        ruvido = b.inputs["Roughness"].default_value if b else m.roughness
        # le immagini a 8 bit tengono i valori così come si scrivono: il colore va in sRGB
        c = [srgb(x) for x in lin]
        valori[nome] = {"srgb": [round(x * 255) for x in c], "metallo": metallo, "ruvido": round(ruvido, 2)}
        cx, cy = i % CELLE, i // CELLE
        for y in range(cy * cella, (cy + 1) * cella):
            for x in range(cx * cella, (cx + 1) * cella):
                k = (y * LATO + x) * 4
                px_c[k:k + 4] = [*c, 1.0]
                px_m[k:k + 4] = [1.0, ruvido, metallo, 1.0]
    colore.pixels.foreach_set(px_c)
    mr.pixels.foreach_set(px_m)
    for im in (colore, mr):
        im.file_format = "PNG"
        im.pack()

    mat = bpy.data.materials.new("M_N1")
    nt = mat.node_tree
    b = principled(mat)
    t_c = nt.nodes.new("ShaderNodeTexImage")
    t_c.image, t_c.interpolation = colore, "Closest"
    t_m = nt.nodes.new("ShaderNodeTexImage")
    t_m.image, t_m.interpolation = mr, "Closest"
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(t_c.outputs["Color"], b.inputs["Base Color"])
    nt.links.new(t_m.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs[1], b.inputs["Roughness"])      # G
    nt.links.new(sep.outputs[2], b.inputs["Metallic"])       # B
    return mat, valori


def su_tavolozza(ob, ordine, mat):
    """UV di ogni faccia al centro del quadrato del suo materiale, poi un materiale solo."""
    me = ob.data
    slot = [ordine.index(m.name) for m in me.materials]
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    uv = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        i = slot[p.material_index]
        centro = ((i % CELLE + 0.5) / CELLE, (i // CELLE + 0.5) / CELLE)
        for li in p.loop_indices:
            uv.data[li].uv = centro
        p.material_index = 0
    me.materials.clear()
    me.materials.append(mat)


def unisci(obs, nome):
    with bpy.context.temp_override(active_object=obs[0], object=obs[0], selected_objects=obs,
                                   selected_editable_objects=obs):
        bpy.ops.object.join()
    ob = obs[0]
    ob.name = ob.data.name = nome
    return ob


def pugno(game, collezione, ordine, mat):
    """Avambraccio e mano sinistra a pugno, fissi: il polso nell'origine, l'avambraccio verso -Z di Godot
    (che è +Y qui) e il dorso della mano in alto."""
    braccio = bpy.data.objects["N1_Braccio.L"]
    game.animation_data.action = None
    for pb in game.pose.bones:
        pb.matrix_basis = Matrix()
    for pb in game.pose.bones:
        if pb.name.endswith(".L") and (pb.name.startswith("f_") or pb.name.startswith("thumb")):
            tab = PUGNO_POLLICE if pb.name.startswith("thumb") else PUGNO_DITA
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = Quaternion((1, 0, 0), math.radians(tab[pb.name.split(".")[1]]))
    bpy.context.view_layer.update()
    ob = mesh_valutata(braccio, collezione, armatura=True)
    # solo i pezzi dall'avambraccio in giù (ogni vertice è al 100% su un osso)
    nomi = {vg.index: vg.name for vg in ob.vertex_groups}
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    deform = bm.verts.layers.deform.active
    via = [v for v in bm.verts
           if not any(nomi[g].startswith(PUGNO_OSSA) and w > 0.5 for g, w in v[deform].items())]
    bmesh.ops.delete(bm, geom=via, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    for vg in list(ob.vertex_groups):
        ob.vertex_groups.remove(vg)

    # sistema della mano: Y dal gomito al polso, Z = dorso della mano
    mw = game.matrix_world
    gomito = mw @ game.pose.bones["forearm.L"].head
    polso = mw @ game.pose.bones["hand.L"].head
    y = (polso - gomito).normalized()
    palmo = (mw.to_3x3() @ game.pose.bones["palm.02.L"].matrix.to_3x3()).col[2]   # Z verso il palmo
    z = (-palmo - y * (-palmo).dot(y)).normalized()
    x = y.cross(z)
    base = Matrix((x, y, z)).transposed().to_4x4()        # colonne x, y, z
    centro = mw @ game.pose.bones["hand.L"].tail
    ob.data.transform(base.inverted() @ Matrix.Translation(-centro) @ ob.matrix_world)
    ob.matrix_world = Matrix()
    ob.parent = None
    ob.modifiers.clear()
    su_tavolozza(ob, ordine, mat)
    ob.name = ob.data.name = "N1_Pugno"
    for pb in game.pose.bones:
        pb.matrix_basis = Matrix()
    return ob


def esporta(obs, nome, animazioni):
    """Impostazioni del preset godot della skill. Non si usa export_asset.run perché raccoglie anche
    i figli dello scheletro, cioè tutti gli oggetti originali."""
    out = os.path.join(USCITA, nome)
    kw = dict(export_asset.GLTF_BASE)
    kw.update(export_asset.PRESETS["godot"][1])
    kw.update(export_anim_slide_to_zero=True, export_force_sampling=True)
    if not animazioni:
        kw.update(export_animations=False, export_skins=False)
    for o in bpy.context.scene.objects:
        o.select_set(o in obs)
    bpy.context.view_layer.objects.active = obs[0]
    res = bpy.ops.export_scene.gltf(filepath=out, **kw)
    ok = res == {"FINISHED"} and os.path.exists(out)
    return {"file": out, "ok": ok, "kb": round(os.path.getsize(out) / 1024, 1) if ok else 0,
            "summary": export_asset.glb_summary(out) if ok else None}


def run():
    sc = bpy.context.scene
    sc.frame_set(1)
    game = bpy.data.objects[GAME]
    os.makedirs(USCITA, exist_ok=True)
    col = bpy.data.collections.new("N1_Export")
    sc.collection.children.link(col)

    sorgenti = oggetti()
    ordine = sorted({m.name for o in sorgenti for m in o.data.materials if m})
    if len(ordine) > CELLE * CELLE:
        raise RuntimeError(f"{len(ordine)} materiali: la tavolozza ne tiene {CELLE * CELLE}")
    mat, valori = tavolozza(ordine)

    # scheletro: niente vincoli verso il rig di controllo, solo le azioni cotte con il nome della clip
    for pb in game.pose.bones:
        for c in pb.constraints:
            c.mute = True
    for a in [a for a in bpy.data.actions if not a.name.startswith(GAME + "|")]:
        bpy.data.actions.remove(a)
    clip = []
    for a in list(bpy.data.actions):       # copia: rinominando cambia l'ordine della lista
        a.name = a.name.split("|", 1)[1]
        clip.append(a.name)

    pugno_ob = pugno(game, col, ordine, mat)

    copie = [mesh_valutata(o, col) for o in sorgenti]
    corpo = unisci(copie, "N1_Personaggio")
    su_tavolozza(corpo, ordine, mat)
    corpo.parent = game
    corpo.matrix_parent_inverse = game.matrix_world.inverted()
    mod = corpo.modifiers.new("Armature", "ARMATURE")
    mod.object = game
    game.animation_data.action = bpy.data.actions.get("Ferma")

    gruppi_vuoti = [vg.name for vg in corpo.vertex_groups
                    if not any(g.group == vg.index for v in corpo.data.vertices for g in v.groups)]
    tris = sum(len(p.vertices) - 2 for p in corpo.data.polygons)
    r_corpo = esporta([corpo, game], "personaggio_n1.glb", True)
    r_pugno = esporta([pugno_ob], "personaggio_n1_pugno.glb", False)
    return {"ok": r_corpo["ok"] and r_pugno["ok"], "materiali_uniti": ordine, "tavolozza": valori,
            "clip": clip, "triangoli": tris, "triangoli_pugno": sum(len(p.vertices) - 2 for p in pugno_ob.data.polygons),
            "gruppi_senza_pesi": len(gruppi_vuoti), "corpo": r_corpo, "pugno": r_pugno,
            "dimensioni_pugno": [round(d, 3) for d in pugno_ob.dimensions]}


print("@@JSON@@" + json.dumps(run(), default=str))
