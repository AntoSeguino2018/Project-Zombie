"""Render delle pose di stress (azione `QA_Stress` di `stress_poses.py`) per controllare la deformazione.

Un foglio con i fotogrammi 1, 10, 20, 30, 40, 50 da due punti di vista (davanti e tre quarti).
Rende solo le mesh delle collezioni del modello (non la sorgente fitta né le guide).

    python -B .claude/skills/blender-core/scripts/run_in_blender.py --blend blender/personaggi/personaggio_n1.blend blender/personaggi/script/verifica_pose.py -- --out FILE.png
"""
import bpy, json, os, sys
import numpy as np
from mathutils import Vector

FOTOGRAMMI = [1, 10, 20, 30, 40, 50]
VISTE = {"davanti": Vector((0.0, -1.0, 0.12)), "tre_quarti": Vector((0.9, -0.9, 0.35))}
ESCLUSE = {"N1_Riferimenti", "N1_Guide", "N1_Alto"}


def run():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = a[a.index("--out") + 1]
    sc = bpy.context.scene
    mesh = [o for c in bpy.data.collections if c.name.startswith("N1_") and c.name not in ESCLUSE
            for o in c.all_objects if o.type == "MESH" and not o.hide_get() and not o.name.startswith("WGT-")]
    for o in sc.objects:
        o.hide_render = o not in mesh
    cam = bpy.data.objects.new("N1_CamPose", bpy.data.cameras.new("N1_CamPose"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 50
    r = sc.render
    r.engine = "BLENDER_WORKBENCH"
    r.resolution_x, r.resolution_y, r.resolution_percentage = 360, 520, 100
    r.film_transparent = False
    sh = sc.display.shading
    sh.light, sh.color_type = "STUDIO", "MATERIAL"
    righe = []
    tmp = os.path.join(os.path.dirname(out), "_posa.png")
    for nome, d in VISTE.items():
        celle = []
        for f in FOTOGRAMMI:
            sc.frame_set(f)
            target = Vector((0, 0, 0.92))
            eye = target + d.normalized() * 4.2
            cam.location = eye
            cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
            r.filepath = tmp
            bpy.ops.render.render(write_still=True)
            im = bpy.data.images.load(tmp)
            px = np.empty(im.size[0] * im.size[1] * 4, np.float32)
            im.pixels.foreach_get(px)
            celle.append(px.reshape(im.size[1], im.size[0], 4))
            bpy.data.images.remove(im)
        righe.append(np.concatenate(celle, axis=1))
    os.remove(tmp)
    foglio = np.concatenate(righe[::-1], axis=0)     # le immagini partono dal basso: davanti in alto
    h, w = foglio.shape[:2]
    img = bpy.data.images.new("pose", w, h)
    img.pixels.foreach_set(foglio.ravel())
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    return {"ok": True, "file": out, "mesh": [o.name for o in mesh], "fotogrammi": FOTOGRAMMI, "righe": list(VISTE)}


print("@@JSON@@" + json.dumps(run()))
