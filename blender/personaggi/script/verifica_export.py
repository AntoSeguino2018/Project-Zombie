"""Verifica dell'export della fase 10: reimporta i .glb in una scena vuota e fa un foglio di render.

Riga in alto: il personaggio con le clip Ferma, Corsa, Sinistra, ATerra e Rianima, con i colori presi
dalla texture (se la tavolozza o le UV fossero sbagliate, i colori non tornerebbero).
Riga in basso: il pugno visto da dietro e sopra, come dalla camera, e di lato.

    python -B .claude/skills/blender-core/scripts/run_in_blender.py blender/personaggi/script/verifica_export.py -- --out blender/personaggi/render/fase10_export.png
"""
import bpy, json, math, os, sys
import numpy as np
from mathutils import Vector

PROGETTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
CARTELLA = os.path.join(PROGETTO, "assets", "models", "characters")
W, H = 300, 420
# clip, fotogramma, vista
SCATTI = [("Ferma", 1, "fronte"), ("Ferma", 1, "tq"), ("Corsa", 5, "lato"), ("Sinistra", 5, "fronte"),
          ("ATerra", 8, "tq"), ("Rianima", 10, "lato")]


def argomenti():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return os.path.abspath(a[a.index("--out") + 1])


def camera(sc, direzione, bersaglio, scala):
    cam = sc.camera
    d = Vector(direzione).normalized()
    cam.location = Vector(bersaglio) + d * 4
    cam.rotation_euler = (Vector(bersaglio) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = scala


def scatta(sc, tmp):
    sc.render.filepath = tmp
    bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(tmp)
    px = np.empty(im.size[0] * im.size[1] * 4, np.float32)
    im.pixels.foreach_get(px)
    bpy.data.images.remove(im)
    return px.reshape(H, W, 4)


def run():
    out = argomenti()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    r = sc.render
    r.engine = "BLENDER_WORKBENCH"
    r.resolution_x, r.resolution_y = W, H
    sh = sc.display.shading
    sh.light, sh.color_type = "STUDIO", "TEXTURE"
    sc.render.fps = 30
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type = "ORTHO"
    sc.collection.objects.link(cam)
    sc.camera = cam

    bpy.ops.import_scene.gltf(filepath=os.path.join(CARTELLA, "personaggio_n1.glb"))
    personaggio = [o for o in sc.objects if o.type in ("MESH", "ARMATURE")]
    arm = next(o for o in personaggio if o.type == "ARMATURE")
    mesh = next(o for o in personaggio if o.type == "MESH")
    azioni = {a.name: a for a in bpy.data.actions}
    info = {"azioni": sorted(azioni), "dimensioni": [round(d, 3) for d in mesh.dimensions],
            "ossa": len(arm.data.bones), "materiali": [m.name for m in mesh.data.materials]}

    viste = {"fronte": (0, -1, 0), "lato": (1, 0, 0), "tq": (1, -1, 0.3)}
    tmp = out + "_t.png"
    sopra = []
    for nome, f, vista in SCATTI:
        a = next(v for k, v in azioni.items() if k == nome or k.startswith(nome + "_"))
        arm.animation_data.action = a
        if a.slots:
            arm.animation_data.action_slot = a.slots[0]
        sc.frame_set(f)
        basso = nome in ("ATerra", "Rianima")
        camera(sc, viste[vista], (0, 0, 0.5 if basso else 0.85), 2.6 if basso else 2.2)
        sopra.append(scatta(sc, tmp))
    for o in personaggio:
        o.hide_render = True

    bpy.ops.import_scene.gltf(filepath=os.path.join(CARTELLA, "personaggio_n1_pugno.glb"))
    pugno = next(o for o in sc.objects if o.type == "MESH" and o not in personaggio)
    info["pugno"] = [round(d, 3) for d in pugno.dimensions]
    sotto = []
    # dalla camera: dietro (-Y in Blender = +Z in Godot) e un po' sopra; poi di lato e dall'alto
    for d in ((0.25, -1, 0.45), (1, 0, 0), (0, 0, 1), (0, 1, 0.2), (-1, -0.3, 0.2), (0.6, -1, -0.3)):
        camera(sc, d, (0, 0.05, 0), 0.5)
        sotto.append(scatta(sc, tmp))
    os.remove(tmp)
    foglio = np.concatenate([np.concatenate(sotto, axis=1), np.concatenate(sopra, axis=1)], axis=0)
    img = bpy.data.images.new("foglio", foglio.shape[1], foglio.shape[0])
    img.pixels.foreach_set(foglio.ravel())
    img.filepath_raw, img.file_format = out, "PNG"
    img.save()
    return {"ok": True, "out": out, **info}


print("@@JSON@@" + json.dumps(run()))
