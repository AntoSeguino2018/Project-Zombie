"""Fase 7 del Personaggio N.1: capelli e pelliccia a ciocche solide sfaccettate (niente texture).

Capelli (`N1_Capelli`, rigidi sull'osso della testa): mullet moderno.
- cuoio capelluto colorato sulla mesh del corpo: castano dove crescono i capelli, sfumatura corta
  (ricrescita scura) sui lati e attorno alle orecchie, che restano scoperte;
- massa unica che segue la testa: folta sopra, sottile dove comincia la sfumatura sui lati, e dietro
  un blocco pieno e tondo che scende dalla nuca e si ferma sopra la base del collo;
- ciuffo in avanti: poche ciocche grosse che escono dalla parte alta davanti e spingono in avanti
  sopra la fronte, con la punta che si alza, senza coprire gli occhi;
- qualche ciocca corta pettinata indietro sopra e qualche punta corta sul bordo basso del blocco dietro.
Pelliccia (`N1_Pelliccia`), marrone scuro, un anello per lato sul busto, a separare busto e braccio:
- passa sopra il trapezio, scende davanti sul petto e dietro sulla schiena e si chiude sotto l'ascella;
- molto folta sopra (spessa, con molti ciuffi), poco sotto;
- resta medialmente rispetto alla spalla metallica e non la copre;
- si muove solo con le ossa del busto (colonna e clavicole), non con il braccio.
Seed fissi: il risultato è sempre lo stesso.

Va lanciato dopo fase6_viso.py (che rifà i materiali del corpo):
    python -B .claude/skills/blender-core/scripts/run_in_blender.py --blend blender/personaggi/personaggio_n1.blend blender/personaggi/script/fase7_capelli.py
"""
import bpy, bmesh, json, math, os, sys, random
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

PROGETTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
for skill in ("blender-clothing", "blender-retopology-uv"):
    sys.path.insert(0, os.path.join(PROGETTO, ".claude", "skills", skill, "scripts"))
import _bpyx as bx      # noqa: E402
import garment          # noqa: E402
import uv_pack          # noqa: E402

CORPO = "N1_Corpo"
RIG = "GAME_RIG_N1_Corpo"
COLL = "N1_Capelli"
OSSO_TESTA = "spine.006"
CENTRO_TESTA = Vector((0.0, 0.004, 1.585))
COLORI = {
    "M_N1_Capelli": ((0.045, 0.027, 0.017), 0.0, 0.7),    # castano scuro
    "M_N1_Rasato": ((0.17, 0.10, 0.066), 0.0, 0.8),       # sfumatura: tra la pelle e il castano
    "M_N1_Pelliccia": ((0.075, 0.042, 0.024), 0.0, 0.9),  # marrone scuro
}
SEED = 7

# Massa dei capelli: elevazione del bordo (gradi, dal centro della testa) per azimut
# (0 = davanti, 90 = lato, 180 = dietro): attaccatura sulla fronte, sopra la sfumatura ai lati,
# e dietro il blocco scende fino alla nuca.
BORDO_MASSA = [(0, 30.0), (45, 36.0), (80, 46.0), (110, 40.0), (135, 8.0), (160, -24.0), (180, -30.0)]   # dietro: sopra la base del collo
# Pelliccia: piano dell'anello (normale quasi laterale, inclinata verso l'alto) e suo centro (lato sinistro)
PELLICCIA_CENTRO = Vector((0.150, 0.0, 1.320))
PELLICCIA_NORMALE = Vector((0.982, 0.0, 0.187))
OSSA_BUSTO = ("spine.001", "spine.002", "spine.003", "shoulder")   # la pelliccia segue solo il busto (non collo né testa)


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


def interp(tab, k):
    if k <= tab[0][0]:
        return tab[0][1]
    for (a, va), (b, vb) in zip(tab, tab[1:]):
        if k <= b:
            return va + (vb - va) * (k - a) / (b - a)
    return tab[-1][1]


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------- superfici

