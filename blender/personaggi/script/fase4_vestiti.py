"""Fase 4 del Personaggio N.1: vestiti ricavati dal corpo (skill blender-clothing, `garment.py`).

Ogni capo nasce dalla zona del corpo che copre (gruppi di vertici `Zona_*` sul corpo), spinto
in fuori e con i pesi copiati dal corpo, così si muove con lo stesso scheletro. Poi:
- maglia attillata senza maniche (le braccia sono robotiche), scollo girocollo con il bordo
  riportato sulla linea dello scollo (il taglio sui quad del corpo sarebbe a dente di sega);
- cargo allargati a mano dopo la copia dei pesi: gamba larga circa 25 cm come nella bozza,
  pieghe, centro spostato verso l'esterno, raccolti in fondo dentro gli scarponi; tasche a toppa
  con patta e bottone, rigide sulla coscia;
- cintura e fibbia con la "C": anelli puliti attorno alla vita (non dai quad del corpo);
- scarponi dal piede, gambale ridisegnato, suola separata, puntale e tallone marroni, lacci.
Alla fine il corpo coperto si nasconde (modificatori Mask `Hidden_*`) e si misura la
compenetrazione del corpo in ogni posa di stress.

    python -B .claude/skills/blender-core/scripts/run_in_blender.py --blend blender/personaggi/personaggio_n1.blend blender/personaggi/script/fase4_vestiti.py
"""
import bpy, bmesh, json, math, os, sys
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

PROGETTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
sys.path.insert(0, os.path.join(PROGETTO, ".claude", "skills", "blender-clothing", "scripts"))
import _bpyx as bx    # noqa: E402
import garment        # noqa: E402

CORPO = "N1_Corpo"
COLL = "N1_Vestiti"
FOTOGRAMMI_STRESS = [1, 10, 20, 30, 40, 50]

# Quote del corpo (uguali a fase1_corpo_base.py / fase3_scheletro.py), lato sinistro
SPALLA = Vector((0.200, 0.0, 1.370))
A_POSE = math.radians(45)
ASSE_GAMBA = [(0.085, Vector((0.112, 0.012))), (0.480, Vector((0.104, -0.014))), (0.895, Vector((0.090, 0.0)))]

# Vestibilità (m): scarto dalla pelle e spessore
MAGLIA = (0.004, 0.002)
CARGO = (0.010, 0.003)
SCARPONI = (0.012, 0.004)
CINTURA_Z = (0.935, 0.995)
CINTURA_SCARTO, CINTURA_SPESSORE = 0.018, 0.021   # il lato interno entra di 3 mm nella pelle (lì il corpo è nascosto): lontano da maglia e cargo

# Cargo larghi: raggio attorno all'asse della gamba e spostamento del centro verso l'esterno
CARGO_RAGGIO = [(0.20, 0.058), (0.235, 0.064), (0.27, 0.095), (0.32, 0.118), (0.45, 0.122), (0.60, 0.118), (0.80, 0.112)]
CARGO_CENTRO = [(0.20, 0.0), (0.27, 0.015), (0.40, 0.030), (0.60, 0.028), (0.80, 0.020)]
LEVIGA_PESI_CARGO = 12      # passate di levigatura dei pesi del cargo
# Gambale degli scarponi
GAMBALE_RAGGIO = [(0.09, 0.060), (0.15, 0.062), (0.25, 0.070)]

COLORI = {  # provvisori, rifiniti nella fase dei colori
    "M_N1_Maglia": ((0.025, 0.025, 0.03), 0.0, 0.8),
    "M_N1_Cargo": ((0.045, 0.045, 0.045), 0.0, 0.9),
    "M_N1_Cuoio": ((0.22, 0.11, 0.05), 0.0, 0.6),
    "M_N1_Acciaio": ((0.75, 0.75, 0.78), 1.0, 0.35),
    "M_N1_MetalloScuro": ((0.12, 0.12, 0.13), 1.0, 0.45),
    "M_N1_ScarponeNero": ((0.035, 0.035, 0.035), 0.0, 0.7),
    "M_N1_ScarponeMarrone": ((0.28, 0.15, 0.07), 0.0, 0.7),
    "M_N1_Suola": ((0.16, 0.085, 0.04), 0.0, 0.9),
}


# ---------------------------------------------------------------- utilità

