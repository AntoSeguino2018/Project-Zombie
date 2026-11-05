"""Braccia robotiche del Personaggio N.1 (v2). Richiede lib_v2.py già caricata.

Spazio del braccio (braccio sinistro, lungo il fianco come nella bozza):
origine nel perno della spalla, braccio verso -Z, esterno +X, davanti -Y.
Gli angoli 'a' attorno al braccio partono da +X (esterno) e girano verso +Y (dietro):
a = 0 esterno, 90 dietro, 180 interno, 270 davanti.

Ogni braccio è un solo oggetto con un gruppo di vertici per ogni osso futuro
(pezzi rigidi: ogni vertice va al 100% su un osso).
"""

C_BRACCIA = "Braccia"
MAT_B = ["Acciaio", "AcciaioScuro", "Brunito"]
ST, DK, BK = 0, 1, 2

# quote lungo il braccio (spazio del braccio)
Z_GOMITO = -0.262
Z_POLSO = -0.515
Z_NOCCHE = -0.612


class Pezzi:
    """Raccoglie i vertici creati per ogni osso."""

    def __init__(self, bm):
        self.bm = bm
        self.groups = {}
        self._mark = None

    def start(self):
        self._mark = set(self.bm.verts)

    def end(self, group):
        new = [v for v in self.bm.verts if v not in self._mark]
        self.groups.setdefault(group, []).extend(new)
        self._mark = None


def P(r, a, z, sy=1.0):
    return Vector((r * math.cos(a), r * math.sin(a) * sy, z))


def shell(bm, zs, rfun, a0, a1, nseg, t, mi, sy=1.0):
    """Piastra curva: tratto di tubo da a0 a a1 (radianti), raggio esterno rfun(a, z), spessore t."""
    outer, inner = [], []
    for z in zs:
        o, i = [], []
        for k in range(nseg + 1):
            a = a0 + (a1 - a0) * k / nseg
            r = rfun(a, z)
            o.append(bm.verts.new(P(r, a, z, sy)))
            i.append(bm.verts.new(P(r - t, a, z, sy)))
        outer.append(o)
        inner.append(i)
    nz = len(zs)
    for j in range(nz - 1):
        for k in range(nseg):
            bm.faces.new((outer[j][k], outer[j][k + 1], outer[j + 1][k + 1], outer[j + 1][k])).material_index = mi
            bm.faces.new((inner[j][k], inner[j + 1][k], inner[j + 1][k + 1], inner[j][k + 1])).material_index = mi
    for j in range(nz - 1):
        for k in (0, nseg):
            f = bm.faces.new((outer[j][k], outer[j + 1][k], inner[j + 1][k], inner[j][k]))
            f.material_index = mi
    for j in (0, nz - 1):
        for k in range(nseg):
            f = bm.faces.new((outer[j][k], inner[j][k], inner[j][k + 1], outer[j][k + 1]))
            f.material_index = mi


def tube(bm, zs, rfun, n, mi, sy=1.0, a0=0.0, caps=True):
    rings = [[P(rfun(a0 + 2 * math.pi * k / n, z), a0 + 2 * math.pi * k / n, z, sy) for k in range(n)] for z in zs]
    loft(bm, rings, mi=mi, cap0=caps, cap1=caps)


def spike(bm, base, d, length, r):
    """Punta d'acciaio con il collare scuro."""
    d = Vector(d).normalized()
    base = Vector(base)
    cyl(bm, base - d * 0.006, base + d * 0.008, r * 1.35, r * 1.25, sides=6, mi=DK)
    cyl(bm, base + d * 0.008, base + d * length, r, 0.0012, sides=6, mi=ST)


# ---------------------------------------------------------------- spallaccio

def _sph(c, U, V, R, u, v, bulge=1.0):
    d = (c + U * u / R + V * v / R).normalized()
    return d * R * bulge