def bvh_mesh(ob, valutato=False):
    if valutato:
        dg = bpy.context.evaluated_depsgraph_get()
        e = ob.evaluated_get(dg)
        me = e.to_mesh()
        b = BVHTree.FromPolygons([ob.matrix_world @ v.co for v in me.vertices], [p.vertices[:] for p in me.polygons])
        e.to_mesh_clear()
        return b
    me = ob.data
    return BVHTree.FromPolygons([ob.matrix_world @ v.co for v in me.vertices], [p.vertices[:] for p in me.polygons])


def da_fuori(bvhs, origine, verso, portata=0.6):
    """Primo punto (il più esterno) colpito arrivando da fuori: raggio da origine + verso*portata verso -verso."""
    o = origine + verso * portata
    meglio = None
    for b in bvhs:
        loc, nor, _i, d = b.ray_cast(o, -verso, portata * 1.5)
        if loc is not None and (meglio is None or d < meglio[2]):
            meglio = (loc, nor, d)
    return meglio


def fuori_da(bvh, p, margine):
    """Se p è dentro la superficie (o a meno di `margine`), lo porta fuori lungo la normale."""
    loc, nor, _i, d = bvh.find_nearest(p)
    if loc is None:
        return p
    if (p - loc).dot(nor) < margine:
        return loc + nor * margine
    return p


# ---------------------------------------------------------------- forme

def bezier(p0, p1, p2, n):
    return [p0 * (1 - t) ** 2 + p1 * 2 * (1 - t) * t + p2 * t * t for t in (i / n for i in range(n + 1))]


def ciuffo(bm, pts, larg, spess, su):
    """Ciocca solida a sezione di rombo lungo `pts`, che si stringe fino a una punta."""
    n = len(pts)
    anelli = []
    for i in range(n - 1):
        p = pts[i]
        t = (pts[i + 1] - pts[max(i - 1, 0)]).normalized()
        lato = t.cross(su)
        if lato.length < 1e-6:
            lato = t.orthogonal()
        lato.normalize()
        alto = lato.cross(t).normalized()
        k = 1.0 - 0.85 * (i / (n - 1)) ** 1.4
        anelli.append([bm.verts.new(p + lato * (larg / 2 * k)), bm.verts.new(p + alto * (spess / 2 * k)),
                       bm.verts.new(p - lato * (larg / 2 * k)), bm.verts.new(p - alto * (spess / 2 * k))])
    punta = bm.verts.new(pts[-1])
    for r0, r1 in zip(anelli, anelli[1:]):
        for j in range(4):
            bm.faces.new((r0[j], r0[(j + 1) % 4], r1[(j + 1) % 4], r1[j]))
    for j in range(4):
        bm.faces.new((anelli[-1][j], anelli[-1][(j + 1) % 4], punta))
    bm.faces.new(list(reversed(anelli[0])))


def direzione(phi, el):
    a, e = math.radians(phi), math.radians(el)
    return Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))


