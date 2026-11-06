"""Fase 5 del Personaggio N.1: braccia robotiche e spallacci (skill blender-hardsurface-modeling).

Approccio mid-poly: pezzi a blocchi alla scala reale, smusso solo sugli spigoli vivi (Bevel per
angolo), acciaio chiaro e metallo scuro, niente texture. Ogni pezzo è costruito lungo l'osso che
lo muove (testa e coda lette da `GAME_RIG_N1_Corpo`) ed è rigido: tutti i suoi vertici vanno al
100% su quell'osso. Un oggetto per braccio (`N1_Braccio.L`/`.R`) e uno per spallaccio.

Pezzi (lato sinistro; il destro è lo specchio):
- spallaccio (osso shoulder): guscio esagonale bombato sopra la spalla, bullone centrale, due punte;
- flangia della spalla (shoulder): anello scuro attorno all'attacco del braccio, copre lo scalfo;
- giunto (upper_arm): sfera scura nella flangia;
- omero (upper_arm): due segmenti ottagonali e una fascia scura sopra il gomito;
- gomito (forearm): cerniera scura con l'asse verso l'esterno, calotta d'acciaio dietro;
- avambraccio (forearm): prisma ottagonale rastremato, fila di bulloni esagonali sul lato esterno;
- polsino (forearm): anello scuro al polso;
- mano (hand): palmo, vite a croce sul dorso, borchie sulle nocche;
- dita e pollice: un blocco per falange, ognuno sul suo osso.
Le braccia del corpo si nascondono (Mask `Hidden_N1_Braccia`, dall'attributo `N1_braccio`).

Va lanciato dopo fase4_vestiti.py (che rifà le maschere del corpo):
    python -B .claude/skills/blender-core/scripts/run_in_blender.py --blend blender/personaggi/personaggio_n1.blend blender/personaggi/script/fase5_braccia.py
"""
import bpy, bmesh, json, math, os, sys
from mathutils import Vector, Matrix

PROGETTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
for skill in ("blender-clothing", "blender-retopology-uv"):
    sys.path.insert(0, os.path.join(PROGETTO, ".claude", "skills", skill, "scripts"))
import _bpyx as bx      # noqa: E402
import garment          # noqa: E402
import uv_pack          # noqa: E402

COLL = "N1_Braccia"
RIG = "GAME_RIG_N1_Corpo"
CORPO = "N1_Corpo"
ACCIAIO, SCURO = 0, 1             # indici dei materiali
SMUSSO = (0.0015, math.radians(50))   # larghezza (m) e angolo minimo: smussa i fondi e i bulloni, non i lati a 45° degli ottagoni
DITA = ("f_index", "f_middle", "f_ring", "f_pinky")
SU = Vector((0, 0, 1))


# ---------------------------------------------------------------- forme

class Pezzi:
    """bmesh unico con, per ogni osso, l'elenco dei vertici creati (pesi rigidi)."""

    def __init__(self):
        self.bm = bmesh.new()
        self.gruppi = {}
        self.da_smussare = set()      # facce dei pezzi grandi: solo i loro spigoli prendono lo smusso
        self._v = self._f = 0

    def inizio(self):
        self._v, self._f = len(self.bm.verts), len(self.bm.faces)

    def fine(self, osso, materiale, smussa=True):
        """I vertici e le facce aggiunti dopo inizio() vanno all'osso e al materiale dati.
        smussa=False per i pezzi piccoli (bulloni, borchie, dita, punte): lì lo smusso collassa."""
        self.bm.faces.ensure_lookup_table()
        for i in range(self._f, len(self.bm.faces)):
            self.bm.faces[i].material_index = materiale
        if smussa:
            self.da_smussare.update(range(self._f, len(self.bm.faces)))
        self.gruppi.setdefault(osso, []).extend(range(self._v, len(self.bm.verts)))


def assi(z, x_hint):
    """Base ortonormale con Z lungo `z` e X il più vicino possibile a `x_hint`."""
    z = z.normalized()
    x = (x_hint - z * x_hint.dot(z))
    if x.length < 1e-6:
        x = z.orthogonal()
    x.normalize()
    return x, z.cross(x), z


def matrice(pos, z, x_hint):
    x, y, z = assi(z, x_hint)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = pos
    return m