def build_spallaccio(bm, pz):
    """Piastra nera a scudo esagonale sulla spalla, con il bullone e tre punte (cima, davanti, dietro)."""
    pz.start()
    C = Vector((0.97, 0.0, 0.24)).normalized()     # verso esterno-alto
    U = Vector((0, -1, 0))                         # u: verso davanti
    V = C.cross(U).normalized()                    # v: verso l'alto sulla piastra
    if V.z < 0:
        V = -V
    R = 0.106
    # contorno esagonale con la punta in basso (u, v in metri sulla piastra)
    hexa = [(-0.058, 0.098), (0.058, 0.098), (0.094, 0.030), (0.070, -0.068), (0.0, -0.112), (-0.070, -0.068), (-0.094, 0.030)]
    hexa = [(-u * 1.28, v * 1.28) for u, v in hexa]              # verso del giro coerente
    outline = []
    sub = 4
    for i in range(len(hexa)):
        a, b = Vector(hexa[i]), Vector(hexa[(i + 1) % len(hexa)])
        for k in range(sub):
            outline.append(a.lerp(b, k / sub))
    scales = [1.0, 0.97, 0.72, 0.42, 0.0]
    T = 0.016
    top_rings, bot_rings = [], []
    for s in scales:
        tr, br = [], []
        pts = outline if s > 0 else [Vector((0, 0))]
        for q in pts:
            u, v = q.x * s, q.y * s
            lip = 1.0 + (0.035 if s == 1.0 else 0.0) * 0 + (0.012 if s == 0.97 else 0.0)
            dome_k = 1.0 + 0.10 * (1 - s) ** 1.5           # bombata al centro
            p = _sph(C, U, V, R, u, v, dome_k * lip)
            tr.append(bm.verts.new(p))
            br.append(bm.verts.new(_sph(C, U, V, R - T, u * 0.98, v * 0.98)))
        top_rings.append(tr)
        bot_rings.append(br)
    n = len(outline)
    for rings, flip in ((top_rings, False), (bot_rings, True)):
        for j in range(len(scales) - 2):
            A, B = rings[j], rings[j + 1]
            for k in range(n):
                f = (A[k], A[(k + 1) % n], B[(k + 1) % n], B[k])
                bm.faces.new(f[::-1] if flip else f).material_index = BK
        A, c = rings[-2], rings[-1][0]
        for k in range(n):
            f = (A[k], A[(k + 1) % n], c)
            bm.faces.new(f[::-1] if flip else f).material_index = BK
    # bordo: collega il contorno di sopra e di sotto
    A, B = top_rings[0], bot_rings[0]
    for k in range(n):
        bm.faces.new((B[k], B[(k + 1) % n], A[(k + 1) % n], A[k])).material_index = BK
    # bullone centrale: disco d'acciaio con il dado in mezzo
    cp = _sph(C, U, V, R, 0.0, 0.004, 1.10)
    nrm = cp.normalized()
    cyl(bm, cp - nrm * 0.004, cp + nrm * 0.008, 0.032, 0.030, sides=12, mi=ST)
    cyl(bm, cp + nrm * 0.008, cp + nrm * 0.011, 0.023, 0.021, sides=12, mi=DK)
    hexnut(bm, cp + nrm * 0.014, nrm, 0.014, 0.008, mi=ST)
    # tre punte: in cima, davanti e dietro
    top = _sph(C, U, V, R, 0.0, 0.108, 1.04)
    spike(bm, top, (top.normalized() * 0.30 + Vector((0, 0, 1))), 0.090, 0.0145)
    for side in (-1, 1):                             # -1 davanti (-Y), +1 dietro
        q = _sph(C, U, V, R, -side * 0.112, 0.042, 1.03)
        d = q.normalized() * 0.40 + Vector((0, side, 0.30))
        spike(bm, q, d, 0.072, 0.013)
    pz.end("spallaccio")


# ---------------------------------------------------------------- braccio

def r_omero(a, z):
    t = (z + 0.05) / (Z_GOMITO + 0.05)              # 0 in alto, 1 al gomito
    r = 0.060 - 0.010 * t
    r += 0.007 * bump(t, 0.40, 0.45) * max(0.0, -math.sin(a))      # bicipite davanti
    r += 0.006 * bump(t, 0.35, 0.50) * max(0.0, math.sin(a))       # tricipite dietro
    r += 0.004 * max(0.0, math.cos(a)) * bump(t, 0.2, 0.4)          # deltoide esterno
    return r


