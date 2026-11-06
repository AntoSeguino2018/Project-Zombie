"""Fase 1 del Personaggio N.1: corpo base nudo e stilizzato, testa compresa, in A-pose a 45°.

Metodo (skill blender-sculpting e blender-geometry-nodes): forme semplici a sezioni (tronco,
testa, arti, mani, piedi) fuse in una griglia SDF. Busto e braccia passano dal raccordo delle
giunture concave (SDF Grid Fillet: spalle e ascelle morbide); testa, gambe e mani si uniscono
dopo, senza raccordo, perché riempirebbe mandibola, interno delle cosce e spazio tra le dita.
Poi levigatura che conserva il volume (viso e mani protetti), muscoli come rilievi morbidi
lungo la normale e simmetria da +X. Il risultato è la sorgente fitta `N1_Corpo_alto`
(collezione `N1_Alto`), da cui la fase 2 ricava la mesh di gioco.

Si lancia senza finestra sul file della fase 0 (rifà solo la collezione N1_Alto):
    python -B .claude/skills/blender-core/scripts/run_in_blender.py --blend blender/personaggi/personaggio_n1.blend blender/personaggi/script/fase1_corpo_base.py
"""
import bpy, bmesh, json, math
from mathutils import Vector, Matrix

VOXEL = 0.004          # griglia SDF: 4 mm tiene separate le dita grosse e le orecchie
BANDA = 10             # spessore della banda SDF in voxel: deve superare il raccordo
RACCORDO = 12          # passate del raccordo morbido nelle giunture concave (ascelle, anche, spalle)
LEVIGA = 20            # passate di levigatura dopo la conversione in mesh (mani e viso protetti)
RIFINI = 4             # passate leggere finali, dopo i muscoli

# Convenzioni: piedi sull'origine, Z in alto, guarda -Y, lato sinistro +X (si costruisce il sinistro).
SPALLA = Vector((0.200, 0.0, 1.370))      # perno della spalla, dalla bozza
A_POSE = math.radians(45)
ANCA = Vector((0.092, 0.0, 0.880))
GINOCCHIO = Vector((0.104, -0.006, 0.480))
CAVIGLIA = Vector((0.112, 0.012, 0.085))

# Tronco dal cavallo al collo: (z, semilarghezza, davanti (y<0), dietro (y>0), esponente della sezione).
# Busto e collo ripresi dalla versione precedente; bacino e glutei aggiunti sotto.
TRONCO = [
    (0.800, 0.070, 0.050, 0.060, 2.0),
    (0.830, 0.125, 0.080, 0.100, 2.1),
    (0.870, 0.162, 0.092, 0.118, 2.2),
    (0.920, 0.160, 0.094, 0.110, 2.2),
    (0.980, 0.134, 0.094, 0.098, 2.2),
    (1.040, 0.134, 0.100, 0.098, 2.3),
    (1.120, 0.152, 0.110, 0.104, 2.4),
    (1.200, 0.172, 0.124, 0.112, 2.5),
    (1.280, 0.182, 0.128, 0.115, 2.6),
    (1.340, 0.182, 0.110, 0.108, 2.6),
    (1.385, 0.170, 0.085, 0.092, 2.4),
    (1.420, 0.128, 0.068, 0.078, 2.2),
    (1.448, 0.080, 0.060, 0.066, 2.1),
    (1.485, 0.066, 0.056, 0.062, 2.1),
    (1.545, 0.062, 0.052, 0.058, 2.1),
]
# Testa dal mento alla sommità (stessa forma della versione precedente, camera di gioco a 1,60).
TESTA = [
    # mento e mandibola squadrati (fase 6): fondo largo e piatto, sezioni quasi rettangolari
    (1.460, 0.034, 0.060, 0.010, 3.0),
    (1.468, 0.044, 0.076, 0.030, 3.0),
    (1.482, 0.050, 0.080, 0.045, 2.8),
    (1.500, 0.056, 0.086, 0.060, 2.6),
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


# ---------------------------------------------------------------- forme

def interp(table, k):
    """Interpola in modo morbido (Catmull-Rom) le colonne di una tabella ordinata sulla prima.
    L'interpolazione lineare lascia uno spigolo a ogni riga, che si vede come una fascia."""
    if k <= table[0][0]:
        return table[0][1:]
    for i in range(len(table) - 1):
        a, b = table[i], table[i + 1]
        if k <= b[0]:
            p = table[i - 1] if i > 0 else a
            q = table[i + 2] if i + 2 < len(table) else b
            t = (k - a[0]) / (b[0] - a[0])
            t2, t3 = t * t, t * t * t
            return tuple(
                0.5 * (2 * y1 + (y2 - y0) * t + (2 * y0 - 5 * y1 + 4 * y2 - y3) * t2 + (3 * y1 - y0 - 3 * y2 + y3) * t3)
                for y0, y1, y2, y3 in zip(p[1:], a[1:], b[1:], q[1:]))
    return table[-1][1:]


def superellisse(w, df, db, p, n, a0=-math.pi / 2, pfront=0.0, pback=0.0):
    """Punti 2D di una sezione: semilarghezza w, profondità davanti (-y) e dietro (+y)."""
    pts = []
    for i in range(n):
        a = a0 + 2 * math.pi * i / n
        c, s = math.cos(a), math.sin(a)
        pp = p + (pfront if s < 0 else pback)
        x = w * math.copysign(abs(c) ** (2 / pp), c)
        y = (df if s < 0 else db) * math.copysign(abs(s) ** (2 / pp), s)
        pts.append((x, y))
    return pts


def loft(bm, rings):
    """Unisce anelli con lo stesso numero di punti e chiude le estremità."""
    vs = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(rings[0])
    for r0, r1 in zip(vs, vs[1:]):
        for i in range(n):
            bm.faces.new((r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i]))
    bm.faces.new(list(reversed(vs[0])))
    bm.faces.new(vs[-1])