def massa(bm, bvh_testa, rng):
    """Massa unica dei capelli: superficie esterna bitorzoluta a spessore variabile, interna 2 mm sotto
    la pelle, bordo chiuso. Folta sopra e nel blocco dietro, sottile verso la sfumatura dei lati."""
    N_AZ, N_EL = 24, 6
    est, inn = [], []
    for k in range(N_EL + 1):
        r_e, r_i = [], []
        for i in range(N_AZ):
            phi = 360.0 * i / N_AZ
            dal_davanti = abs(((phi + 180) % 360) - 180)          # 0 davanti, 180 dietro
            el0 = interp(BORDO_MASSA, dal_davanti)
            el = el0 + (84 - el0) * (k / N_EL) ** 0.85
            hit = da_fuori([bvh_testa], CENTRO_TESTA, direzione(phi, el))
            loc, nor = hit[0], hit[1]
            sopra = smooth(0.0, 0.5, k / N_EL)                     # dal bordo verso l'alto
            dietro = smooth(110, 160, dal_davanti)                  # il blocco del mullet
            lati = 1.0 - dietro - (1 - smooth(20, 60, dal_davanti))  # dove la massa si assottiglia
            spessore = 0.006 + 0.020 * sopra + 0.016 * dietro - 0.004 * max(0.0, lati) * (1 - sopra)
            spessore *= 1.0 + 0.30 * rng.uniform(-1, 1)
            if k == 0 and dal_davanti < 100:
                spessore = 0.004                                    # attaccatura e sfumatura: bordo basso
            r_e.append(bm.verts.new(loc + nor * max(spessore, 0.004)))
            r_i.append(bm.verts.new(loc - nor * 0.002))
        est.append(r_e)
        inn.append(r_i)
    hit = da_fuori([bvh_testa], CENTRO_TESTA, Vector((0, 0, 1)))
    cima_e = bm.verts.new(hit[0] + hit[1] * 0.028)
    cima_i = bm.verts.new(hit[0] - hit[1] * 0.002)
    for strato, cima, rov in ((est, cima_e, False), (inn, cima_i, True)):
        for r0, r1 in zip(strato, strato[1:]):
            for i in range(N_AZ):
                f = (r0[i], r0[(i + 1) % N_AZ], r1[(i + 1) % N_AZ], r1[i])
                bm.faces.new(f[::-1] if rov else f)
        for i in range(N_AZ):
            f = (strato[-1][i], strato[-1][(i + 1) % N_AZ], cima)
            bm.faces.new(f[::-1] if rov else f)
    for i in range(N_AZ):
        j = (i + 1) % N_AZ
        bm.faces.new((est[0][j], est[0][i], inn[0][i], inn[0][j]))
    return est


def capelli(bvh_testa, rng):
    bm = bmesh.new()
    est = massa(bm, bvh_testa, rng)
    su = Vector((0, 0, 1))

    def sulla_massa(phi, el, alto):
        d = direzione(phi, el)
        hit = da_fuori([bvh_testa], CENTRO_TESTA, d)
        return hit[0] + hit[1] * alto, hit[1]

    # ciuffo in avanti: ciocche grosse dalla parte alta davanti, spinte in avanti sopra la fronte
    for k, (phi, el) in enumerate(((0, 62), (-14, 58), (14, 58), (-26, 52), (26, 52))):
        p0, n0 = sulla_massa(phi, el, 0.010 + 0.005 * k)   # basi a quote diverse: i tappi non coincidono
        x = p0.x
        # come nella foto: le ciocche davanti ricadono in avanti sulla fronte e la punta si rialza
        p1 = p0 + Vector((x * 0.25, -0.046, 0.004 - 0.003 * k))     # in avanti, appena su
        p2 = p1 + Vector((x * 0.30, -0.018, -0.024 - 0.004 * k))    # ricade sulla fronte
        pts = [fuori_da(bvh_testa, p, 0.010) for p in bezier(p0, p1, p2, 5)]
        if pts[-1].z < 1.625:                                       # la punta resta sopra l'arcata
            pts[-1].z = 1.625
        # ogni ciocca ruotata un po' sul suo asse: affiancate e parallele avrebbero lati coincidenti
        ciuffo(bm, pts, 0.054 - 0.004 * k, 0.022, Vector((math.sin(math.radians(9 * k - 18)), 0.0, 1.0)).normalized())
    # sopra spettinato a punte, come nella foto: ciocche corte che salgono e vanno in avanti o di lato
    for k in range(8):
        phi = rng.uniform(-70, 70) + (180 if k >= 6 else 0)
        p0, n0 = sulla_massa(phi, rng.uniform(55, 82), 0.016)
        verso = (n0 * 1.0 + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.8, 0.2), 0.2))).normalized()
        p1 = p0 + verso * 0.020
        p2 = p1 + (verso + Vector((rng.uniform(-0.3, 0.3), -0.3, 0.0))).normalized() * 0.018
        pts = [fuori_da(bvh_testa, p, 0.018) for p in bezier(p0, p1, p2, 3)]
        ciuffo(bm, pts, 0.030, 0.013, Vector((0, -1, 0)).cross(verso).normalized() if abs(verso.y) < 0.95 else n0)
    # punte corte sul bordo basso del blocco dietro
    for k, i in enumerate((10, 11, 12, 13, 14)):                # un punto del bordo ciascuna (azimut 150°–210°)
        base = est[0][i].co.copy()
        n = (base - CENTRO_TESTA)
        n.z = 0
        n.normalize()
        p0 = base + Vector((0, 0, 0.012)) - n * 0.004
        p2 = base + n * 0.016 + Vector((0, 0, -0.020 - 0.006 * (k % 2)))
        ciuffo(bm, bezier(p0, (p0 + p2) / 2 + n * 0.004, p2, 3), 0.040, 0.016, n)
    return bm


