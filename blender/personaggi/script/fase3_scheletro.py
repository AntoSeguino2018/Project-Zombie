"""Fase 3 del Personaggio N.1: scheletro Rigify, pesi della mesh di gioco, scheletro da gioco.

Metodo (skill blender-character-rigging, script `rigify_build.py`, `bind_mesh.py`, `rig_check.py`,
`stress_poses.py`):
1. metarig `human` senza viso (il `basic_human` della skill non ha le dita, che servono alle mani
   robotiche), scalato sull'altezza di `N1_Corpo`;
2. articolazioni messe dove la fase 1 ha costruito il corpo (stesse quote di `fase1_corpo_base.py`):
   braccia in A-pose a 45°, gomiti appena piegati all'indietro e ginocchia in avanti, così l'IK
   sa da che parte piegare; il rollio delle ossa segue le convenzioni del metarig;
3. rig di controllo generato (`RIG_N1_Corpo`), pesi automatici con pulizia (4 influenze, normalizzati),
   scheletro da gioco `GAME_RIG_N1_Corpo` (radice + ossa DEF senza prefisso) a cui passa la mesh;
4. controllo dello scheletro e azione `QA_Stress` con le pose estreme sul rig di controllo.

    python -B .claude/skills/blender-core/scripts/run_in_blender.py --blend blender/personaggi/personaggio_n1.blend blender/personaggi/script/fase3_scheletro.py
"""
import bpy, json, math, os, sys
from mathutils import Vector, Matrix

PROGETTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
sys.path.insert(0, os.path.join(PROGETTO, ".claude", "skills", "blender-character-rigging", "scripts"))
import _bpyx as bx            # noqa: E402
import rigify_build, bind_mesh, rig_check, stress_poses   # noqa: E402

CORPO = "N1_Corpo"
COLL = "N1_Scheletro"

# Quote del corpo (uguali a fase1_corpo_base.py), lato sinistro (+X)
SPALLA = Vector((0.200, 0.0, 1.370))
A_POSE = math.radians(45)
L_BRACCIO, L_AVAMBRACCIO = 0.270, 0.250
PIEGA_GOMITO = 0.012          # gomito spostato indietro (+Y)
ANCA = Vector((0.090, 0.0, 0.895))
GINOCCHIO = Vector((0.104, -0.014, 0.480))   # leggermente in avanti rispetto alla fase 1
CAVIGLIA = Vector((0.112, 0.012, 0.085))
DITA = [("f_index", -0.031, 0.075), ("f_middle", -0.011, 0.085), ("f_ring", 0.010, 0.080), ("f_pinky", 0.029, 0.065)]


def specchia(v, s):
    return Vector((v.x * s, v.y, v.z))


def osso(eb, nome, testa, coda, rollio):
    """Posiziona un osso e ne orienta lo Z locale verso `rollio` (come nel metarig)."""
    b = eb[nome]
    b.head, b.tail = testa, coda
    b.align_roll(rollio)


