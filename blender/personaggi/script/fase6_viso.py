"""Fase 6 del Personaggio N.1: viso (colori a zone sulla mesh del corpo) e collana con targhetta.

I rilievi del viso (arcata, incavo degli occhi, naso, zigomi, labbra, mento) sono nella sorgente
(`viso()` in fase1_corpo_base.py) e la testa della mesh di gioco è suddivisa una volta
(fase2_retopologia.py). Qui si colorano le facce della testa, in posa di riposo:
- pelle mediterranea su tutto il corpo;
- zona d'ombra al posto degli occhi, solo nelle orbite (con la radice del naso in mezzo
  non sembra una benda);
- linea scura della bocca;
- baffi collegati al pizzetto pieno sul mento, appena più scuri della pelle (quasi rasati).
Baffi e pizzetto hanno anche un guscio solido di pochi millimetri (`N1_Barba`, rigido sulla testa).
Poi la collana: catenina a sezione triangolare attorno alla base del collo, sulla pelle, che
scende a V sulla maglia fino alla targhetta d'acciaio sullo sterno (circa 1,35 m, inclinata di 12°).
Pesi della collana copiati dal corpo.

Va lanciato dopo fase5_braccia.py:
    python -B .claude/skills/blender-core/scripts/run_in_blender.py --blend blender/personaggi/personaggio_n1.blend blender/personaggi/script/fase6_viso.py
"""
import bpy, bmesh, json, math, os, sys
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

PROGETTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
for skill in ("blender-clothing", "blender-retopology-uv"):
    sys.path.insert(0, os.path.join(PROGETTO, ".claude", "skills", skill, "scripts"))
import _bpyx as bx      # noqa: E402
import garment          # noqa: E402
import uv_pack          # noqa: E402

CORPO = "N1_Corpo"
COLL = "N1_Accessori"
COLORI = {  # (colore lineare, metallo, ruvidità)
    "M_N1_Pelle": ((0.60, 0.36, 0.23), 0.0, 0.6),        # carnagione mediterranea
    "M_N1_Ombra": ((0.015, 0.012, 0.012), 0.0, 1.0),     # zona d'ombra al posto degli occhi
    "M_N1_Bocca": ((0.30, 0.13, 0.09), 0.0, 0.6),
    "M_N1_Barba": ((0.08, 0.04, 0.025), 0.0, 0.85),      # baffi, pizzetto e sopracciglia (definitivi in fase 8)
    "M_N1_Barbetta": ((0.33, 0.19, 0.12), 0.0, 0.8),     # barba corta lungo la mascella e sotto il mento
}
PELLE, OMBRA, BOCCA, BARBA, BARBETTA = 0, 1, 2, 3, 4
CATENA_R = 0.0028          # raggio della sezione triangolare
TARGHETTA = (0.012, 0.018, 0.0015)   # semidimensioni (larghezza, altezza, spessore)
TARGHETTA_Z = 1.350
TARGHETTA_INCLINAZIONE = math.radians(12)


def materiale(nome):
    m = bpy.data.materials.get(nome) or bpy.data.materials.new(nome)
    col, metal, rough = COLORI[nome]
    m.diffuse_color = (*col, 1.0)
    m.metallic, m.roughness = metal, rough
    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*col, 1.0)
        bsdf.inputs["Metallic"].default_value = metal
        bsdf.inputs["Roughness"].default_value = rough
    return m