def prisma(bm, p0, p1, o, f, tabella, lati=8, fase=math.pi / 8):
    """Prisma chiuso da p0 a p1; tabella (t, raggio lungo o, raggio lungo f) con t in 0..1.
    o e f si rendono perpendicolari all'asse, così la sezione è sempre dritta sull'osso."""
    d = p1 - p0
    a = d.normalized()
    o = (o - a * o.dot(a)).normalized()
    f = (f - a * f.dot(a) - o * f.dot(o)).normalized()
    anelli = []
    for t, ro, rf in tabella:
        c = p0 + d * t
        anelli.append([bm.verts.new(c + o * (ro * math.cos(fase + 2 * math.pi * i / lati)) +
                                    f * (rf * math.sin(fase + 2 * math.pi * i / lati))) for i in range(lati)])
    for r0, r1 in zip(anelli, anelli[1:]):
        for i in range(lati):
            bm.faces.new((r0[i], r0[(i + 1) % lati], r1[(i + 1) % lati], r1[i]))
    bm.faces.new(list(reversed(anelli[0])))
    bm.faces.new(anelli[-1])


def cilindro(bm, base, asse, raggio, altezza, lati=8, x_hint=Vector((1, 0, 0)), r2=None):
    """Cilindro (o cono, con r2) che parte da `base` lungo `asse`."""
    m = matrice(base + asse.normalized() * (altezza / 2), asse, x_hint)
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=True, segments=lati, radius1=raggio,
                          radius2=raggio if r2 is None else r2, depth=altezza, matrix=m)


def sfera(bm, c, r, segmenti=8, anelli=6):
    bmesh.ops.create_uvsphere(bm, u_segments=segmenti, v_segments=anelli, radius=r, matrix=Matrix.Translation(c))


def scatola(bm, centro, asse_y, x_hint, mezzi):
    """Parallelepipedo con il lato lungo (y) lungo `asse_y`; mezzi = semidimensioni (x, y, z)."""
    y = asse_y.normalized()
    x = (x_hint - y * x_hint.dot(y)).normalized()
    z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = centro
    bmesh.ops.create_cube(bm, size=2.0, matrix=m @ Matrix.Diagonal((*mezzi, 1.0)))


def croce(bm, base, normale, verso, braccio, mezza, altezza):
    """Croce della vite in un pezzo solo (due barre sovrapposte farebbero z-fighting), ruotata di 45°."""
    _x, _y, n = assi(normale, verso)
    u = (verso - n * verso.dot(n)).normalized()
    v = n.cross(u)
    u, v = (u + v).normalized(), (v - u).normalized()
    contorno = [(mezza, braccio), (mezza, mezza), (braccio, mezza), (braccio, -mezza), (mezza, -mezza), (mezza, -braccio),
                (-mezza, -braccio), (-mezza, -mezza), (-braccio, -mezza), (-braccio, mezza), (-mezza, mezza), (-mezza, braccio)]
    giu = [bm.verts.new(base + u * x + v * y) for x, y in contorno]
    su = [bm.verts.new(base + u * x + v * y + n * altezza) for x, y in contorno]
    bm.faces.new(list(reversed(giu)))
    bm.faces.new(su)
    for i in range(len(contorno)):
        j = (i + 1) % len(contorno)
        bm.faces.new((giu[i], giu[j], su[j], su[i]))


def cupola_esagonale(bm, c, raggio, asse, verso_u, ampiezza, anelli=3, spessore=0.010):
    """Guscio esagonale su una sfera (centro c, raggio): superficie esterna, interna e bordo."""
    u = (verso_u - asse * verso_u.dot(asse)).normalized()
    v = asse.cross(u)

    def punto(x, y, r):
        rho = math.hypot(x, y)
        teta = ampiezza * rho / anelli
        d = asse * math.cos(teta) + ((u * x + v * y) / rho if rho > 1e-9 else Vector()) * math.sin(teta)
        return c + d * r

    angoli = [math.radians(30 + 60 * j) for j in range(6)]
    spigoli = [(math.cos(a), math.sin(a)) for a in angoli]
    piani = []                       # coordinate 2D per anello
    for k in range(anelli + 1):
        if k == 0:
            piani.append([(0.0, 0.0)])
            continue
        anello = []
        for j in range(6):
            a, b = spigoli[j], spigoli[(j + 1) % 6]
            for i in range(k):
                t = i / k
                anello.append(((a[0] * (1 - t) + b[0] * t) * k, (a[1] * (1 - t) + b[1] * t) * k))
        piani.append(anello)
    fuori = [[bm.verts.new(punto(x, y, raggio)) for x, y in r] for r in piani]
    dentro = [[bm.verts.new(punto(x, y, raggio - spessore)) for x, y in r] for r in piani]

    def facce(strati, rovescia):
        for k in range(1, anelli + 1):
            rk, rp = strati[k], strati[k - 1]
            for j in range(6):
                for i in range(k):
                    a = rk[(j * k + i) % (6 * k)]
                    b = rk[(j * k + i + 1) % (6 * k)]
                    p = rp[(j * (k - 1) + i) % len(rp)] if k > 1 else rp[0]
                    tri = (a, b, p)
                    bm.faces.new(tri[::-1] if rovescia else tri)
                    if i < k - 1:
                        p2 = rp[(j * (k - 1) + i + 1) % len(rp)]
                        tri = (b, p2, p)
                        bm.faces.new(tri[::-1] if rovescia else tri)
    facce(fuori, False)
    facce(dentro, True)
    bo, bi = fuori[-1], dentro[-1]
    for i in range(len(bo)):
        j = (i + 1) % len(bo)
        bm.faces.new((bo[j], bo[i], bi[i], bi[j]))
    return punto


