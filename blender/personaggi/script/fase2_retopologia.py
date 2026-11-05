"""Fase 2 del Personaggio N.1: mesh di gioco del corpo dalla sorgente fitta della fase 1.

Metodo (skill blender-retopology-uv, come `auto_retopo.py --method quadriflow`): copia della
sorgente, remesh a voxel, Quadriflow simmetrico a quad, proiezione sulla sorgente (Shrinkwrap).
In più rispetto allo script della skill: prima di Quadriflow si fondono i vertici a meno di
0,3 mm, perché Quadriflow rifiuta i lati più corti di 0,1 mm che il remesh a volte lascia
("The mesh needs to be manifold...").

Il risultato è `N1_Corpo` nella collezione `N1_Gioco`; la sorgente `N1_Corpo_alto` resta
nascosta. UV automatiche (Smart UV Project): i colori sono pieni, le UV servono a vestiti ed export.

    python -B .claude/skills/blender-core/scripts/run_in_blender.py --blend blender/personaggi/personaggio_n1.blend blender/personaggi/script/fase2_retopologia.py [-- --quad 3000 --prova]
--prova: non salva, riporta solo i numeri per zona.
"""
import bpy, bmesh, json, math, os, sys

QUAD = 5000            # quad richiesti a Quadriflow (ne dà un po' meno)
PROGETTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
SKILL_UV = os.path.join(PROGETTO, ".claude", "skills", "blender-retopology-uv", "scripts")


def argomenti():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    quad = int(a[a.index("--quad") + 1]) if "--quad" in a else QUAD
    return quad, "--prova" in a


def ctx(ob):
    return bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob],
                                     selected_editable_objects=[ob])


def applica(ob):
    for nome in [m.name for m in ob.modifiers]:
        with ctx(ob):
            bpy.ops.object.modifier_apply(modifier=nome)


def zone(me):
    """Triangoli per zona del corpo (centri delle facce)."""
    def t(f):
        return sum(len(p.vertices) - 2 for p in me.polygons if f(p.center))
    return {
        "totale": t(lambda c: True),
        "testa_collo": t(lambda c: c.z > 1.44 and abs(c.x) < 0.10),
        "busto": t(lambda c: 0.80 <= c.z <= 1.44 and abs(c.x) < 0.20),
        "braccia": t(lambda c: abs(c.x) >= 0.20 and abs(c.x) < 0.53 and c.z > 0.80),
        "mani": t(lambda c: abs(c.x) >= 0.53),
        "gambe": t(lambda c: 0.10 <= c.z < 0.80),
        "piedi": t(lambda c: c.z < 0.10),
    }


def run():
    quad, prova = argomenti()
    sc = bpy.context.scene
    src = bpy.data.objects["N1_Corpo_alto"]
    asset = bpy.data.collections["Personaggio_N1"]
    gioco = bpy.data.collections.get("N1_Gioco")
    if gioco:
        for ob in list(gioco.objects):
            if ob.name.startswith("N1_Corpo"):
                me = ob.data
                bpy.data.objects.remove(ob)
                if me.users == 0:
                    bpy.data.meshes.remove(me)
    else:
        gioco = bpy.data.collections.new("N1_Gioco")
        asset.children.link(gioco)

    low = src.copy()
    low.data = src.data.copy()
    low.name = low.data.name = "N1_Corpo"
    low.hide_render = False      # la sorgente è nascosta nei render: la copia non deve ereditarlo
    gioco.objects.link(low)
    src.hide_set(False)

    # remesh a voxel con la densità del bersaglio (come la skill), poi pulizia dei lati quasi nulli
    area = sum(p.area for p in low.data.polygons)
    low.data.remesh_voxel_size = math.sqrt(area / (quad * 4))
    with ctx(low):
        bpy.ops.object.voxel_remesh()
    bm = bmesh.new()
    bm.from_mesh(low.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=3e-4)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=3e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(low.data)
    bm.free()

    with ctx(low):
        r = bpy.ops.object.quadriflow_remesh(mode="FACES", target_faces=quad, use_mesh_symmetry=True,
                                             use_preserve_sharp=False, seed=0)
    if r != {"FINISHED"}:
        raise RuntimeError(f"Quadriflow: {r}")

    # proiezione sulla sorgente fitta
    sw = low.modifiers.new("Proietta", "SHRINKWRAP")
    sw.target, sw.wrap_method, sw.wrap_mode = src, "PROJECT", "ON_SURFACE"
    sw.use_negative_direction = sw.use_positive_direction = True
    applica(low)

    # suole sul pavimento dopo la proiezione
    for v in low.data.vertices:
        if v.co.z < 0.0:
            v.co.z = 0.0

    # ombreggiatura piatta: lo stile a faccette viene dalla mesh stessa
    for p in low.data.polygons:
        p.use_smooth = False
    low.data.materials.clear()
    low.data.materials.append(bpy.data.materials["M_N1_Provvisorio"])

    numeri = {"quad_richiesti": quad, "facce": len(low.data.polygons),
              "non_quad": sum(1 for p in low.data.polygons if len(p.vertices) != 4),
              "zone": zone(low.data), "dimensioni": [round(d, 3) for d in low.dimensions]}
    if prova:
        return {"ok": True, "prova": True, **numeri}

    # UV automatiche con lo script della skill (gestisce da sé il contesto della modalità modifica)
    sys.path.insert(0, SKILL_UV)
    import uv_pack
    uv = uv_pack.run(objects=[low.name], method="smart", angle=66.0, res=2048, margin_px=8)

    src.hide_set(True)
    src.hide_render = True
    # niente selezione salvata: gli script delle skill senza --objects lavorano sulla selezione
    for ob in sc.objects:
        ob.select_set(False)
    bpy.ops.wm.save_mainfile(compress=True)
    return {"ok": True, **numeri, "uv": uv}


print("@@JSON@@" + json.dumps(run()))