def loft_verticale(bm, table, step, n=48, cx=0.0, cy=0.0, pfront=0.0, pback=0.0):
    z0, z1 = table[0][0], table[-1][0]
    k = max(2, int(round((z1 - z0) / step)))
    rings = []
    for j in range(k + 1):
        z = z0 + (z1 - z0) * j / k
        w, df, db, p = interp(table, z)
        rings.append([(cx + x, cy + y, z) for x, y in superellisse(max(w, 1e-4), max(df, 1e-4), max(db, 1e-4), p, n, pfront=pfront, pback=pback)])
    loft(bm, rings)


def loft_asse(bm, p0, p1, table, n=32, step=0.01, up=Vector((0, 1, 0))):
    """Sezioni lungo un asse da p0 a p1. table: (t, raggio_u, raggio_v, esponente) con t in 0..1.
    u è perpendicolare all'asse nel piano dell'asse e di `up`, v è il più vicino possibile a `up`."""
    d = (p1 - p0)
    L = d.length
    d.normalize()
    v = (up - d * up.dot(d)).normalized()
    u = v.cross(d).normalized()
    k = max(2, int(round(L / step)))
    rings = []
    for j in range(k + 1):
        t = j / k
        ru, rv, p = interp(table, t)
        c = p0 + d * (L * t)
        rings.append([c + u * x + v * y for x, y in superellisse(max(ru, 1e-4), max(rv, 1e-4), max(rv, 1e-4), p, n)])
    loft(bm, rings)


def ellissoide(bm, c, r, rot=Matrix.Identity(3), segs=24, anelli=14):
    m = Matrix.Translation(c) @ rot.to_4x4() @ Matrix.Diagonal((*r, 1.0))
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=anelli, radius=1.0, matrix=m)


# ---------------------------------------------------------------- parti

def tronco_e_testa(bm, resto):
    """Tronco in `bm` (con raccordo); testa, orecchie e naso in `resto` (senza: la mandibola resta netta)."""
    loft_verticale(bm, TRONCO, 0.006, n=64)
    bm = resto
    loft_verticale(bm, TESTA, 0.004, n=64, cy=CY_TESTA, pfront=0.5, pback=-0.3)
    for s in (1, -1):
        # orecchie: dischi schiacciati, inclinati all'indietro
        ellissoide(bm, Vector((s * 0.071, 0.012, 1.572)), (0.010, 0.022, 0.030),
                   Matrix.Rotation(math.radians(-12), 3, "X"), segs=16, anelli=10)
    naso(bm)