def pelliccia(bvh_busto, rng):
    """Un anello per lato sul busto: superficie appoggiata alla maglia, sezione a mezzo ellisse più alta
    e larga sopra il trapezio e sottile sotto l'ascella, più i ciuffi (molti sopra, pochi sotto)."""
    bm = bmesh.new()
    N_G, N_S = 24, 7         # 24 sezioni attorno all'anello: con la barba solida il totale stava sopra i 15.000
    for s in (1, -1):
        c = Vector((PELLICCIA_CENTRO.x * s, PELLICCIA_CENTRO.y, PELLICCIA_CENTRO.z))
        n_piano = Vector((PELLICCIA_NORMALE.x * s, 0.0, PELLICCIA_NORMALE.z))
        u = Vector((0, -1, 0))                                   # davanti
        v = n_piano.cross(u).normalized()
        if v.z < 0:
            v = -v                                               # in alto
        punti = []
        for i in range(N_G):
            psi = 2 * math.pi * i / N_G
            d = u * math.cos(psi) + v * math.sin(psi)
            hit = da_fuori(bvh_busto, c, d, portata=0.35)
            punti.append((hit[0], hit[1], math.sin(psi)))
        anelli = []
        for i, (p, nrm, alto) in enumerate(punti):
            t = (punti[(i + 1) % N_G][0] - punti[i - 1][0]).normalized()
            w = t.cross(nrm).normalized()
            folto = (0.5 + 0.5 * alto) ** 3.0                    # 1 sopra il trapezio, sottile già sul petto e sulla schiena
            H = (0.008 + 0.052 * folto) * (1 + 0.25 * rng.uniform(-1, 1))
            W = (0.012 + 0.034 * folto) * (1 + 0.15 * rng.uniform(-1, 1))
            sezione = []
            for j in range(N_S):
                a = math.pi * j / (N_S - 1)
                # base affondata di 1,4 cm: sotto maglia e pelle (lì il corpo è nascosto), lontana dalle loro facce
                sezione.append(bm.verts.new(p + w * (W * math.cos(a)) + nrm * (H * math.sin(a) - 0.014)))
            anelli.append(sezione)
            # ciuffi: molti sopra, pochi sotto
            if rng.random() < 0.15 + 0.85 * folto:
                for _ in range(1 + int(2 * folto)):
                    a = rng.uniform(0.2, math.pi - 0.2)
                    base = p + w * (W * 0.8 * math.cos(a)) + nrm * (H * 0.8 * math.sin(a))
                    fuori = (nrm * math.sin(a) + w * math.cos(a) + t * rng.uniform(-0.4, 0.4)).normalized()
                    lung = 0.020 + 0.030 * folto * rng.uniform(0.6, 1.0)
                    p2 = base + fuori * lung + Vector((0, 0, -0.008 * rng.random()))
                    ciuffo(bm, bezier(base - fuori * 0.004, (base + p2) / 2 + fuori * 0.004, p2, 3),
                           0.014 + 0.012 * folto, 0.009, nrm)
        for i in range(N_G):
            r0, r1 = anelli[i], anelli[(i + 1) % N_G]
            for j in range(N_S - 1):          # sotto resta aperta: è dentro il corpo, e chiusa coincideva con la maglia
                k = j + 1
                bm.faces.new((r0[j], r1[j], r1[k], r0[k]))
    return bm