def interp(table, k):
    if k <= table[0][0]:
        return table[0][1]
    for (a, va), (b, vb) in zip(table, table[1:]):
        if k <= b:
            t = (k - a) / (b - a)
            return va + (vb - va) * t
    return table[-1][1]


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


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


def scollo(x, y):
    """Altezza dello scollo girocollo: basso davanti, alto dietro, alla base del collo.
    Stessa forma della versione precedente, 2 cm più in basso: su questo corpo saliva a collo alto."""
    fr = smooth(-0.02, -0.055, y)
    return 1.467 - 0.040 * fr * (1 - min(1.0, (x / 0.07) ** 2) * 0.45)


def e_braccio(co):
    s = 1 if co.x >= 0 else -1
    sp = Vector((SPALLA.x * s, SPALLA.y, SPALLA.z))
    giu = Vector((math.sin(A_POSE) * s, 0, -math.cos(A_POSE)))
    d = co - sp
    lungo = d.dot(giu)
    return lungo > -0.025 and (d - giu * lungo).length < 0.09


def asse_gamba(z, s):
    """Centro (x, y) dell'asse della gamba alla quota z."""
    pts = ASSE_GAMBA
    if z <= pts[0][0]:
        c = pts[0][1]
    elif z >= pts[-1][0]:
        c = pts[-1][1]
    else:
        for (a, ca), (b, cb) in zip(pts, pts[1:]):
            if z <= b:
                c = ca.lerp(cb, (z - a) / (b - a))
                break
    return Vector((c.x * s, c.y))


def segna_braccia(body):
    """Attributo `N1_braccio` (1 su braccia e mani): il Mask lo conserva, così la misura della
    compenetrazione può saltare le braccia del corpo, che saranno sostituite da quelle robotiche."""
    a = body.data.attributes.get("N1_braccio") or body.data.attributes.new("N1_braccio", "FLOAT", "POINT")
    a.data.foreach_set("value", [1.0 if e_braccio(v.co) or abs(v.co.x) > 0.26 else 0.0 for v in body.data.vertices])


def compenetrazione(g, body, tol=0.0005, reach=0.1):
    """Come garment.penetration (stessa regola), ma senza i vertici del corpo segnati come braccio."""
    dg = bpy.context.evaluated_depsgraph_get()
    ge, be = g.evaluated_get(dg), body.evaluated_get(dg)
    me = be.to_mesh()
    try:
        braccio = me.attributes["N1_braccio"].data
        ginv, bmw = g.matrix_world.inverted(), body.matrix_world
        gdir, nmat = ginv.to_3x3(), bmw.to_3x3().inverted().transposed()
        n_in, worst = 0, 0.0
        for v in me.vertices:
            if braccio[v.index].value > 0.5:
                continue
            p = ginv @ (bmw @ v.co)
            n = (gdir @ (nmat @ v.normal)).normalized()
            ho, lo, _a, _b = ge.ray_cast(p, n, distance=reach)
            hi, li, _a, _b = ge.ray_cast(p, -n, distance=reach)
            do = (lo - p).length if ho else None
            di = (li - p).length if hi else None
            if do is None and di is None:
                continue
            if di is not None and (do is None or di < do):
                n_in += 1
                worst = max(worst, di)
            elif do < tol:
                n_in += 1
        return n_in, round(worst, 4)
    finally:
        be.to_mesh_clear()


def gruppo(body, nome, verts):
    vg = body.vertex_groups.get(nome) or body.vertex_groups.new(name=nome)
    vg.remove(range(len(body.data.vertices)))
    vg.add(sorted(verts), 1.0, "REPLACE")
    return nome


def oggetto(nome, bm, coll):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)   # i pezzi specchiati (lato destro) nascono rovesciati
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nome, me)
    coll.objects.link(ob)
    return ob


def arma(ob, rig, body=None, osso=None):
    """Pesi (copiati dal corpo, oppure 100% su un osso) e Armature verso lo scheletro da gioco."""
    if osso:
        vg = ob.vertex_groups.new(name=osso)
        vg.add(range(len(ob.data.vertices)), 1.0, "REPLACE")
    else:
        garment._transfer_weights(ob, body, 4)
    am = ob.modifiers.new("Armature", "ARMATURE")
    am.object = rig
    ob.parent = rig
    ob.matrix_parent_inverse = rig.matrix_world.inverted()