def r_avambraccio(a, z):
    t = (z - (Z_GOMITO - 0.025)) / (Z_POLSO - (Z_GOMITO - 0.025))    # 0 al gomito, 1 al polso
    r = 0.055 - 0.015 * smoothstep(0.0, 1.0, t)
    r += 0.008 * bump(t, 0.22, 0.35) * (0.6 + 0.4 * max(0.0, math.cos(a - 0.6)))   # massa muscolare in alto
    return r


def build_omero(bm, pz):
    pz.start()
    # spalla: sfera scura
    sphere(bm, (0, 0, -0.004), 0.064, mi=DK, segs=10, rings=7)
    pz.end("spalla")
    pz.start()
    zs = [-0.045, -0.07, -0.11, -0.15, -0.19, -0.215]
    tube(bm, [-0.03, -0.235], lambda a, z: 0.046, 10, DK)                         # anima scura
    g = math.radians(9)
    shell(bm, zs, r_omero, math.radians(270) - math.radians(90) + g, math.radians(270) + math.radians(90) - g, 8, 0.006, ST)
    shell(bm, zs, r_omero, g - math.radians(0), math.radians(180) - g, 8, 0.006, ST)
    # fascia in alto sotto lo spallaccio e fascia sopra il gomito
    tube(bm, [-0.034, -0.048], lambda a, z: 0.062, 12, DK)
    tube(bm, [-0.212, -0.232], lambda a, z: 0.053, 12, DK)
    pz.end("omero")


def build_gomito(bm, pz):
    pz.start()
    zc = Z_GOMITO
    # cerniera lungo X con i dischi d'acciaio ai lati e il bullone
    cyl(bm, (-0.050, 0, zc), (0.050, 0, zc), 0.032, 0.032, sides=10, mi=DK)
    for s in (-1, 1):
        cyl(bm, (s * 0.044, 0, zc), (s * 0.056, 0, zc), 0.036, 0.034, sides=10, mi=ST)
        hexnut(bm, (s * 0.0595, 0, zc), (s, 0, 0), 0.011, 0.006, mi=DK)
    pz.end("omero")                        # la cerniera segue il braccio
    pz.start()
    # gomitiera dietro, segue l'avambraccio
    shell(bm, [zc + 0.030, zc + 0.005, zc - 0.022, zc - 0.040],
          lambda a, z: 0.050 + 0.010 * bump(z, zc - 0.005, 0.04), math.radians(40), math.radians(140), 6, 0.006, ST)
    pz.end("avambraccio")


def build_avambraccio(bm, pz):
    pz.start()
    z0 = Z_GOMITO - 0.028
    zs = [z0, z0 - 0.035, z0 - 0.075, z0 - 0.12, z0 - 0.165, Z_POLSO + 0.022]
    tube(bm, [z0 + 0.01, Z_POLSO + 0.01], lambda a, z: 0.040 - 0.008 * (z0 - z) / (z0 - Z_POLSO), 10, DK)
    g = math.radians(6)
    # piastra esterna-dietro (con i bulloni) e piastra interna-davanti
    a_seam1, a_seam2 = math.radians(-55), math.radians(125)
    shell(bm, zs, r_avambraccio, a_seam1 + g, a_seam2 - g, 9, 0.006, ST, sy=0.92)
    shell(bm, zs, r_avambraccio, a_seam2 + g, a_seam1 + 2 * math.pi - g, 9, 0.006, ST, sy=0.92)
    # fila di bulloni esagonali lungo il lato esterno
    ab = math.radians(30)
    for k in range(5):
        z = z0 - 0.035 - 0.036 * k
        r = r_avambraccio(ab, z)
        p = P(r, ab, z, 0.92)
        nrm = Vector((math.cos(ab), math.sin(ab) * 0.92, 0)).normalized()
        hexnut(bm, p + nrm * 0.002, nrm, 0.0085, 0.006, mi=DK, spin=0.3)
    # polsino a costine verticali
    n = 24
    for zz in ((Z_POLSO + 0.020, Z_POLSO - 0.016),):
        rings = []
        for z in (zz[0], zz[0] - 0.004, zz[1] + 0.004, zz[1]):
            edge = z in zz
            rings.append([P((0.046 if k % 2 == 0 else 0.042) - (0.003 if edge else 0.0), 2 * math.pi * k / n, z, 0.92)
                          for k in range(n)])
        loft(bm, rings, mi=DK)
    pz.end("avambraccio")


