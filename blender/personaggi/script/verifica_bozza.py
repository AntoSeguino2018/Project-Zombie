"""Confronto con la bozza: render ortogonale del modello allineato pixel per pixel al disegno,
sovrapposto in trasparenza (di fronte e di profilo).

Usa le immagini `Bozza_Fronte` e `Bozza_Profilo` del file: la camera inquadra esattamente
l'immagine, così un pixel del render cade sullo stesso punto della bozza.

    python -B .claude/skills/blender-core/scripts/run_in_blender.py --blend blender/personaggi/personaggio_n1.blend blender/personaggi/script/verifica_bozza.py -- --out CARTELLA [--oggetti A B]
"""
import bpy, json, math, os, sys
import numpy as np
from mathutils import Vector


def argomenti():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out, oggetti = None, []
    i = 0
    while i < len(a):
        if a[i] == "--out":
            out = a[i + 1]
            i += 2
        elif a[i] == "--oggetti":
            i += 1
            while i < len(a) and not a[i].startswith("--"):
                oggetti.append(a[i])
                i += 1
        else:
            i += 1
    return out, oggetti


def pixel(img):
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(h, w, 4)


def render_su(empty, oggetti, out, nome):
    sc = bpy.context.scene
    img = empty.data
    w, h = img.size
    size = empty.empty_display_size
    cam = bpy.data.objects.get("N1_CamBozza") or bpy.data.objects.new("N1_CamBozza", bpy.data.cameras.new("N1_CamBozza"))
    if cam.name not in sc.collection.objects:
        sc.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size
    # stessa rotazione dell'immagine: la camera guarda lungo il suo -Z locale, cioè verso l'immagine;
    # sta a 3 m davanti all'immagine, lungo la normale, con il modello in mezzo
    m = empty.matrix_world
    normale = (m.to_3x3() @ Vector((0, 0, 1))).normalized()
    cam.rotation_euler = empty.rotation_euler
    cam.location = m.translation + normale * 3.0
    sc.camera = cam
    r = sc.render
    r.engine = "BLENDER_WORKBENCH"
    r.resolution_x, r.resolution_y, r.resolution_percentage = w, h, 100
    r.film_transparent = True
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    sh = sc.display.shading
    sh.light, sh.color_type = "STUDIO", "SINGLE"
    sh.single_color = (0.85, 0.35, 0.2)
    visibili = set(oggetti)
    nascosti = []
    for ob in sc.objects:
        if ob.type in {"MESH", "CURVE", "CURVES"} and ob.name not in visibili and not ob.hide_render:
            ob.hide_render = True
            nascosti.append(ob)
    tmp = os.path.join(out, f"_render_{nome}.png")
    r.filepath = tmp
    bpy.ops.render.render(write_still=True)
    for ob in nascosti:
        ob.hide_render = False
    ren = bpy.data.images.load(tmp)
    a = pixel(ren)
    b = pixel(img)
    alfa = a[..., 3:4] * 0.55
    comp = b.copy()
    comp[..., :3] = b[..., :3] * (1 - alfa) + a[..., :3] * alfa
    comp[..., 3] = 1.0
    res = bpy.data.images.new(f"conf_{nome}", w, h, alpha=True)
    res.pixels.foreach_set(comp.ravel())
    res.filepath_raw = os.path.join(out, f"confronto_{nome}.png")
    res.file_format = "PNG"
    res.save()
    bpy.data.images.remove(ren)
    os.remove(tmp)
    return res.filepath_raw


def run():
    out, oggetti = argomenti()
    os.makedirs(out, exist_ok=True)
    if not oggetti:
        oggetti = [o.name for c in bpy.data.collections if c.name.startswith("N1_") and c.name not in ("N1_Riferimenti", "N1_Guide")
                   for o in c.all_objects if o.type == "MESH"]
    return {"ok": True, "oggetti": oggetti,
            "fronte": render_su(bpy.data.objects["Bozza_Fronte"], oggetti, out, "fronte"),
            "profilo": render_su(bpy.data.objects["Bozza_Profilo"], oggetti, out, "profilo")}


print("@@JSON@@" + json.dumps(run()))