# ---------------------------------------------------------------- braccio

def ossa(rig, lato):
    """Testa e coda (posa di riposo) delle ossa di braccio e mano, per nome senza lato."""
    nomi = ["shoulder", "upper_arm", "forearm", "hand"] + [f"palm.0{i}" for i in (1, 2, 3, 4)]
    nomi += [f"{d}.0{i}" for d in list(DITA) + ["thumb"] for i in (1, 2, 3)]
    b = rig.data.bones
    return {n: (b[n + lato].head_local.copy(), b[n + lato].tail_local.copy()) for n in nomi}


def interp(tabella, t):
    if t <= tabella[0][0]:
        return tabella[0][1:]
    for r0, r1 in zip(tabella, tabella[1:]):
        if t <= r1[0]:
            k = (t - r0[0]) / (r1[0] - r0[0])
            return tuple(x + (y - x) * k for x, y in zip(r0[1:], r1[1:]))
    return tabella[-1][1:]


def braccio(rig, s):
    lato = ".L" if s == 1 else ".R"
    B = ossa(rig, lato)
    P = Pezzi()
    bm = P.bm
    avanti = Vector((0, -1, 0))
    spalla = B["upper_arm"][0]
    gomito = B["forearm"][0]
    polso = B["hand"][0]
    a_br = (rig.data.bones[f"upper_arm{lato}.001"].tail_local - spalla).normalized()
    a_av = (polso - gomito).normalized()

    def fuori_di(a):
        """Lato esterno (dorso del braccio): perpendicolare all'asse e al davanti, in su e in fuori."""
        return (avanti.cross(a) * s).normalized()

    def davanti_di(a):
        return (avanti - a * avanti.dot(a)).normalized()

    o_br, o_av = fuori_di(a_br), fuori_di(a_av)
    f_br, f_av = davanti_di(a_br), davanti_di(a_av)

    # flangia della spalla: anello scuro attorno all'attacco del braccio (resta con la clavicola)
    P.inizio()
    prisma(bm, spalla - a_br * 0.045, spalla - a_br * 0.005, o_br, f_br,
           [(0.0, 0.080, 0.084), (1.0, 0.086, 0.090)], lati=12, fase=0)
    P.fine("shoulder" + lato, SCURO)

    # giunto: sfera scura
    P.inizio()
    sfera(bm, spalla + a_br * 0.012, 0.064, segmenti=10, anelli=6)
    P.fine("upper_arm" + lato, SCURO)

    # omero: due segmenti ottagonali e una fascia scura sopra il gomito
    P.inizio()
    prisma(bm, spalla + a_br * 0.050, spalla + a_br * 0.140, o_br, f_br,
           [(0.0, 0.060, 0.064), (0.85, 0.066, 0.070), (1.0, 0.064, 0.068)])
    prisma(bm, spalla + a_br * 0.148, spalla + a_br * 0.228, o_br, f_br,
           [(0.0, 0.062, 0.066), (1.0, 0.055, 0.058)])
    P.fine("upper_arm" + lato, ACCIAIO)
    P.inizio()
    prisma(bm, spalla + a_br * 0.226, spalla + a_br * 0.246, o_br, f_br,
           [(0.0, 0.059, 0.062), (1.0, 0.059, 0.062)])
    P.fine("upper_arm" + lato, SCURO)

    # gomito: cerniera scura con l'asse verso l'esterno, calotta d'acciaio dietro
    asse_g = a_av.cross(avanti).normalized()
    P.inizio()
    cilindro(bm, gomito - asse_g * 0.050, asse_g, 0.040, 0.100, lati=12, x_hint=a_av)   # tappi dentro la fascia: a 5,5 cm erano complanari con lei
    P.fine("forearm" + lato, SCURO)
    P.inizio()
    dietro = -f_av
    cilindro(bm, gomito + dietro * 0.030, dietro, 0.030, 0.022, lati=8, x_hint=a_av, r2=0.020)
    P.fine("forearm" + lato, ACCIAIO, smussa=False)

    # avambraccio: prisma rastremato, bulloni esagonali sul lato esterno
    P.inizio()
    prisma(bm, gomito + a_av * 0.035, polso - a_av * 0.020, o_av, f_av,
           [(0.0, 0.054, 0.058), (0.25, 0.060, 0.062), (1.0, 0.044, 0.042)])
    P.fine("forearm" + lato, ACCIAIO)
    P.inizio()
    lung = (polso - gomito).length
    lp = lung - 0.055                      # lunghezza del prisma dell'avambraccio
    for k in range(5):
        dd = 0.035 + lp * (0.18 + 0.15 * k)
        ro, _rf = interp([(0.0, 0.054, 0.058), (0.25, 0.060, 0.062), (1.0, 0.044, 0.042)], (dd - 0.035) / lp)
        base = gomito + a_av * dd + o_av * (ro * math.cos(math.pi / 8) - 0.002)   # appoggiato sulla faccia esterna
        cilindro(bm, base, o_av, 0.0085, 0.008, lati=6, x_hint=a_av)
    P.fine("forearm" + lato, SCURO, smussa=False)

    # polsino: anello scuro
    P.inizio()
    prisma(bm, polso - a_av * 0.026, polso + a_av * 0.012, o_av, f_av,
           [(0.0, 0.050, 0.049), (1.0, 0.050, 0.049)])
    P.fine("forearm" + lato, SCURO)

    # mano: palmo, vite a croce sul dorso, borchie sulle nocche
    a_m = (B["palm.02"][1] - B["palm.02"][0]).normalized()
    o_m, f_m = fuori_di(a_m), davanti_di(a_m)
    nocche = (B["palm.02"][1] + B["palm.03"][1]) / 2
    centro_palmo = (polso + nocche) / 2 + o_m * 0.004
    P.inizio()
    prisma(bm, polso + a_m * 0.004, nocche + a_m * 0.004, o_m, f_m,
           [(0.0, 0.020, 0.040), (0.5, 0.022, 0.050), (1.0, 0.019, 0.050)], lati=8)
    P.fine("hand" + lato, ACCIAIO)
    P.inizio()
    dorso = centro_palmo + o_m * 0.020
    cilindro(bm, dorso, o_m, 0.016, 0.005, lati=8, x_hint=a_m)
    croce(bm, dorso + o_m * 0.0045, o_m, a_m, 0.012, 0.0018, 0.003)
    P.fine("hand" + lato, SCURO, smussa=False)
    P.inizio()
    for dito in DITA:
        base = B[f"{dito}.01"][0]
        cilindro(bm, base + o_m * 0.014 - a_m * 0.004, o_m, 0.0075, 0.008, lati=8, x_hint=a_m, r2=0.005)
    P.fine("hand" + lato, ACCIAIO, smussa=False)

    # dita: un blocco per falange, con un piccolo stacco tra l'una e l'altra
    for dito in list(DITA) + ["thumb"]:
        for i in (1, 2, 3):
            nome = f"{dito}.0{i}"
            h, t = B[nome]
            asse = t - h
            if dito == "thumb" and i == 1:
                continue                      # il primo osso del pollice è dentro il palmo
            larg = 0.0105 if dito != "thumb" else 0.012
            spess = 0.0095 if dito != "thumb" else 0.011
            if dito == "f_pinky":
                larg, spess = 0.009, 0.0085
            P.inizio()
            prisma(bm, h + asse.normalized() * 0.0015, t - asse.normalized() * 0.0015, o_m, f_m,
                   [(0.0, spess, larg), (1.0, spess * 0.9, larg * 0.92)], lati=6, fase=math.pi / 6)
            P.fine(nome + lato, ACCIAIO, smussa=False)
    return P