# ---------------------------------------------------------------- mano

DITA = [  # (nome, y della radice, lunghezze falangi, larghezza)
    ("indice", -0.031, (0.036, 0.026, 0.022), 0.0195),
    ("medio", -0.010, (0.039, 0.029, 0.023), 0.0205),
    ("anulare", 0.011, (0.037, 0.027, 0.022), 0.0195),
    ("mignolo", 0.030, (0.030, 0.021, 0.019), 0.0175),
]


def phalanx(bm, p0, d, side, length, w, t, taper=0.88, tip=False):
    """Falange a blocco: da p0 lungo d. side = asse della cerniera (Y). w larghezza, t spessore."""
    d = Vector(d).normalized()
    side = Vector(side).normalized()
    up = d.cross(side).normalized()         # dorso
    p0 = Vector(p0)
    def ring(c, s, cut=0.0):
        return [c + side * (sx * w / 2 * s) + up * (sy * t / 2 * s) for sx, sy in
                ((-1, -1 + cut), (1, -1 + cut), (1, 1), (-1, 1))]
    r0 = ring(p0 + d * 0.003, 1.0)
    r1 = ring(p0 + d * (length - 0.004), taper)
    rings = [r0, r1]
    if tip:
        rings.append(ring(p0 + d * length, taper * 0.75, cut=0.6))
    loft(bm, rings, mi=ST)
    return p0 + d * length, up