def oggetto(nome, bm, coll, mat, rig, corpo=None, osso=None, solo=None):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nome, me)
    coll.objects.link(ob)
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = False
    if osso:
        vg = ob.vertex_groups.new(name=osso)
        vg.add(range(len(me.vertices)), 1.0, "REPLACE")
    else:
        garment._transfer_weights(ob, corpo, 4)
        if solo:
            tieni_solo(ob, solo)
    am = ob.modifiers.new("Armature", "ARMATURE")
    am.object = rig
    ob.parent = rig
    ob.matrix_parent_inverse = rig.matrix_world.inverted()
    return ob


def tieni_solo(ob, prefissi, riserva="spine.003"):
    """Toglie i pesi delle ossa che non iniziano con `prefissi` e rinormalizza (senza pesi: `riserva`)."""
    me = ob.data
    nomi = {g.index: g.name for g in ob.vertex_groups}
    pesi = [{nomi[g.group]: g.weight for g in v.groups if nomi[g.group].startswith(prefissi) and g.weight > 1e-4}
            for v in me.vertices]
    ob.vertex_groups.clear()
    gruppi = {}
    for i, w in enumerate(pesi):
        w = w or {riserva: 1.0}
        tot = sum(w.values())
        for nome, x in w.items():
            g = gruppi.get(nome) or ob.vertex_groups.new(name=nome)
            gruppi[nome] = g
            g.add([i], x / tot, "REPLACE")


def cuoio_capelluto(corpo):
    """Castano dove crescono i capelli, sfumatura sui lati e attorno alle orecchie (materiali aggiunti al corpo)."""
    me = corpo.data
    for nome in ("M_N1_Capelli", "M_N1_Rasato"):
        if nome not in me.materials:
            me.materials.append(materiale(nome))
    i_cap = list(me.materials).index(bpy.data.materials["M_N1_Capelli"])
    i_ras = list(me.materials).index(bpy.data.materials["M_N1_Rasato"])
    conta = [0, 0]
    for p in me.polygons:
        x, y, z = abs(p.center.x), p.center.y, p.center.z
        if z < 1.50 or (y < -0.03 and z < 1.650):
            continue                                    # viso e collo
        dietro_centro = y > 0.03 and x < 0.055
        sopra = z > 1.655 - 0.03 * smooth(-0.02, 0.06, y)
        if sopra or (dietro_centro and z > 1.51):
            p.material_index = i_cap
            conta[0] += 1
        elif x > 0.035 and z > 1.53:
            p.material_index = i_ras
            conta[1] += 1
    return {"capelli": conta[0], "rasato": conta[1]}


def run():
    bx.object_mode()
    sc = bpy.context.scene
    sc.frame_set(1)
    corpo = bpy.data.objects[CORPO]
    rig = bpy.data.objects[RIG]
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

    out = {"cuoio_capelluto": cuoio_capelluto(corpo)}
    bvh_testa = bvh_mesh(corpo)
    bvh_maglia = bvh_mesh(bpy.data.objects["N1_Maglia"], valutato=True)
    rng = random.Random(SEED)
    cap = oggetto("N1_Capelli", capelli(bvh_testa, rng), coll, materiale("M_N1_Capelli"), rig, osso=OSSO_TESTA)
    pel = oggetto("N1_Pelliccia", pelliccia([bvh_maglia, bvh_testa], rng), coll, materiale("M_N1_Pelliccia"), rig,
                  corpo=corpo, solo=OSSA_BUSTO)
    uv_pack.run(objects=[cap.name, pel.name], method="smart", angle=66.0, res=1024, margin_px=4)
    out["triangoli"] = {o.name: bx.mesh_tris(o) for o in (cap, pel)}
    out["dimensioni"] = {o.name: [round(d, 3) for d in o.dimensions] for o in (cap, pel)}
    out["ossa_pelliccia"] = sorted(g.name for g in pel.vertex_groups)
    for o in sc.objects:
        o.select_set(False)
    bpy.ops.wm.save_mainfile(compress=True)
    return {"ok": True, **out}


print("@@JSON@@" + json.dumps(run(), default=str))