def spallaccio(rig, s):
    """Piastra esagonale larga circa 16 cm (come la bozza), poco bombata, sopra la spalla.
    Sta sull'osso del braccio: alzando il braccio si alza con lui, invece di farsi attraversare."""
    lato = ".L" if s == 1 else ".R"
    osso = "upper_arm" + lato
    spalla = rig.data.bones[osso].head_local
    P = Pezzi()
    bm = P.bm
    asse = Vector((s * 0.5, 0.0, 1.0)).normalized()
    raggio = 0.160                                   # sfera larga: piastra poco bombata
    cima = spalla + Vector((s * 0.035, 0.0, 0.085))  # sopra giunto e omero, con lo spazio per la pelliccia
    c = cima - asse * raggio
    P.inizio()
    punto = cupola_esagonale(bm, c, raggio, asse, Vector((0, -1, 0)), math.radians(30), anelli=3, spessore=0.012)
    P.fine(osso, ACCIAIO)
    # bullone centrale: base scura e testa esagonale
    P.inizio()
    cilindro(bm, cima - asse * 0.003, asse, 0.026, 0.011, lati=8)
    P.fine(osso, SCURO)
    P.inizio()
    cilindro(bm, cima + asse * 0.007, asse, 0.014, 0.009, lati=6)
    P.fine(osso, ACCIAIO, smussa=False)
    # punte: una verso l'alto (lato collo), una verso l'esterno
    P.inizio()
    for x, y in ((0.0, -2.0 * s), (0.0, 2.3 * s)):    # verso il collo e verso l'esterno (v cambia verso tra i lati)
        p = punto(x, y, raggio - 0.003)
        n = (p - c).normalized()
        cilindro(bm, p, n, 0.015, 0.055, lati=6, r2=0.0)
    P.fine(osso, SCURO, smussa=False)
    return P