def articolazioni(meta):
    bx.select_only([meta])
    bpy.ops.object.mode_set(mode="EDIT")
    eb = meta.data.edit_bones
    for nome in ("breast.L", "breast.R"):      # pettorali rigidi sotto la maglia: niente ossa
        if nome in eb:
            eb.remove(eb[nome])
    for s, lato in ((1, ".L"), (-1, ".R")):
        m = lambda v: specchia(v, s)           # noqa: E731
        rot = Matrix.Rotation(-A_POSE, 3, "Y")
        giu, fuori = rot @ Vector((0, 0, -1)), rot @ Vector((1, 0, 0))
        spalla = SPALLA
        gomito = spalla + giu * L_BRACCIO + Vector((0, PIEGA_GOMITO, 0))
        polso = spalla + giu * (L_BRACCIO + L_AVAMBRACCIO)
        avanti = Vector((0, -1, 0))
        osso(eb, "shoulder" + lato, m(Vector((0.020, -0.040, 1.400))), m(Vector((0.170, 0.0, 1.385))), Vector((0, 0, 1)))
        osso(eb, "upper_arm" + lato, m(spalla), m(gomito), avanti)
        osso(eb, "forearm" + lato, m(gomito), m(polso), avanti)
        osso(eb, "hand" + lato, m(polso), m(polso + giu * 0.050), avanti)
        # dita: stesse basi e punte della fase 1; Z verso il palmo
        palmo = m(-fuori)
        nocche = polso + giu * 0.095
        for i, (dito, dy, lung) in enumerate(DITA, start=1):
            base = nocche + Vector((0, dy, 0)) - giu * 0.008
            punta = base + giu * lung - fuori * 0.012
            osso(eb, f"palm.0{i}{lato}", m(polso + giu * 0.015 + Vector((0, dy * 0.6, 0))), m(base), palmo)
            p1, p2 = base + (punta - base) * 0.45, base + (punta - base) * 0.75
            osso(eb, f"{dito}.01{lato}", m(base), m(p1), palmo)
            osso(eb, f"{dito}.02{lato}", m(p1), m(p2), palmo)
            osso(eb, f"{dito}.03{lato}", m(p2), m(punta), palmo)
        # pollice: dal lato davanti del palmo, Z verso le altre dita (+Y)
        base = polso + giu * 0.030 + Vector((0, -0.032, 0)) - fuori * 0.006
        punta = base + giu * 0.050 + Vector((0, -0.030, 0)) - fuori * 0.010
        verso_dita = Vector((0, 1, 0))
        meta_p = base + (punta - base) * 0.5
        osso(eb, "thumb.01" + lato, m(polso + giu * 0.012 + Vector((0, -0.018, 0))), m(base), verso_dita)
        osso(eb, "thumb.02" + lato, m(base), m(meta_p), verso_dita)
        osso(eb, "thumb.03" + lato, m(meta_p), m(punta), verso_dita)
        # gamba e piede (punta ruotata di 8° verso l'esterno, come la fase 1)
        r8 = Matrix.Rotation(math.radians(8) * s, 3, "Z")
        cav = m(CAVIGLIA)
        dietro = Vector((0, 1, 0))
        osso(eb, "thigh" + lato, m(ANCA), m(GINOCCHIO), dietro)
        osso(eb, "shin" + lato, m(GINOCCHIO), cav, dietro)
        pianta = cav + r8 @ Vector((0, -0.120, -0.065))
        punta = cav + r8 @ Vector((0, -0.190, -0.065))
        osso(eb, "foot" + lato, cav, pianta, Vector((0, 0, -1)))
        osso(eb, "toe" + lato, pianta, punta, Vector((0, 0, 1)))
        osso(eb, "heel.02" + lato, Vector((cav.x - 0.03, 0.035, 0.0)), Vector((cav.x + 0.03, 0.035, 0.0)), Vector((0, 0, 1)))
    bpy.ops.object.mode_set(mode="OBJECT")


def sposta_in(ob, coll):
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    coll.objects.link(ob)


def pulisci():
    for nome in ("GAME_RIG_N1_Corpo", "RIG_N1_Corpo", "META_N1_Corpo"):
        ob = bpy.data.objects.get(nome)
        if ob:
            arm = ob.data
            bpy.data.objects.remove(ob)
            if arm and arm.users == 0:
                bpy.data.armatures.remove(arm)
    act = bpy.data.actions.get("QA_Stress")
    if act:
        bpy.data.actions.remove(act)
    corpo = bpy.data.objects[CORPO]
    mw = corpo.matrix_world.copy()
    corpo.parent = None
    corpo.matrix_world = mw
    for mod in [m for m in corpo.modifiers if m.type == "ARMATURE"]:
        corpo.modifiers.remove(mod)
    corpo.vertex_groups.clear()


def run():
    bx.object_mode()
    pulisci()
    asset = bpy.data.collections["Personaggio_N1"]
    coll = bpy.data.collections.get(COLL)
    if not coll:
        coll = bpy.data.collections.new(COLL)
        asset.children.link(coll)

    out = {}
    r = rigify_build.run(add="human", fit=CORPO, no_face=True)
    meta = bpy.data.objects[r["metarig"]]
    sposta_in(meta, coll)
    articolazioni(meta)

    r = rigify_build.run(metarig=meta.name, generate=True)
    rig = bpy.data.objects[r["rig"]]
    rig.name = rig.data.name = "RIG_N1_Corpo"
    sposta_in(rig, coll)
    out["rig"] = {"ossa": r["bones"], "deformanti": r["deform_bones"]}

    out["pesi"] = bind_mesh.run(armature=rig.name, meshes=[CORPO])["meshes"][CORPO]

    gs, n, spostate = rigify_build.game_skeleton(rig)
    sposta_in(gs, coll)
    out["gioco"] = {"nome": gs.name, "ossa": n + 1, "mesh": spostate}
    out["controllo"] = rig_check.run(armature=gs.name, meshes=[CORPO], profile="game")

    out["stress"] = stress_poses.run(armature=rig.name)

    # widget di Rigify fuori dalla vista; metarig nascosto
    def tutte(lc):
        yield lc
        for c in lc.children:
            yield from tutte(c)
    for lc in tutte(bpy.context.view_layer.layer_collection):
        if lc.collection.name.startswith("WGTS_"):
            lc.exclude = True
    meta.hide_set(True)
    bx.object_mode()
    for ob in bpy.context.scene.objects:
        ob.select_set(False)
    bpy.context.scene.frame_set(1)
    bpy.ops.wm.save_mainfile(compress=True)
    return {"ok": True, **out}


print("@@JSON@@" + json.dumps(run(), default=str))