def naso(bm):
    """Naso ben piazzato, all'italiana: dorso dritto dalla radice tra gli occhi alla punta, che esce
    di circa 2,5 cm dal viso, tonda (non appuntita), più un riempimento dietro il dorso e le ali delle narici."""
    radice, punta = Vector((0.0, -0.088, 1.594)), Vector((0.0, -0.110, 1.542))
    avanti = Vector((0, -1, 0))
    loft_asse(bm, radice, punta, [(0.0, 0.007, 0.006, 2.0), (0.5, 0.009, 0.010, 2.0),
                                  (0.85, 0.012, 0.012, 2.0), (1.0, 0.011, 0.010, 2.0)], n=16, step=0.004, up=avanti)
    loft_asse(bm, Vector((0.0, -0.086, 1.588)), Vector((0.0, -0.098, 1.535)),
              [(0.0, 0.008, 0.008, 2.0), (1.0, 0.012, 0.012, 2.0)], n=16, step=0.004, up=avanti)
    ellissoide(bm, Vector((0.0, -0.106, 1.542)), (0.014, 0.012, 0.012), segs=16, anelli=10)   # punta tonda
    for s in (1, -1):
        ellissoide(bm, Vector((0.015 * s, -0.099, 1.537)), (0.010, 0.011, 0.009), segs=12, anelli=8)


def gamba(bm, s):
    anca, gin, cav = (Vector((s * v.x, v.y, v.z)) for v in (ANCA, GINOCCHIO, CAVIGLIA))
    # coscia: dal bacino al ginocchio, quadricipite davanti
    # parte da dentro il bacino con un raggio piccolo, così non lascia un bordo sopra l'anca
    loft_asse(bm, anca + Vector((-s * 0.02, 0, 0.10)), gin, [
        (0.00, 0.050, 0.060, 2.0), (0.22, 0.092, 0.098, 2.2), (0.55, 0.082, 0.084, 2.2),
        (0.88, 0.058, 0.060, 2.1), (1.00, 0.053, 0.055, 2.0)], n=40)
    # polpaccio: rigonfio dietro in alto, stretto alla caviglia
    loft_asse(bm, gin + Vector((0, 0, 0.04)), cav, [
        (0.00, 0.052, 0.054, 2.0), (0.20, 0.055, 0.062, 2.1), (0.40, 0.050, 0.056, 2.1),
        (0.75, 0.034, 0.036, 2.0), (1.00, 0.030, 0.032, 2.0)], n=40)
    # piede: punta verso -Y, ruotata di 8° verso l'esterno
    rot = Matrix.Rotation(math.radians(8) * s, 3, "Z")
    tallone = cav + Vector((0, 0.025, -0.045))
    punta = cav + rot @ Vector((0, -0.19, -0.06))
    loft_asse(bm, tallone, punta, [
        (0.00, 0.034, 0.040, 2.2), (0.30, 0.042, 0.045, 2.6), (0.75, 0.048, 0.030, 2.8),
        (1.00, 0.040, 0.016, 2.4)], n=32, up=Vector((0, 0, 1)))


