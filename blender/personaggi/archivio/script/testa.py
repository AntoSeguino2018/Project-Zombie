"""Testa del Personaggio N.1: ragazzo di 23 anni.

Metodo: forma liscia per sezioni con i tratti del viso scolpiti come rilievi morbidi,
ritopologia a quad (Quadriflow) con ombreggiatura morbida, e una texture generata
(pelle, ombra degli occhi, baffi e pizzetto alla Tony Stark, sfumatura dei lati).
Richiede lib_n1.py già caricata."""

C_TESTA = "Testa"

Z_MENTO, Z_BOCCA, Z_NASO, Z_OCCHI, Z_SOPRACC, Z_VERTICE = 1.468, 1.514, 1.540, 1.586, 1.604, 1.694

# (z, semilarghezza, davanti, dietro, esponente)
TESTA = [
    (1.462, 0.012, 0.010, 0.000, 2.0),
    (1.470, 0.030, 0.026, 0.010, 2.2),
    (1.482, 0.044, 0.058, 0.032, 2.4),
    (1.500, 0.056, 0.084, 0.060, 2.6),
    (1.520, 0.062, 0.090, 0.082, 2.6),
    (1.545, 0.066, 0.092, 0.094, 2.6),
    (1.575, 0.070, 0.092, 0.102, 2.6),
    (1.605, 0.074, 0.094, 0.106, 2.5),
    (1.635, 0.074, 0.090, 0.106, 2.4),
    (1.660, 0.068, 0.080, 0.098, 2.3),
    (1.680, 0.052, 0.060, 0.080, 2.2),
    (1.692, 0.026, 0.030, 0.042, 2.1),
    (1.697, 0.004, 0.004, 0.006, 2.0),
]
CY_TESTA = 0.004


def _anello_testa(z, n):
    w, df, db, p = interp_table(TESTA, z)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n - math.pi / 2
        c, s = math.cos(a), math.sin(a)
        x = w * math.copysign(abs(c) ** (2 / p), c)
        d = df if s < 0 else db
        # il viso è più piatto davanti, il cranio più tondo dietro
        pp = p + (0.5 if s < 0 else -0.3)
        y = d * math.copysign(abs(s) ** (2 / pp), s)
        pts.append(Vector((x, CY_TESTA + y, z)))
    return pts


NASO = [  # (z, altezza davanti alla faccia, mezza larghezza)
    (1.533, 0.000, 0.014),
    (1.538, 0.006, 0.0165),
    (1.544, 0.018, 0.0170),
    (1.551, 0.022, 0.0135),
    (1.560, 0.018, 0.0105),
    (1.575, 0.011, 0.0085),
    (1.590, 0.005, 0.0070),
    (1.600, 0.000, 0.0070),
]


def _tab(table, z, k):
    zs = np.array([r[0] for r in table])
    vs = np.array([r[k] for r in table])
    return np.interp(z, zs, vs, left=vs[0], right=vs[-1])


def _viso(co, nr):
    """Tratti del viso: restituisce lo spostamento in avanti (-Y) di ogni vertice."""
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    ax = np.abs(x)
    fr = ssmooth(-0.040, -0.075, y)
    d = np.zeros(len(co), np.float32)
    # naso dal profilo: dorso dritto, punta piccola, ali
    H = _tab(NASO, z, 1)
    W = _tab(NASO, z, 2)
    t = np.clip(1 - (ax / W) ** 2, 0, 1) ** 1.3
    d += H * t
    d += 0.004 * sbump(z, 1.541, 0.006) * sbump(ax, 0.0135, 0.006)
    # arcata sopraccigliare leggera e orbite poco profonde
    d += 0.004 * sbump(z, Z_SOPRACC, 0.011) * sbump(ax, 0.034, 0.030)
    eye = np.clip(1 - ((ax - 0.032) / 0.021) ** 2 - ((z - Z_OCCHI) / 0.013) ** 2, 0, 1)
    d -= 0.007 * eye ** 1.5
    # labbra piene, solco della bocca, filtro, piega sotto il labbro
    d += 0.0055 * sbump(z, Z_BOCCA + 0.0065, 0.0065) * sbump(x, 0, 0.024)
    d += 0.0065 * sbump(z, Z_BOCCA - 0.0075, 0.0070) * sbump(x, 0, 0.021)
    d -= 0.0030 * sbump(z, Z_BOCCA, 0.0020) * sbump(x, 0, 0.024)
    d += 0.0020 * sbump(z, Z_BOCCA + 0.016, 0.005) * sbump(ax, 0.005, 0.004)
    d -= 0.0040 * sbump(z, Z_BOCCA - 0.019, 0.005) * sbump(x, 0, 0.017)
    # mento squadrato
    d += 0.0075 * sbump(z, 1.480, 0.012) * np.clip(1 - (ax / 0.026) ** 4, 0, 1)
    d *= fr
    return d