def build_mano(bm, pz):
    """Mano: palmo con la piastra sul dorso, vite a croce, borchie sulle nocche, dita a falangi."""
    pz.start()
    zt, zb = Z_POLSO - 0.018, Z_NOCCHE
    # palmo: blocco rastremato (dorso verso +X, palmo verso -X, dita verso -Z, pollice davanti -Y)
    rings = []
    for z, w, t, x in ((zt, 0.074, 0.036, 0.0), (zt - 0.03, 0.084, 0.040, 0.001), (zb + 0.012, 0.088, 0.036, 0.0), (zb, 0.084, 0.030, -0.002)):
        rings.append([Vector((x + sx * t / 2, sy * w / 2, z)) for sx, sy in ((1, -1), (1, 1), (-1, 1), (-1, -1))])
    loft(bm, rings, mi=DK)
    # piastra del dorso d'acciaio, un po' bombata
    plate = []
    for z, w in ((zt - 0.004, 0.068), (zt - 0.03, 0.080), (zb + 0.010, 0.082)):
        plate.append([Vector((0.020 + 0.004 * (1 - abs(k - 2) / 2) + (0.002 if z == zt - 0.03 else 0), -w / 2 + w * k / 4, z)) for k in range(5)])
    vr = [[bm.verts.new(p) for p in row] for row in plate]
    back = [[bm.verts.new(p - Vector((0.006, 0, 0))) for p in row] for row in plate]
    for i in range(2):
        for k in range(4):
            bm.faces.new((vr[i][k], vr[i + 1][k], vr[i + 1][k + 1], vr[i][k + 1])).material_index = ST
            bm.faces.new((back[i][k], back[i][k + 1], back[i + 1][k + 1], back[i + 1][k])).material_index = ST
    ring_o = [vr[0][k] for k in range(5)] + [vr[1][4], vr[2][4]] + [vr[2][k] for k in range(3, -1, -1)] + [vr[1][0]]
    ring_b = [back[0][k] for k in range(5)] + [back[1][4], back[2][4]] + [back[2][k] for k in range(3, -1, -1)] + [back[1][0]]
    m = len(ring_o)
    for k in range(m):
        bm.faces.new((ring_o[k], ring_b[k], ring_b[(k + 1) % m], ring_o[(k + 1) % m])).material_index = ST
    # vite a croce al centro del dorso
    zc = (zt + zb) / 2 + 0.004
    cyl(bm, (0.024, 0, zc), (0.0285, 0, zc), 0.0145, 0.0135, sides=10, mi=DK)
    box(bm, (0.0287, 0, zc), (0.0016, 0.020, 0.0038), mi=ST)
    box(bm, (0.0287, 0, zc), (0.0016, 0.0038, 0.020), mi=ST)
    # pollice: metacarpo sul lato davanti del palmo, verso il basso e l'interno
    tb = Vector((-0.004, -0.040, zt - 0.022))
    td = Vector((-0.45, -0.35, -1.0)).normalized()
    cyl(bm, tb - td * 0.004, tb + td * 0.034, 0.0135, 0.012, sides=6, mi=DK)
    pz.end("mano")
    groups = {}
    # pollice: due falangi
    pz.start()
    sideax = Vector((0.6, -0.8, 0.0)).normalized()
    p = tb + td * 0.034
    d = (td + Vector((-0.25, 0.15, 0))).normalized()
    sphere(bm, p, 0.010, mi=DK, segs=6, rings=4)
    p, up = phalanx(bm, p, d, sideax, 0.030, 0.021, 0.019)
    pz.end("pollice_1")
    pz.start()
    d2 = (d + Vector((-0.30, 0.10, 0))).normalized()
    cyl(bm, p - sideax * 0.012, p + sideax * 0.012, 0.0085, 0.0085, sides=6, mi=DK)
    phalanx(bm, p, d2, sideax, 0.026, 0.019, 0.017, tip=True)
    pz.end("pollice_2")
    # quattro dita, appena piegate verso il palmo (-X)
    for name, y, lens, w in DITA:
        p = Vector((0.0, y, zb + 0.002))
        ang = 0.0
        for k, L in enumerate(lens):
            pz.start()
            ang += math.radians((12, 18, 14)[k])
            d = Vector((-math.sin(ang), 0, -math.cos(ang)))
            cyl(bm, p - Vector((0, w * 0.55, 0)), p + Vector((0, w * 0.55, 0)), 0.0088, 0.0088, sides=6, mi=DK)
            if k == 0:
                # borchia tonda sulla nocca
                dome(bm, (0.0175, y, zb + 0.004), 0.0095, (1, 0, 0), mi=ST, segs=8, rings=4)
            p, _ = phalanx(bm, p, d, (0, 1, 0), L, w, 0.018 - 0.0015 * k, tip=(k == 2))
            pz.end(f"{name}_{k + 1}")


# ---------------------------------------------------------------- assemblaggio

def arm_matrix(side):
    """Dallo spazio del braccio al mondo: A-pose a 45° e perno della spalla."""
    return Matrix.Translation(Vector((SPALLA.x * side, SPALLA.y, SPALLA.z))) @ Matrix.Rotation(-A_POSE * side, 4, 'Y')


def build_braccio(side=1):
    sfx = ".L" if side > 0 else ".R"
    bm = bmesh.new()
    pz = Pezzi(bm)
    build_spallaccio(bm, pz)
    build_omero(bm, pz)
    build_gomito(bm, pz)
    build_avambraccio(bm, pz)
    mark = set(bm.verts)
    build_mano(bm, pz)
    # mani più grosse, come nella bozza
    bmesh.ops.scale(bm, vec=(1.16, 1.16, 1.16), space=Matrix.Translation((0, 0, -Z_POLSO)),
                    verts=[v for v in bm.verts if v not in mark])
    # dallo spazio del braccio al mondo (il destro è lo specchio del sinistro)
    M = arm_matrix(1)
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    bm.verts.index_update()
    groups = {g: [v.index for v in vs if v.is_valid] for g, vs in pz.groups.items()}
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = make("Braccio" + sfx, bm, MAT_B, coll(C_BRACCIA), mirror=(side < 0), smooth=True, sharp=40)
    for g, ids in groups.items():
        vg = ob.vertex_groups.new(name=g + sfx)
        vg.add(ids, 1.0, 'REPLACE')
    return ob


def build_braccia():
    return [build_braccio(1), build_braccio(-1)]
