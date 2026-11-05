"""Busto e collo del Personaggio N.1: ragazzo di 23 anni, atletico, maglia nera attillata.

Metodo: forma liscia e fitta per sezioni (larghezza e profondità prese dalla bozza),
muscoli scolpiti come rilievi morbidi, poi riduzione a grandi faccette piatte.
Richiede lib_n1.py già caricata."""

C_CORPO = "Corpo"

# (z, semilarghezza, davanti (y<0), dietro (y>0), esponente della sezione)
SEZIONI = [
    (0.925, 0.150, 0.104, 0.104, 2.4),
    (1.000, 0.140, 0.098, 0.100, 2.4),
    (1.070, 0.136, 0.104, 0.099, 2.5),
    (1.150, 0.148, 0.111, 0.104, 2.6),
    (1.225, 0.160, 0.121, 0.110, 2.7),
    (1.300, 0.168, 0.118, 0.112, 2.8),
    (1.350, 0.170, 0.097, 0.101, 2.7),
    (1.390, 0.148, 0.077, 0.087, 2.5),
    (1.420, 0.108, 0.066, 0.075, 2.3),
    (1.448, 0.068, 0.058, 0.066, 2.1),
    (1.485, 0.057, 0.054, 0.060, 2.1),
    (1.545, 0.055, 0.052, 0.058, 2.1),
]


def _anello(z, n):
    w, df, db, p = interp_table(SEZIONI, z)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n - math.pi / 2           # i = 0 davanti al centro
        c, s = math.cos(a), math.sin(a)
        x = w * math.copysign(abs(c) ** (2 / p), c)
        d = df if s < 0 else db
        y = d * math.copysign(abs(s) ** (2 / p), s)
        pts.append(Vector((x, y, z)))
    return pts


def _muscoli(co, nr):
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    ax = np.abs(x)
    fr = ssmooth(-0.03, -0.08, y)          # davanti
    bk = ssmooth(0.03, 0.08, y)            # dietro
    d = np.zeros(len(co), np.float32)
    # pettorali: piastra con il bordo basso deciso che sale verso l'ascella
    low = 1.212 + 0.045 * ssmooth(0.03, 0.14, ax)
    pec = ssmooth(low - 0.005, low + 0.045, z) * (1 - ssmooth(1.31, 1.38, z)) * sbump(ax, 0.072, 0.10)
    d += 0.013 * pec * fr
    d -= 0.005 * sbump(x, 0, 0.016) * fr * ssmooth(1.19, 1.23, z) * (1 - ssmooth(1.33, 1.37, z))   # sterno
    # addominali: due colonne e tre file, appena accennati sotto la maglia
    col = sbump(ax, 0.034, 0.030) * fr
    for zc in (1.040, 1.090, 1.140):
        d += 0.0035 * col * sbump(z, zc, 0.026)
    d -= 0.003 * sbump(x, 0, 0.010) * fr * (1 - ssmooth(1.17, 1.20, z))
    # obliqui e dentato
    d += 0.004 * sbump(z, 1.05, 0.06) * ssmooth(0.10, 0.13, ax) * (1 - bk)
    # dorsali a V
    d += 0.010 * bk * sbump(ax, 0.110, 0.055) * sbump(z, 1.24, 0.11)
    # scapole
    d += 0.007 * bk * sbump(ax, 0.075, 0.045) * sbump(z, 1.295, 0.055)
    # trapezio dalla nuca a metà schiena e solco della colonna
    d += 0.007 * bk * (1 - ssmooth(0.0, 0.05 + 0.35 * np.clip(z - 1.25, 0, None), ax)) * sbump(z, 1.33, 0.12)
    d -= 0.005 * bk * sbump(x, 0, 0.012) * (1 - ssmooth(1.37, 1.42, z))
    d += 0.004 * bk * sbump(ax, 0.026, 0.018) * sbump(z, 1.08, 0.11)
    # trapezi che salgono al collo
    d += 0.008 * sbump(z, 1.418, 0.035) * sbump(ax, 0.085, 0.050)
    # collo: sternocleidomastoidei appena accennati, incavo dello sterno
    d += 0.003 * fr * sbump(z, 1.475, 0.030) * sbump(ax, 0.028, 0.018)
    d -= 0.005 * fr * sbump(z, 1.446, 0.012) * sbump(x, 0, 0.016)
    # clavicole
    d += 0.004 * fr * sbump(z, 1.398 - 0.12 * np.clip(ax - 0.03, 0, None), 0.009) * ssmooth(0.02, 0.04, ax) * (1 - ssmooth(0.12, 0.15, ax))
    return d


def neckline(x, y):
    """Altezza dello scollo girocollo: basso davanti, alto dietro."""
    fr = ssmooth(-0.02, -0.055, y)
    return 1.487 - 0.044 * fr * (1 - np.clip((x / 0.07) ** 2, 0, 1) * 0.45)


def build_busto(ratio=0.075):
    bm = bmesh.new()
    rings = []
    z = SEZIONI[0][0]
    while z <= SEZIONI[-1][0] + 1e-6:
        rings.append(_anello(z, 112))
        z += 0.004
    loft(bm, rings, cap0=True, cap1=False)
    ob = make("Busto", bm, ["Maglia", "Pelle"], coll(C_CORPO))
    sculpt_fn(ob, _muscoli)
    for p in ob.data.polygons:
        c = p.center
        p.material_index = 1 if c.z > float(neckline(c.x, c.y)) else 0
    decimate(ob, ratio)
    return ob