def _volumi(co, nr):
    """Zigomi e mandibola: rilievi lungo la normale."""
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    ax = np.abs(x)
    d = np.zeros(len(co), np.float32)
    d += 0.005 * sbump(z, 1.568, 0.016) * sbump(ax, 0.054, 0.018) * ssmooth(0.0, -0.05, y)
    jaw_z = 1.490 + 0.32 * np.clip(ax - 0.038, 0, None)
    d += 0.0045 * sbump(z, jaw_z, 0.009) * ssmooth(0.028, 0.045, ax) * ssmooth(0.03, -0.02, y)
    d -= 0.003 * sbump(z, 1.535, 0.016) * sbump(ax, 0.050, 0.014) * ssmooth(-0.02, -0.06, y)
    return d


def build_testa(ratio=0.075):
    bm = bmesh.new()
    rings = []
    z = TESTA[0][0]
    while z <= TESTA[-1][0] + 1e-6:
        rings.append(_anello_testa(z, 128))
        z += 0.0022
    loft(bm, rings, cap0=True, cap1=True)
    ob = make("Testa", bm, ["Pelle"], coll(C_TESTA), smooth=True)
    sculpt_fn(ob, _volumi)
    co = np_co(ob)
    co[:, 1] -= _viso(co, None)
    ob.data.vertices.foreach_set("co", co.ravel())
    ob.data.update()
    decimate(ob, ratio)
    return ob


def build_orecchie():
    """Orecchie: conchiglia a C con l'elice, il lobo e la conca, un po' inclinate all'indietro."""
    bm = bmesh.new()
    for side in (1, -1):
        prof = [(-0.009, 1.604), (0.004, 1.612), (0.015, 1.607), (0.020, 1.592), (0.019, 1.573),
                (0.012, 1.556), (0.003, 1.549), (-0.005, 1.553), (-0.008, 1.568), (-0.010, 1.588)]
        cy, cz = 0.016, 1.581
        tilt = math.radians(14)

        def pt(y, z, x):
            dy, dz = y, z - cz
            yy = dy * math.cos(tilt) - dz * math.sin(tilt)
            zz = dy * math.sin(tilt) + dz * math.cos(tilt)
            return Vector((side * x, cy + yy, cz + zz))
        n = len(prof)
        root = [bm.verts.new(pt(y * 0.8, cz + (z - cz) * 0.8, 0.060)) for y, z in prof]
        rim = [bm.verts.new(pt(y, z, 0.083 - 0.10 * max(0.0, -y))) for y, z in prof]
        lip = [bm.verts.new(pt(y * 0.78 + 0.002, cz + (z - cz) * 0.80, 0.085)) for y, z in prof]
        conch = [bm.verts.new(pt(y * 0.40 + 0.002, cz + (z - cz) * 0.45 - 0.003, 0.074)) for y, z in prof]
        for A, B in ((root, rim), (rim, lip), (lip, conch)):
            for k in range(n):
                bm.faces.new((A[k], A[(k + 1) % n], B[(k + 1) % n], B[k]))
        bm.faces.new(conch)
        bm.faces.new(list(reversed(root)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = make("Orecchie", bm, ["Pelle"], coll(C_TESTA), smooth=True, sharp=60)
    m = ob.modifiers.new("Morbido", 'SUBSURF')
    m.levels = m.render_levels = 1
    return ob
