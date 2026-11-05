"""Fase 0 del Personaggio N.1: crea da zero blender/personaggi/personaggio_n1.blend.

Contenuto: unità in metri, collezioni, la bozza come immagine di riferimento in scala
(vista frontale e testa di profilo), le guide (altezza, quote della bozza, capsula del
giocatore, punto della camera di gioco) e una camera di verifica.

Si lancia senza finestra (riparte da una scena vuota e sovrascrive il file):
    python -B .claude/skills/blender-core/scripts/run_in_blender.py blender/personaggi/script/fase0_preparazione.py
"""
import bpy, bmesh, json, math, os
from mathutils import Matrix

assert bpy.app.background, "Solo senza finestra: azzera la scena."

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
FILE = os.path.join(ROOT, "personaggio_n1.blend")
BOZZA = os.path.normpath(os.path.join(ROOT, "..", "Peronaggio_N1_bozza.jpeg"))

# Scala della bozza: 1,72 m su 967 px (punta dei capelli y 608, suola y 1575), linea centrale x 340.
ALTEZZA = 1.72
PX = ALTEZZA / 967
# Quote ricavate dalla bozza (m), le stesse della scheda.
QUOTE = [
    ("Capelli", 1.72), ("Occhi", 1.60), ("Mento", 1.47), ("Spalla", 1.37),
    ("Cintura_su", 0.995), ("Cintura_giu", 0.935), ("Ginocchio", 0.48),
    ("Risvolto_su", 0.24), ("Risvolto_giu", 0.15),
]
# Capsula del giocatore in Godot (game/player/player.tscn): raggio 0,4, altezza 1,8, camera a 1,6.
CAPSULA_R, CAPSULA_H, CAMERA_Z = 0.4, 1.8, 1.6


def collezione(nome, padre):
    c = bpy.data.collections.new(nome)
    padre.children.link(c)
    return c


def guida(ob, colore):
    """Oggetto d'aiuto: solo filo, non si seleziona, non si renderizza."""
    ob.display_type = "WIRE"
    ob.show_in_front = True
    ob.hide_render = True
    ob.hide_select = True
    ob.color = colore
    return ob


def mesh_da_bmesh(nome, bm, coll):
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nome, me)
    coll.objects.link(ob)
    return ob


def bozza(nome, img, loc, rot, coll):
    """Immagine di riferimento centrata (offset -0,5), lato lungo = 1920 px in scala."""
    ob = bpy.data.objects.new(nome, None)
    ob.empty_display_type = "IMAGE"
    ob.data = img
    ob.empty_display_size = max(img.size) * PX
    ob.empty_image_offset = (-0.5, -0.5)
    ob.empty_image_side = "FRONT"
    ob.show_empty_image_only_axis_aligned = True   # solo nelle viste allineate
    ob.show_empty_image_perspective = False
    ob.use_empty_image_alpha = True
    ob.color[3] = 0.5
    ob.location = loc
    ob.rotation_euler = rot
    ob.hide_select = True
    coll.objects.link(ob)
    return ob


def run():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 1.0
    sc.unit_settings.length_unit = "METERS"

    asset = collezione("Personaggio_N1", sc.collection)
    rif = collezione("N1_Riferimenti", asset)
    guide = collezione("N1_Guide", asset)

    # --- bozza: la vista frontale guarda -Y (immagine dietro, a +Y); il profilo si vede dalla destra (+X)
    img = bpy.data.images.load(BOZZA, check_existing=True)
    w, h = img.size
    cx, cy = w / 2, h / 2
    fronte = bozza("Bozza_Fronte", img, ((cx - 340) * PX, 0.6, (1575 - cy) * PX),
                   (math.radians(90), 0, 0), rif)
    # Profilo: stessa immagine ruotata nel piano YZ; posizione allineata a mano nella versione precedente.
    profilo = bozza("Bozza_Profilo", img, (-0.6, -0.249, 0.899),
                    (math.radians(90), 0, math.radians(90)), rif)

    # --- guide
    bm = bmesh.new()
    for _, z in QUOTE:
        a = bm.verts.new((-0.45, 0, z))
        b = bm.verts.new((0.45, 0, z))
        bm.edges.new((a, b))
    a, b = bm.verts.new((0, 0, 0)), bm.verts.new((0, 0, ALTEZZA))
    bm.edges.new((a, b))
    quote = guida(mesh_da_bmesh("Guida_Quote", bm, guide), (1.0, 0.55, 0.1, 1))

    # capsula: cilindro aperto e due sfere, dalla base a CAPSULA_H (è solo un filo di guida)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=24, radius1=CAPSULA_R, radius2=CAPSULA_R,
                          depth=CAPSULA_H - 2 * CAPSULA_R,
                          matrix=Matrix.Translation((0, 0, CAPSULA_H / 2)))
    for z, verso in ((CAPSULA_R, -1), (CAPSULA_H - CAPSULA_R, 1)):
        geom = bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=CAPSULA_R,
                                         matrix=Matrix.Translation((0, 0, z)))
        # tiene solo la semisfera esterna
        via = [v for v in geom["verts"] if (v.co.z - z) * verso < -1e-6]
        bmesh.ops.delete(bm, geom=via, context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    capsula = guida(mesh_da_bmesh("Guida_Capsula", bm, guide), (0.2, 0.6, 1.0, 1))

    cam_gioco = bpy.data.objects.new("Guida_CameraGioco", None)
    cam_gioco.empty_display_type = "SPHERE"
    cam_gioco.empty_display_size = 0.03
    cam_gioco.location = (0, 0, CAMERA_Z)
    cam_gioco.hide_select = True
    guide.objects.link(cam_gioco)

    # --- camera di verifica: ortogonale, di fronte, inquadra il corpo intero
    cd = bpy.data.cameras.new("CameraVerifica")
    cd.type = "ORTHO"
    cd.ortho_scale = 2.0
    cam = bpy.data.objects.new("CameraVerifica", cd)
    cam.location = (0, -4.0, 0.9)
    cam.rotation_euler = (math.radians(90), 0, 0)
    rif.objects.link(cam)
    cam.hide_set(True)   # nascosta nella vista (il riquadro coprirebbe la bozza), funziona lo stesso nei render
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = 800, 1000

    # aiuti di sola visualizzazione: fuori dal render
    for ob in (fronte, profilo, cam_gioco):
        ob.hide_render = True

    bpy.ops.wm.save_as_mainfile(filepath=FILE, relative_remap=True)
    return {
        "ok": True, "file": FILE,
        "bozza_px": [w, h], "bozza_m": round(max(w, h) * PX, 4),
        "bozza_fronte": [round(c, 4) for c in fronte.location],
        "capsula_dim": [round(d, 3) for d in capsula.dimensions],
        "quote_dim": [round(d, 3) for d in quote.dimensions],
        "img_path": img.filepath,
        "collezioni": {c.name: [o.name for o in c.objects] for c in asset.children},
    }


print("@@JSON@@" + json.dumps(run()))