def braccio(bm, mani, s):
    """Braccio nel bmesh del corpo; mano e dita in `mani`, che si unisce dopo il raccordo."""
    rot = Matrix.Rotation(-A_POSE * s, 3, "Y")          # A-pose: braccio verso il basso e in fuori
    spalla = Vector((s * SPALLA.x, SPALLA.y, SPALLA.z))
    giu = rot @ Vector((0, 0, -1))
    gomito = spalla + giu * 0.270
    polso = gomito + giu * 0.250
    up = Vector((0, -1, 0))                              # v verso il davanti
    # sommità della spalla: raccorda il trapezio al deltoide, in discesa verso l'esterno
    ellissoide(bm, Vector((s * 0.168, 0.004, 1.372)), (0.070, 0.074, 0.045),
               Matrix.Rotation(math.radians(-22) * s, 3, "Y"))
    # deltoide: avvolge la testa del braccio, più basso della linea del trapezio
    ellissoide(bm, spalla + rot @ Vector((-s * 0.006, 0, -0.060)), (0.058, 0.064, 0.095), rot)
    # braccio: bicipite davanti, tricipite dietro; parte da dentro il busto
    loft_asse(bm, spalla - giu * 0.03 - rot @ Vector((s * 0.02, 0, 0)), gomito, [
        (0.00, 0.050, 0.056, 2.1), (0.30, 0.056, 0.062, 2.2), (0.65, 0.050, 0.054, 2.1),
        (1.00, 0.042, 0.043, 2.0)], n=32, up=up)
    # avambraccio: pieno sotto il gomito, piatto al polso
    loft_asse(bm, gomito, polso, [
        (0.00, 0.042, 0.043, 2.0), (0.25, 0.048, 0.045, 2.1), (0.70, 0.036, 0.032, 2.2),
        (1.00, 0.027, 0.021, 2.3)], n=32, up=up)
    # mano: palmo verso il corpo, larghezza lungo Y
    nocche = polso + giu * 0.095
    loft_asse(mani, polso - giu * 0.015, nocche, [
        (0.00, 0.017, 0.030, 2.4), (0.40, 0.016, 0.042, 2.8), (1.00, 0.013, 0.044, 3.0)],
        n=32, up=up)
    fuori = rot @ Vector((s, 0, 0))                      # direzione del dorso
    for i, (dy, lung) in enumerate(((-0.031, 0.075), (-0.011, 0.085), (0.010, 0.080), (0.029, 0.065))):
        base = nocche + Vector((0, dy, 0)) - giu * 0.008
        # dita leggermente piegate verso il palmo, così il futuro scheletro sa da che parte piegarle
        punta = base + giu * lung - fuori * 0.012
        loft_asse(mani, base, punta, [(0.0, 0.0095, 0.0095, 2.0), (0.8, 0.0085, 0.0085, 2.0),
                                     (1.0, 0.004, 0.004, 2.0)], n=12, step=0.006, up=up)
    # pollice: dal lato davanti del palmo, verso il basso e in avanti
    base = polso + giu * 0.030 + Vector((0, -0.032, 0)) - fuori * 0.006
    punta = base + giu * 0.050 + Vector((0, -0.030, 0)) - fuori * 0.010
    loft_asse(mani, base, punta, [(0.0, 0.013, 0.013, 2.0), (0.8, 0.010, 0.010, 2.0),
                                 (1.0, 0.005, 0.005, 2.0)], n=12, step=0.006, up=up)


# ---------------------------------------------------------------- muscoli

def piano(x, mezzo, bordo):
    """1 fino a `mezzo`, poi scende a 0 in `bordo` (un rilievo piatto con i fianchi, non una campana)."""
    if x <= mezzo:
        return 1.0
    t = min(1.0, (x - mezzo) / bordo)
    return 1.0 - t * t * (3 - 2 * t)


def bump(x, c, w):
    """Campana morbida centrata in c, larga w (0 fuori)."""
    t = (x - c) / w
    return max(0.0, 1.0 - t * t) ** 2


def rilievi(co, nr):
    """Spostamento lungo la normale (m) per i gruppi muscolari del busto. Lato sinistro: x >= 0."""
    x, y, z = abs(co.x), co.y, co.z
    d = 0.0
    if y < 0:   # davanti
        # pettorali: piastra con il bordo basso netto che sale verso l'ascella
        bordo = 1.215 + 0.18 * x
        if z > bordo - 0.01 and z < 1.40 and x < 0.17:
            d += 0.010 * bump(x, 0.075, 0.095) * min(1.0, (z - bordo + 0.01) / 0.02) * bump(z, 1.29, 0.11)
        # solco dello sterno
        d -= 0.004 * bump(x, 0.0, 0.012) * bump(z, 1.27, 0.09)
        # addominali: due colonne con tre solchi orizzontali
        if 0.98 < z < 1.20 and x < 0.075:
            d += 0.004 * bump(x, 0.035, 0.040) * bump(z, 1.09, 0.12)
            for zs in (1.03, 1.09, 1.15):
                d -= 0.0015 * bump(z, zs, 0.012) * bump(x, 0.035, 0.050)
            d -= 0.002 * bump(x, 0.0, 0.010)
    else:       # dietro
        # scapole e dorsali larghi a V
        d += 0.006 * bump(x, 0.085, 0.060) * bump(z, 1.27, 0.08)
        d += 0.004 * bump(x, 0.12, 0.05) * bump(z, 1.15, 0.10)
        # solco della colonna
        d -= 0.004 * bump(x, 0.0, 0.014) * bump(z, 1.15, 0.25)
        # glutei
        d += 0.010 * bump(x, 0.075, 0.075) * bump(z, 0.86, 0.07)
    # clavicole
    if y < 0.02:
        d += 0.003 * bump(z, 1.405 - 0.10 * x, 0.012) * bump(x, 0.08, 0.07)
    # viso (fase 6, sulla bozza del viso)
    if z > 1.46 and y < -0.02:
        d += viso(x, z) * min(1.0, (-0.02 - y) / 0.04)
    return d