def zona_viso(c):
    """Materiale di una faccia del corpo dal suo centro (posa di riposo). La mesh è simmetrica (fase 2),
    quindi le zone vengono uguali sui due lati. Sulle foto dello sviluppatore:
    - sopracciglia folte e scure subito sopra la fascia d'ombra degli occhi;
    - baffi pieni sul labbro superiore, fino agli angoli della bocca e appena sotto;
    - barba scura sul mento con la striscia sotto il labbro;
    - barba corta (più chiara) lungo la mascella fino alle orecchie e sotto il mento; guance pulite.
    Baffi, mento e sopracciglia hanno anche un guscio con spessore (`barba_solida`)."""
    x, y, z = abs(c.x), c.y, c.z
    # barba corta lungo la mascella e sotto il mento (anche di lato e sul collo, sotto la mandibola)
    if 1.452 <= z <= 1.505 and 0.034 < x <= 0.070 and y < 0.030:
        return BARBETTA
    if 1.425 <= z < 1.462 and x <= 0.060 and y < -0.010:
        return BARBETTA
    if y > -0.035 or z < 1.452 or z > 1.62 or x > 0.075:
        return PELLE
    if 1.600 < z <= 1.612 and 0.012 <= x <= 0.062 and y < -0.050:
        return BARBA                                            # sopracciglia
    if 1.573 <= z <= 1.600 and 0.014 <= x <= 0.064 and y < -0.045:
        return OMBRA
    if 1.509 <= z <= 1.516 and x <= 0.021 and y < -0.06:     # una riga di facce (5 mm): una linea, le labbra restano pelle
        return BOCCA
    davanti = y < -0.058
    baffi = 1.516 < z <= 1.538 and x <= 0.031 and davanti           # pieni, coprono il labbro superiore
    punte_baffi = 1.505 <= z <= 1.522 and 0.021 <= x <= 0.034 and davanti   # scendono agli angoli della bocca
    sotto_labbro = 1.490 <= z < 1.499 and x <= 0.012 and davanti
    mento = 1.452 <= z < 1.490 and x <= 0.034 and y < -0.040
    return BARBA if (baffi or punte_baffi or sotto_labbro or mento) else PELLE


def colora_viso(corpo):
    me = corpo.data
    me.materials.clear()
    for nome in ("M_N1_Pelle", "M_N1_Ombra", "M_N1_Bocca", "M_N1_Barba", "M_N1_Barbetta"):
        me.materials.append(materiale(nome))
    conta = [0, 0, 0, 0, 0]
    for p in me.polygons:
        p.material_index = zona_viso(p.center)
        conta[p.material_index] += 1
    return dict(zip(("pelle", "ombra", "bocca", "barba", "barbetta"), conta))


def scollo(x, y):
    """Uguale a fase4_vestiti.py: altezza dello scollo della maglia."""
    t = max(0.0, min(1.0, (y + 0.02) / (-0.055 + 0.02)))
    fr = t * t * (3 - 2 * t)
    return 1.467 - 0.040 * fr * (1 - min(1.0, (x / 0.07) ** 2) * 0.45)


class Superficie:
    """Pelle e maglia insieme: un raggio da fuori si ferma sulla prima che incontra (la più esterna)."""

    def __init__(self, *bvhs):
        self.bvhs = bvhs

    def tocca(self, o, verso):
        migliore = None
        for bvh in self.bvhs:
            loc, nor, _i, d = bvh.ray_cast(o, verso, 0.5)
            if loc is not None and (migliore is None or d < migliore[2]):
                migliore = (loc, nor, d)
        return migliore


def appoggia(sup, x, z, verso):
    """Punto sulla superficie più esterna alla quota z, raggiunto da fuori lungo `verso` (orizzontale),
    staccato di un raggio di catena più 1,2 mm lungo la normale."""
    hit = sup.tocca(Vector((x, 0.0, z)) - verso * 0.3, verso)
    if hit is None:
        return None
    return hit[0] + hit[1] * (CATENA_R + 0.0012)


def percorso(sup, s):
    """Mezza catenina (lato s): dal centro della nuca, attorno al collo, giù a V fino alla targhetta."""
    pts = []
    # attorno al collo: angolo da dietro (180°) a davanti-lato (40°), quota in leggera discesa
    for i in range(22):
        t = i / 21
        a = math.radians(180 - 140 * t)
        z = 1.476 - 0.026 * t * t
        d = Vector((math.sin(a) * s, -math.cos(a), 0.0))
        hit = sup.tocca(Vector((0, 0.005, z)) + d * 0.3, -d)
        if hit is not None:
            pts.append(hit[0] + hit[1] * (CATENA_R + 0.0012))
    # giù a V sullo sterno, fino all'anellino della targhetta
    a0 = pts[-1]
    cima = TARGHETTA_Z + TARGHETTA[1] + 0.006
    for i in range(1, 13):
        t = i / 12
        p = appoggia(sup, a0.x * (1 - t), a0.z + (cima - a0.z) * t, Vector((0, 1, 0)))
        if p is not None:
            pts.append(p)
    return pts