def oggetto(nome, P, rig, coll, mats):
    bmesh.ops.recalc_face_normals(P.bm, faces=P.bm.faces)
    me = bpy.data.meshes.new(nome)
    P.bm.to_mesh(me)
    P.bm.free()
    ob = bpy.data.objects.new(nome, me)
    coll.objects.link(ob)
    for m in mats:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = False
    for osso, idx in P.gruppi.items():
        vg = ob.vertex_groups.get(osso) or ob.vertex_groups.new(name=osso)
        vg.add(idx, 1.0, "REPLACE")
    # smusso solo sugli spigoli vivi dei pezzi grandi (peso di smusso sugli spigoli, come dice la skill)
    peso = me.attributes.new("bevel_weight_edge", "FLOAT", "EDGE")
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    for e in bm.edges:
        fs = e.link_faces
        if len(fs) == 2 and all(f.index in P.da_smussare for f in fs) and e.calc_face_angle(0) > SMUSSO[1]:
            peso.data[e.index].value = 1.0
    bm.free()
    bev = ob.modifiers.new("Smusso", "BEVEL")
    bev.width, bev.segments = SMUSSO[0], 1
    bev.limit_method = "WEIGHT"
    bev.use_clamp_overlap = True
    am = ob.modifiers.new("Armature", "ARMATURE")
    am.object = rig
    ob.parent = rig
    ob.matrix_parent_inverse = rig.matrix_world.inverted()
    return ob


def run():
    bx.object_mode()
    sc = bpy.context.scene
    sc.frame_set(1)
    rig = bpy.data.objects[RIG]
    body = bpy.data.objects[CORPO]
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
    mats = [bpy.data.materials["M_N1_Acciaio"], bpy.data.materials["M_N1_MetalloScuro"]]

    obs = []
    for s, lato in ((1, ".L"), (-1, ".R")):
        obs.append(oggetto("N1_Braccio" + lato, braccio(rig, s), rig, coll, mats))
        obs.append(oggetto("N1_Spallaccio" + lato, spallaccio(rig, s), rig, coll, mats))
    uv_pack.run(objects=[o.name for o in obs], method="smart", angle=66.0, res=1024, margin_px=4)

    # braccia del corpo nascoste per intero, senza l'anello di margine: l'attacco sta sotto la flangia,
    # e quell'anello toccava il bordo dello scalfo della maglia
    braccio_attr = body.data.attributes["N1_braccio"].data
    verts = {i for i, x in enumerate(braccio_attr) if x.value > 0.5}
    out = {"corpo_nascosto": garment._hide_body(body, verts, "N1_Braccia", inset=0)[1]}

    # compenetrazione del corpo visibile nella maglia, ora che tutte le maschere ci sono
    maglia = bpy.data.objects["N1_Maglia"]
    pen = {}
    for f in (1, 10, 20, 30, 40, 50):
        sc.frame_set(f)
        r = garment.penetration(maglia, body, reach=0.03)   # 3 cm: con 10 cm i raggi attraversano l'ascella
        pen[f] = (r["poke_verts"], r["poke_max_m"])
    sc.frame_set(1)
    out["maglia_compenetrazione"] = pen

    out["triangoli"] = {o.name: bx.mesh_tris(o) for o in obs}
    out["triangoli_totale"] = sum(out["triangoli"].values())
    out["gruppi"] = {o.name: len(o.vertex_groups) for o in obs}
    for ob in sc.objects:
        ob.select_set(False)
    bpy.ops.wm.save_mainfile(compress=True)
    return {"ok": True, **out}


print("@@JSON@@" + json.dumps(run(), default=str))