def viso(x, z):
    """Tratti del viso come rilievi lungo la normale (m), lato sinistro x >= 0.
    Dalla bozza del viso: arcata a tettoia con sotto la fascia d'ombra degli occhi, naso lungo e
    dritto (l'ellissoide del naso più la radice), zigomi, labbra con la linea della bocca, mento squadrato."""
    d = 0.0
    # ampiezze marcate: con quad di 1 cm sulla testa i rilievi di pochi millimetri spariscono
    d += 0.012 * bump(z, 1.606, 0.012) * bump(x, 0.0, 0.072)       # arcata sopraccigliare
    d -= 0.009 * bump(z, 1.585, 0.014) * bump(x, 0.034, 0.027)     # fascia degli occhi, incavata
    d += 0.004 * bump(x, 0.0, 0.012) * bump(z, 1.585, 0.016)       # radice del naso
    d += 0.006 * bump(x, 0.050, 0.020) * bump(z, 1.560, 0.016)     # zigomi
    # bocca e mento in volume (sotto il naso non deve essere una parete piatta)
    d += 0.008 * bump(z, 1.521, 0.007) * bump(x, 0.0, 0.026)       # labbro superiore
    d += 0.008 * bump(z, 1.503, 0.007) * bump(x, 0.0, 0.024)       # labbro inferiore
    d -= 0.004 * bump(z, 1.512, 0.003) * bump(x, 0.0, 0.022)       # linea della bocca
    d -= 0.003 * bump(z, 1.491, 0.005) * bump(x, 0.0, 0.030)       # solco sotto il labbro
    d += 0.010 * piano(x, 0.022, 0.016) * piano(abs(z - 1.475), 0.009, 0.010)   # mento squadrato e sporgente
    return d


# ---------------------------------------------------------------- costruzione

def peso_levigatura(co):
    """Quanto levigare (0..1): pieno sul corpo, poco su viso, orecchie e mani."""
    x, z = abs(co.x), co.z
    if z > 1.50 and x < 0.095:
        return 0.15
    # distanza dalla spalla lungo il braccio in A-pose: oltre il polso c'è la mano
    giu = Vector((math.sin(A_POSE), 0, -math.cos(A_POSE)))
    lungo = (Vector((x, co.y, z)) - SPALLA).dot(giu)
    if lungo > 0.50:
        return 0.08
    return 1.0


def da_bmesh(nome, bm, coll):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(nome)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(nome, me)
    coll.objects.link(ob)
    return ob