def leviga(pts, passate=2):
    """Toglie i piccoli scalini della polilinea (gli estremi restano fermi)."""
    for _ in range(passate):
        pts = [pts[0]] + [(pts[i - 1] + pts[i] * 2 + pts[i + 1]) / 4 for i in range(1, len(pts) - 1)] + [pts[-1]]
    return pts


def tubo(bm, pts, r, lati=3):
    """Tubo a sezione poligonale lungo una polilinea aperta, con i tappi."""
    anelli = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        u = t.orthogonal().normalized()
        v = t.cross(u)
        anelli.append([bm.verts.new(p + (u * math.cos(2 * math.pi * k / lati) + v * math.sin(2 * math.pi * k / lati)) * r)
                       for k in range(lati)])
    for r0, r1 in zip(anelli, anelli[1:]):
        for k in range(lati):
            bm.faces.new((r0[k], r0[(k + 1) % lati], r1[(k + 1) % lati], r1[k]))
    bm.faces.new(list(reversed(anelli[0])))
    bm.faces.new(anelli[-1])


def collana(corpo, rig, coll):
    me = corpo.data
    pelle = BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [p.vertices[:] for p in me.polygons])
    dg = bpy.context.evaluated_depsgraph_get()
    mg = bpy.data.objects["N1_Maglia"].evaluated_get(dg)
    mm = mg.to_mesh()
    maglia = BVHTree.FromPolygons([mg.matrix_world @ v.co for v in mm.vertices], [p.vertices[:] for p in mm.polygons])
    mg.to_mesh_clear()
    sup = Superficie(pelle, maglia)
    sx, dx = percorso(sup, 1), percorso(sup, -1)
    catena = leviga(list(reversed(dx)) + sx[1:])   # le due metà si uniscono al centro della nuca
    # la catena si chiude sull'anellino: i due capi davanti sono vicini, si lascia il tubo aperto lì
    bm = bmesh.new()
    tubo(bm, catena, CATENA_R, lati=3)
    # targhetta: rettangolo d'acciaio sullo sterno, inclinato come il petto, con l'anellino
    fronte = appoggia(sup, 0.0, TARGHETTA_Z, Vector((0, 1, 0)))
    n = Vector((0, -math.cos(TARGHETTA_INCLINAZIONE), math.sin(TARGHETTA_INCLINAZIONE)))
    su = Vector((0, math.sin(TARGHETTA_INCLINAZIONE), math.cos(TARGHETTA_INCLINAZIONE)))
    centro = fronte - n * CATENA_R + n * TARGHETTA[2]
    m = Matrix((Vector((1, 0, 0)), su, n)).transposed().to_4x4()
    m.translation = centro
    bmesh.ops.create_cube(bm, size=2.0, matrix=m @ Matrix.Diagonal((*TARGHETTA, 1.0)))
    anello_c = centro + su * (TARGHETTA[1] + 0.003)
    giro = [anello_c + (Vector((1, 0, 0)) * math.cos(2 * math.pi * k / 8) + su * math.sin(2 * math.pi * k / 8)) * 0.004
            for k in range(9)]
    tubo(bm, giro, 0.0012, lati=3)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me_c = bpy.data.meshes.new("N1_Collana")
    bm.to_mesh(me_c)
    bm.free()
    ob = bpy.data.objects.new("N1_Collana", me_c)
    coll.objects.link(ob)
    me_c.materials.append(bpy.data.materials["M_N1_Acciaio"])
    for p in me_c.polygons:
        p.use_smooth = False
    garment._transfer_weights(ob, corpo, 4)
    am = ob.modifiers.new("Armature", "ARMATURE")
    am.object = rig
    ob.parent = rig
    ob.matrix_parent_inverse = rig.matrix_world.inverted()
    return ob, len(catena)