def scatola(bm, centro, assi, mezzi):
    """Parallelepipedo orientato: assi = (u, v, n) normalizzati, mezzi = semidimensioni."""
    m = Matrix((assi[0], assi[1], assi[2])).transposed().to_4x4()
    m.translation = centro
    m = m @ Matrix.Diagonal((*mezzi, 1.0))
    bmesh.ops.create_cube(bm, size=2.0, matrix=m)


# ---------------------------------------------------------------- capi

def zone(body):
    me = body.data
    maglia, cargo, scarponi = set(), set(), set()
    for v in me.vertices:
        co = v.co
        ax = abs(co.x)
        if 0.955 <= co.z <= scollo(ax, co.y) and ax < 0.30 and not e_braccio(co):
            maglia.add(v.index)
        if 0.20 <= co.z <= 0.995 and ax < 0.26:
            cargo.add(v.index)
        if co.z <= 0.25:
            scarponi.add(v.index)
    return maglia, cargo, scarponi


def bordo_scollo(g, body_bvh, scarto):
    """Riporta il bordo del collo sulla linea dello scollo, appoggiato al corpo."""
    bm = bmesh.new()
    bm.from_mesh(g.data)
    n = 0
    for v in bm.verts:
        if v.is_boundary and v.co.z > 1.40 and abs(v.co.x) < 0.10:
            p = Vector((v.co.x, v.co.y, scollo(abs(v.co.x), v.co.y)))
            loc, nor, _i, _d = body_bvh.find_nearest(p)
            if loc is not None:
                v.co = loc + nor * scarto
                n += 1
    bm.to_mesh(g.data)
    bm.free()
    return n


def allarga_cargo(g):
    me = g.data
    for v in me.vertices:
        co = v.co
        if co.z > 0.90:
            continue
        w = 1.0 - smooth(0.78, 0.90, co.z)        # 1 sulle gambe, 0 sui fianchi
        if abs(co.x) < 1e-5:
            s = 1
        else:
            s = 1 if co.x > 0 else -1
        c = asse_gamba(co.z, s)
        rad = Vector((co.x, co.y)) - c
        if rad.length < 1e-6:
            continue
        d = rad.normalized()
        teta = math.atan2(d.y, d.x * s)
        r = interp(CARGO_RAGGIO, co.z) * (1 + 0.035 * math.sin(5 * teta + 14 * co.z))
        nuovo = c + Vector((interp(CARGO_CENTRO, co.z) * s, 0)) + d * r
        if abs(co.x) < 1e-5:
            nuovo.x = 0.0
        elif nuovo.x * s < 0.006:
            nuovo.x = 0.006 * s
        xy = Vector((co.x, co.y)).lerp(nuovo, w)
        co.x, co.y = xy.x, xy.y


def leviga_pesi(ob, ripeti, fattore=0.5, limite=4):
    """Passaggio più morbido tra le ossa: il cargo sta a 12 cm dalla gamba e, con il cambio netto
    coscia/stinco copiato dal corpo, al ginocchio piegato si gonfiava a palla.
    Ogni passata porta i pesi di un vertice a metà strada verso la media dei vicini; poi al massimo
    `limite` ossa per vertice e somma 1. (L'operatore vertex_group_smooth vuole la modalità pesi.)"""
    me = ob.data
    vicini = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        vicini[a].append(b)
        vicini[b].append(a)
    pesi = [{g.group: g.weight for g in v.groups} for v in me.vertices]
    for _ in range(ripeti):
        nuovi = []
        for i, w in enumerate(pesi):
            vv = vicini[i]
            if not vv:
                nuovi.append(w)
                continue
            media = {}
            for j in vv:
                for g, x in pesi[j].items():
                    media[g] = media.get(g, 0.0) + x / len(vv)
            chiavi = set(w) | set(media)
            nuovi.append({g: (1 - fattore) * w.get(g, 0.0) + fattore * media.get(g, 0.0) for g in chiavi})
        pesi = nuovi
    for vg in ob.vertex_groups:
        vg.remove(range(len(me.vertices)))
    gruppi = list(ob.vertex_groups)
    for i, w in enumerate(pesi):
        top = sorted(((x, g) for g, x in w.items() if x > 0.001), reverse=True)[:limite]
        tot = sum(x for x, _g in top) or 1.0
        for x, g in top:
            gruppi[g].add([i], x / tot, "REPLACE")
    return ripeti