def albero_raccordo(mani):
    """Geometry Nodes: corpo -> SDF -> raccordo delle giunture concave -> unione con le mani -> mesh.
    Il raccordo riempie ogni concavità: per questo le mani (dita) si uniscono dopo."""
    ng = bpy.data.node_groups.get("N1_Raccordo") or bpy.data.node_groups.new("N1_Raccordo", "GeometryNodeTree")
    ng.nodes.clear()
    ng.interface.clear()
    ng.interface.new_socket(name="Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    ng.interface.new_socket(name="Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    N, L = ng.nodes, ng.links
    gi, go = N.new("NodeGroupInput"), N.new("NodeGroupOutput")
    sdf = N.new("GeometryNodeMeshToSDFGrid")
    sdf.inputs["Voxel Size"].default_value = VOXEL
    sdf.inputs["Band Width"].default_value = BANDA
    fil = N.new("GeometryNodeSDFGridFillet")
    fil.inputs["Iterations"].default_value = RACCORDO
    info = N.new("GeometryNodeObjectInfo")
    info.inputs["Object"].default_value = mani
    sdf_m = N.new("GeometryNodeMeshToSDFGrid")
    sdf_m.inputs["Voxel Size"].default_value = VOXEL
    unione = N.new("GeometryNodeSDFGridBoolean")
    unione.operation = "UNION"
    mesh = N.new("GeometryNodeGridToMesh")
    mesh.inputs["Threshold"].default_value = 0.0      # superficie dell'SDF (il valore predefinito è 0,1 m dentro)
    L.new(gi.outputs[0], sdf.inputs["Mesh"])
    L.new(sdf.outputs[0], fil.inputs["Grid"])
    L.new(info.outputs["Geometry"], sdf_m.inputs["Mesh"])
    # in UNION il nodo legge solo l'ingresso multiplo "Grid" (il secondo); "Grid 1" serve alla differenza
    L.new(fil.outputs[0], unione.inputs[1])
    L.new(sdf_m.outputs[0], unione.inputs[1])
    L.new(unione.outputs[0], mesh.inputs["Grid"])
    L.new(mesh.outputs[0], go.inputs[0])
    return ng


def mesh_valutata(ob):
    """Applica i modificatori leggendo la mesh valutata (niente operatori)."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    vecchia = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(vecchia)


def run():
    sc = bpy.context.scene
    asset = bpy.data.collections["Personaggio_N1"]
    alto = bpy.data.collections.get("N1_Alto")
    if alto:
        for ob in list(alto.objects):
            me = ob.data
            bpy.data.objects.remove(ob)
            if me and me.users == 0:
                bpy.data.meshes.remove(me)
    else:
        alto = bpy.data.collections.new("N1_Alto")
        asset.children.link(alto)

    # due gruppi: busto e braccia hanno il raccordo; testa, gambe e mani si uniscono dopo,
    # perché il raccordo riempirebbe la mandibola, l'interno delle cosce e lo spazio tra le dita
    bm, bm_resto = bmesh.new(), bmesh.new()
    tronco_e_testa(bm, bm_resto)
    for s in (1, -1):
        gamba(bm_resto, s)
        braccio(bm, bm_resto, s)
    ob = da_bmesh("N1_Corpo_alto", bm, alto)
    mani = da_bmesh("N1_Resto_tmp", bm_resto, alto)

    # fonde le parti con un raccordo morbido nelle giunture, poi aggiunge il resto
    gn = ob.modifiers.new("Raccordo", "NODES")
    gn.node_group = albero_raccordo(mani)
    mesh_valutata(ob)
    me = mani.data
    bpy.data.objects.remove(mani)
    bpy.data.meshes.remove(me)

    # leviga i raccordi tra le parti senza perdere volume; mani e viso quasi fermi
    vg = ob.vertex_groups.new(name="Leviga")
    for v in ob.data.vertices:
        vg.add([v.index], peso_levigatura(v.co), "REPLACE")
    s = ob.modifiers.new("Leviga", "LAPLACIANSMOOTH")
    s.iterations, s.lambda_factor, s.use_volume_preserve = LEVIGA, 0.5, True
    s.vertex_group = vg.name
    mesh_valutata(ob)
    ob.vertex_groups.remove(ob.vertex_groups["Leviga"])

    # muscoli lungo la normale
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    sposta = [(v, rilievi(v.co, v.normal)) for v in bm.verts]
    for v, d in sposta:
        if d:
            v.co += v.normal * d
    # simmetria: il lato +X sul lato -X
    bmesh.ops.symmetrize(bm, input=bm.verts[:] + bm.edges[:] + bm.faces[:], direction="X", dist=1e-5)
    bm.to_mesh(ob.data)
    bm.free()

    s = ob.modifiers.new("Rifinitura", "LAPLACIANSMOOTH")
    s.iterations, s.lambda_factor, s.use_volume_preserve = RIFINI, 0.4, True
    mesh_valutata(ob)

    # pulizia (qa_check): suole piatte sul pavimento, doppioni e spigoli nulli della simmetria
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    for v in bm.verts:
        if v.co.z < 0.0:
            v.co.z = 0.0
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=1e-5)
    bm.to_mesh(ob.data)
    bm.free()
    # materiale provvisorio: senza, qa_check segnala le facce su uno slot vuoto
    mat = bpy.data.materials.get("M_N1_Provvisorio") or bpy.data.materials.new("M_N1_Provvisorio")
    mat.diffuse_color = (0.62, 0.42, 0.32, 1.0)
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True

    bpy.context.view_layer.update()
    lo = [min((ob.matrix_world @ v.co)[i] for v in ob.data.vertices) for i in range(3)]
    hi = [max((ob.matrix_world @ v.co)[i] for v in ob.data.vertices) for i in range(3)]
    bpy.ops.wm.save_mainfile(compress=True)   # la sorgente fitta pesa: si salva compressa
    return {
        "ok": True, "oggetto": ob.name,
        "vertici": len(ob.data.vertices), "facce": len(ob.data.polygons),
        "min": [round(c, 3) for c in lo], "max": [round(c, 3) for c in hi],
    }


print("@@JSON@@" + json.dumps(run()))