def barba_solida(corpo, rig, coll):
    """Baffi e pizzetto con spessore: un guscio chiuso sulle facce colorate a barba, 3,5 mm sopra la
    pelle e con il lato interno 1 mm sotto (così il bordo non lascia fessure), rigido sulla testa."""
    me = corpo.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    via = [f for f in bm.faces if f.material_index != BARBA]
    bmesh.ops.delete(bm, geom=via, context="FACES")
    def spessore(co):
        if co.z > 1.595:
            return 0.0025      # sopracciglia
        if co.z > 1.505:
            return 0.0045      # baffi pieni
        return 0.0035          # pizzetto e striscia sotto il labbro
    fuori = {v: v.co + v.normal * spessore(v.co) for v in bm.verts}
    dentro = {v: v.co - v.normal * 0.0010 for v in bm.verts}
    out = bmesh.new()
    ve = {v: out.verts.new(fuori[v]) for v in bm.verts}
    vi = {v: out.verts.new(dentro[v]) for v in bm.verts}
    for f in bm.faces:
        out.faces.new([ve[v] for v in f.verts])
        out.faces.new([vi[v] for v in reversed(f.verts)])
    for e in bm.edges:
        if e.is_boundary:
            a, b2 = e.verts
            f = e.link_faces[0]
            # verso del lato nella faccia, per avere il bordo con le normali in fuori
            loop = next(l for l in f.loops if l.edge == e)
            a, b2 = loop.vert, loop.link_loop_next.vert
            out.faces.new((ve[b2], ve[a], vi[a], vi[b2]))
    bm.free()
    bmesh.ops.recalc_face_normals(out, faces=out.faces)
    m = bpy.data.meshes.new("N1_Barba")
    out.to_mesh(m)
    out.free()
    ob = bpy.data.objects.new("N1_Barba", m)
    coll.objects.link(ob)
    m.materials.append(materiale("M_N1_Barba"))
    for p in m.polygons:
        p.use_smooth = False
    vg = ob.vertex_groups.new(name="spine.006")
    vg.add(range(len(m.vertices)), 1.0, "REPLACE")
    am = ob.modifiers.new("Armature", "ARMATURE")
    am.object = rig
    ob.parent = rig
    ob.matrix_parent_inverse = rig.matrix_world.inverted()
    return ob


def run():
    bx.object_mode()
    sc = bpy.context.scene
    sc.frame_set(1)
    corpo = bpy.data.objects[CORPO]
    rig = bpy.data.objects["GAME_RIG_N1_Corpo"]
    coll = bpy.data.collections.get(COLL)
    if coll:
        for ob in list(coll.objects):
            me = ob.data
            bpy.data.objects.remove(ob)
            if me.users == 0:
                bpy.data.meshes.remove(me)
    else:
        coll = bpy.data.collections.new(COLL)
        bpy.data.collections["Personaggio_N1"].children.link(coll)

    out = {"facce_viso": colora_viso(corpo)}
    ob, n = collana(corpo, rig, coll)
    barba = barba_solida(corpo, rig, coll)
    uv_pack.run(objects=[ob.name, barba.name], method="smart", angle=66.0, res=512, margin_px=2)
    out["barba"] = {"triangoli": bx.mesh_tris(barba), "dimensioni": [round(d, 3) for d in barba.dimensions]}
    out["collana"] = {"punti": n, "triangoli": bx.mesh_tris(ob), "dimensioni": [round(d, 3) for d in ob.dimensions]}
    pen = {}
    for f in (1, 10, 20, 30, 40, 50):
        sc.frame_set(f)
        r = garment.penetration(bpy.data.objects["N1_Maglia"], corpo, reach=0.03)
        pen[f] = r["poke_verts"]
    sc.frame_set(1)
    out["maglia_compenetrazione"] = pen
    for o in sc.objects:
        o.select_set(False)
    bpy.ops.wm.save_mainfile(compress=True)
    return {"ok": True, **out}


print("@@JSON@@" + json.dumps(run(), default=str))