def tasche(rig, coll, mat):
    bm_l = {1: bmesh.new(), -1: bmesh.new()}
    for s, bm in bm_l.items():
        z = 0.60
        c = asse_gamba(z, s)
        r = interp(CARGO_RAGGIO, z) * (1 + 0.035 * math.sin(14 * z)) + CARGO[1]   # stessa piega di allarga_cargo a teta 0
        base = Vector((c.x + interp(CARGO_CENTRO, z) * s + r * s, c.y, z))
        n = Vector((s, 0, 0))
        u, v = Vector((0, 1, 0)), Vector((0, 0, 1))
        scatola(bm, base, (u, v, n), (0.065, 0.065, 0.010))   # tasca: il retro entra di 1 cm, lontano dalle superfici del cargo
        scatola(bm, base + n * 0.013 + v * 0.072, (u, v, n), (0.070, 0.020, 0.008))      # patta
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=8, radius1=0.007, radius2=0.007, depth=0.006,
                              matrix=Matrix.Translation(base + n * 0.026 + v * 0.066) @ Matrix.Rotation(math.radians(90), 4, "Y"))
    obs = []
    for s, bm in bm_l.items():
        lato = ".L" if s == 1 else ".R"
        ob = oggetto("N1_Tasca" + lato, bm, coll)
        ob.data.materials.append(mat)
        arma(ob, rig, osso="thigh" + lato)
        obs.append(ob)
    return obs


def anello(bvh, z, scarto, n=64, cy=0.005):
    """Punti attorno al corpo alla quota z, a `scarto` dalla superficie (raggi orizzontali dal centro)."""
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n - math.pi / 2
        d = Vector((math.cos(a), math.sin(a), 0))
        o = Vector((0, cy, z))
        loc, _n, _i, _d = bvh.ray_cast(o + d * 0.5, -d, 0.5)
        pts.append((loc if loc is not None else o + d * 0.15) + d * scarto)
    return pts


def cintura(body, bvh, rig, coll):
    z0, z1 = CINTURA_Z
    est = [anello(bvh, z, CINTURA_SCARTO) for z in (z0, z1)]
    inn = [anello(bvh, z, CINTURA_SCARTO - CINTURA_SPESSORE) for z in (z0, z1)]
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in r] for r in (inn[0], est[0], est[1], inn[1])]
    n = len(vs[0])
    for k in range(4):
        r0, r1 = vs[k], vs[(k + 1) % 4]
        for i in range(n):
            bm.faces.new((r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = oggetto("N1_Cintura", bm, coll)
    ob.data.materials.append(materiale("M_N1_Cuoio"))
    arma(ob, rig, body=body)

    # fibbia d'acciaio con la "C" in rilievo scuro, davanti
    zc = (z0 + z1) / 2
    fronte = anello(bvh, zc, CINTURA_SCARTO, n=4)[0]        # primo punto: davanti (-Y)
    u, v, nn = Vector((1, 0, 0)), Vector((0, 0, 1)), Vector((0, -1, 0))
    bm = bmesh.new()
    scatola(bm, fronte + nn * 0.003, (u, v, nn), (0.036, 0.028, 0.004))
    piastra = len(bm.faces)
    # "C": barra curva a sezione quadrata, arco da 50° a 310°, apertura a destra di chi guarda
    # (u = +X è la destra vista da davanti); sporge 4 mm dalla piastra
    c0 = fronte + nn * 0.009
    anelli = []
    for i in range(15):
        a = math.radians(50 + 260 * i / 14)
        rad = u * math.cos(a) + v * math.sin(a)
        p = c0 + rad * 0.016
        anelli.append([bm.verts.new(p + rad * dr + nn * dn) for dr, dn in ((-0.003, -0.003), (0.003, -0.003), (0.003, 0.003), (-0.003, 0.003))])
    for r0, r1 in zip(anelli, anelli[1:]):
        for k in range(4):
            bm.faces.new((r0[k], r0[(k + 1) % 4], r1[(k + 1) % 4], r1[k]))
    bm.faces.new(list(reversed(anelli[0])))
    bm.faces.new(anelli[-1])
    fib = oggetto("N1_Fibbia", bm, coll)
    fib.data.materials.append(materiale("M_N1_Acciaio"))
    fib.data.materials.append(materiale("M_N1_MetalloScuro"))
    for i, p in enumerate(fib.data.polygons):
        p.material_index = 0 if i < piastra else 1
    arma(fib, rig, osso="spine")
    return [ob, fib]


def scarponi(body, verts, rig, coll):
    g = garment._shell(body, verts, "N1_Scarponi", SCARPONI[0])
    for c in list(g.users_collection):
        c.objects.unlink(g)
    coll.objects.link(g)
    garment._transfer_weights(g, body, 4)
    me = g.data
    # gambale: cerchio attorno all'asse della gamba; fondo piatto sopra la suola
    for v in me.vertices:
        co = v.co
        if co.z >= 0.09:
            s = 1 if co.x > 0 else -1
            c = asse_gamba(co.z, s)
            rad = Vector((co.x, co.y)) - c
            w = smooth(0.09, 0.13, co.z)
            nuovo = c + rad.normalized() * interp(GAMBALE_RAGGIO, co.z)
            xy = Vector((co.x, co.y)).lerp(nuovo, w)
            co.x, co.y = xy.x, xy.y
        if co.z < 0.025:
            co.z = 0.025
    # materiali: tomaia nera, puntale e contrafforte del tallone marroni
    me.materials.append(materiale("M_N1_ScarponeNero"))
    me.materials.append(materiale("M_N1_ScarponeMarrone"))
    for p in me.polygons:
        c = p.center
        s = 1 if c.x > 0 else -1
        locale = Matrix.Rotation(-math.radians(8) * s, 3, "Z") @ Vector((c.x - 0.112 * s, c.y - 0.012, 0))
        punta = locale.y < -0.105 and c.z < 0.085
        tallone = locale.y > 0.03 and c.z < 0.095
        p.material_index = 1 if (punta or tallone) else 0
    so = g.modifiers.new("Thickness", "SOLIDIFY")
    so.thickness, so.offset, so.use_even_offset = SCARPONI[1], 1.0, True
    am = g.modifiers.new("Armature", "ARMATURE")
    am.object = rig
    g.parent = rig
    g.matrix_parent_inverse = rig.matrix_world.inverted()

    # suola: le facce del fondo, allargate di 9 mm ed estruse fino a terra
    bm = bmesh.new()
    bm.from_mesh(me)
    giu = [f for f in bm.faces if all(v.co.z <= 0.0251 for v in f.verts)]
    resto = [f for f in bm.faces if f not in set(giu)]
    bmesh.ops.delete(bm, geom=resto, context="FACES")
    for isola in (1, -1):
        vs = [v for v in bm.verts if (v.co.x > 0) == (isola > 0)]
        if not vs:
            continue
        cen = sum((v.co for v in vs), Vector()) / len(vs)
        for v in vs:
            d = Vector((v.co.x - cen.x, v.co.y - cen.y, 0))
            if d.length > 1e-6:
                v.co += d.normalized() * 0.009
    sopra = list(bm.verts)
    ext = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z = 0.0
    for v in sopra:              # il lato di sopra entra nel fondo dello scarpone, lontano dalle facce appiattite della punta
        v.co.z = 0.034
    for f in bm.faces:
        f.material_index = 0
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    suola = oggetto("N1_Suole", bm, coll)
    suola.data.materials.append(materiale("M_N1_Suola"))
    arma(suola, rig, body=body)

    # lacci: quattro barrette sul davanti del gambale
    bm = bmesh.new()
    for s in (1, -1):
        for z in (0.115, 0.145, 0.175, 0.205):
            c = asse_gamba(z, s)
            r = interp(GAMBALE_RAGGIO, z) + SCARPONI[1]
            avanti = Vector((0, -1, 0))
            p = Vector((c.x, c.y, z)) + avanti * (r + 0.001)   # entra di 2 mm nel gambale
            scatola(bm, p, (Vector((1, 0, 0)), Vector((0, 0, 1)), avanti), (0.022, 0.004, 0.003))
    lacci = oggetto("N1_Lacci", bm, coll)
    lacci.data.materials.append(materiale("M_N1_Suola"))
    arma(lacci, rig, body=body)
    return [g, suola, lacci]


def capo(body, zona, nome, vestibilita, mat, rig, coll):
    r = garment.run(body=body.name, group=zona, name=nome, offset=vestibilita[0], thickness=vestibilita[1])
    g = bpy.data.objects[nome]
    for c in list(g.users_collection):
        c.objects.unlink(g)
    coll.objects.link(g)
    g.data.materials.clear()
    g.data.materials.append(mat)
    return g, r


# ---------------------------------------------------------------- costruzione

def pulisci(body):
    coll = bpy.data.collections.get(COLL)
    if coll:
        for ob in list(coll.objects):
            me = ob.data
            bpy.data.objects.remove(ob)
            if me and me.users == 0:
                bpy.data.meshes.remove(me)
    for m in [m for m in body.modifiers if m.type == "MASK"]:
        body.modifiers.remove(m)
    for vg in [vg for vg in body.vertex_groups if vg.name.startswith(("Zona_", "Hidden_"))]:
        body.vertex_groups.remove(vg)
    return coll


def run():
    bx.object_mode()
    sc = bpy.context.scene
    sc.frame_set(1)                                  # posa di riposo
    body = bpy.data.objects[CORPO]
    body.hide_render = False
    rig = bpy.data.objects["GAME_RIG_N1_Corpo"]
    coll = pulisci(body)
    segna_braccia(body)
    if not coll:
        coll = bpy.data.collections.new(COLL)
        bpy.data.collections["Personaggio_N1"].children.link(coll)

    maglia_v, cargo_v, scarponi_v = zone(body)
    gruppo(body, "Zona_Maglia", maglia_v)
    gruppo(body, "Zona_Cargo", cargo_v)
    gruppo(body, "Zona_Scarponi", scarponi_v)
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bvh = BVHTree.FromBMesh(bm)
    bm.free()

    out = {}
    maglia, r = capo(body, "Zona_Maglia", "N1_Maglia", MAGLIA, materiale("M_N1_Maglia"), rig, coll)
    out["maglia_bordo_scollo"] = bordo_scollo(maglia, bvh, MAGLIA[0])
    cargo, r = capo(body, "Zona_Cargo", "N1_Cargo", CARGO, materiale("M_N1_Cargo"), rig, coll)
    allarga_cargo(cargo)
    out["cargo_pesi_levigati"] = leviga_pesi(cargo, LEVIGA_PESI_CARGO)
    altri = tasche(rig, coll, materiale("M_N1_Cargo"))
    altri += cintura(body, bvh, rig, coll)
    altri += scarponi(body, scarponi_v, rig, coll)

    # corpo coperto nascosto (resta un anello di pelle sotto i bordi)
    for nome, vs in (("N1_Maglia", maglia_v), ("N1_Cargo", cargo_v), ("N1_Scarponi", scarponi_v)):
        garment._hide_body(body, vs, nome)

    # compenetrazione del corpo nelle pose di stress
    capi = [maglia, cargo, bpy.data.objects["N1_Scarponi"]]
    pen = {}
    for f in FOTOGRAMMI_STRESS:
        sc.frame_set(f)
        pen[f] = {g.name: (garment.penetration(g, body)["poke_verts"], compenetrazione(g, body)) for g in capi}
    sc.frame_set(1)
    # per capo: (vertici del corpo che bucano, contando le braccia; senza braccia: (vertici, profondità massima))
    out["compenetrazione"] = pen

    tutti = capi + altri
    for ob in tutti:
        for p in ob.data.polygons:
            p.use_smooth = False
    # UV ai pezzi costruiti a mano (le suole le ereditavano dagli scarponi, schiacciate)
    sys.path.insert(0, os.path.join(PROGETTO, ".claude", "skills", "blender-retopology-uv", "scripts"))
    import uv_pack
    for ob in altri:
        while ob.data.uv_layers:
            ob.data.uv_layers.remove(ob.data.uv_layers[0])
    uv_pack.run(objects=[ob.name for ob in altri], method="smart", angle=66.0, res=1024, margin_px=4)
    out["triangoli"] = {ob.name: bx.mesh_tris(ob) for ob in tutti}
    out["triangoli_totale"] = sum(out["triangoli"].values())
    for ob in sc.objects:
        ob.select_set(False)
    bpy.ops.wm.save_mainfile(compress=True)
    return {"ok": True, **out}


print("@@JSON@@" + json.dumps(run(), default=str))
