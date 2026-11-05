"""Libreria di modellazione del Personaggio N.1, versione nuova.

Si carica in Blender con:
    exec(open(r"C:\\Dev\\Project-Zombie\\blender\\personaggi\\script\\lib_n1.py", encoding="utf-8").read())

Convenzioni: 1 unità = 1 m, piedi sull'origine, Z in alto, il personaggio guarda -Y
(il suo lato sinistro è +X, pezzi .L/.R), A-pose con le braccia a 45°.
"""
import bpy, bmesh, math, os, random
import numpy as np
from mathutils import Vector, Matrix, Quaternion, Euler
from mathutils.bvhtree import BVHTree

ROOT = r"C:\Dev\Project-Zombie\blender\personaggi"
SCRATCH = os.environ.get("PZ_SCRATCH", ROOT + r"\render")

# --- quote prese dalla bozza (1,78 mm per pixel, linea centrale x 340, suola y 1575) ---
PX = 1.72 / 967
BOZZA = ROOT + r"\..\Peronaggio_N1_bozza.jpeg"
SPALLA = Vector((0.215, 0.0, 1.365))   # perno della spalla sinistra
A_POSE = math.radians(45)


def px_z(y):
    return (1575 - y) * PX


def px_x(x):
    return (x - 340) * PX


# ---------------------------------------------------------------- scena

def coll(name, parent=None):
    sc = bpy.context.scene
    c = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    par = parent.children if parent else sc.collection.children
    if c.name not in par:
        par.link(c)
    return c


def drop(name):
    o = bpy.data.objects.get(name)
    if not o:
        return
    me = o.data if o.type in ('MESH', 'CURVE', 'FONT') else None
    bpy.data.objects.remove(o)
    if me is not None and me.users == 0:
        if isinstance(me, bpy.types.Mesh):
            bpy.data.meshes.remove(me)
        else:
            bpy.data.curves.remove(me)


def mat(name, color, metal=0.0, rough=0.6, emit=None):
    """Materiale piatto (Principled). Colore lineare."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*color, 1)
    m.metallic = metal
    m.roughness = rough
    return m


PALETTE = {
    "Pelle": ((0.60, 0.36, 0.23), 0.0, 0.55),
    "PelleScura": ((0.30, 0.15, 0.09), 0.0, 0.6),
    "Ombra": ((0.012, 0.008, 0.006), 0.0, 0.9),
    "Maglia": ((0.022, 0.022, 0.024), 0.0, 0.75),
    "Cargo": ((0.030, 0.030, 0.032), 0.0, 0.85),
    "CuoioNero": ((0.016, 0.015, 0.015), 0.0, 0.45),
    "Anfibio": ((0.018, 0.018, 0.019), 0.0, 0.4),
    "Suola": ((0.010, 0.010, 0.010), 0.0, 0.9),
    "Acciaio": ((0.80, 0.80, 0.82), 1.0, 0.28),
    "AcciaioScuro": ((0.30, 0.30, 0.32), 1.0, 0.38),
    "Brunito": ((0.025, 0.025, 0.028), 0.7, 0.42),   # spallacci neri
    "Barba": ((0.018, 0.011, 0.007), 0.0, 0.8),
    "Capelli": ((0.055, 0.030, 0.016), 0.0, 0.5),
    "Rasato": ((0.20, 0.12, 0.08), 0.0, 0.7),
    "Pelliccia": ((0.11, 0.06, 0.03), 0.0, 0.8),
}


def palette():
    for k, (c, m, r) in PALETTE.items():
        mat(k, c, m, r)


def align(d):
    return Vector((0, 0, 1)).rotation_difference(Vector(d).normalized()).to_matrix().to_4x4()


def _tag(bm, before, mi):
    for f in bm.faces:
        if f not in before:
            f.material_index = mi


def make(name, bm, mats, collection, parent=None, mirror=False, smooth=False, bevel=0.0,
         bevel_angle=65, sharp=None):
    """Crea l'oggetto da un bmesh. mirror specchia in X (per i pezzi .R)."""
    if mirror:
        bmesh.ops.scale(bm, vec=(-1, 1, 1), verts=bm.verts)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    drop(name)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(bpy.data.materials[m])
    if smooth:
        me.shade_smooth()
    else:
        me.shade_flat()
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    if parent:
        ob.parent = parent
    if smooth and sharp:
        mod = ob.modifiers.new("Spigoli", 'NODES')
        mod.node_group = _smooth_by_angle_group()
        _set_input(mod, "Angle", math.radians(sharp))
    if bevel:
        b = ob.modifiers.new("Smusso", 'BEVEL')
        b.width = bevel
        b.segments = 1
        b.limit_method = 'ANGLE'
        b.angle_limit = math.radians(bevel_angle)
        b.harden_normals = False
    return ob


def _smooth_by_angle_group():
    """Gruppo di nodi 'Smooth by Angle' minimo (morbido sotto l'angolo, spigolo sopra)."""
    g = bpy.data.node_groups.get("PZ_SmoothAngle")
    if g:
        return g
    g = bpy.data.node_groups.new("PZ_SmoothAngle", 'GeometryNodeTree')
    g.interface.new_socket("Geometry", in_out='INPUT', socket_type='NodeSocketGeometry')
    a = g.interface.new_socket("Angle", in_out='INPUT', socket_type='NodeSocketFloat')
    a.default_value = math.radians(40)
    g.interface.new_socket("Geometry", in_out='OUTPUT', socket_type='NodeSocketGeometry')
    N = g.nodes
    gi = N.new('NodeGroupInput')
    go = N.new('NodeGroupOutput')
    ea = N.new('GeometryNodeInputMeshEdgeAngle')
    cmp = N.new('FunctionNodeCompare')
    cmp.data_type = 'FLOAT'
    cmp.operation = 'GREATER_THAN'
    sh = N.new('GeometryNodeSetShadeSmooth')
    sh.domain = 'EDGE'
    nt = N.new('FunctionNodeBooleanMath')
    nt.operation = 'NOT'
    L = g.links
    L.new(ea.outputs[0], cmp.inputs[0])
    L.new(gi.outputs[1], cmp.inputs[1])
    L.new(cmp.outputs[0], nt.inputs[0])
    L.new(gi.outputs[0], sh.inputs["Geometry"])
    L.new(nt.outputs[0], sh.inputs["Shade Smooth"])
    L.new(sh.outputs[0], go.inputs[0])
    return g


def _set_input(mod, name, value):
    for it in mod.node_group.interface.items_tree:
        if getattr(it, "in_out", None) == 'INPUT' and it.name == name:
            try:
                getattr(mod.properties.inputs, it.identifier).value = value     # 5.2
            except AttributeError:
                mod[it.identifier] = value


def decimate(ob, ratio, name="Faccette"):
    d = ob.modifiers.new(name, 'DECIMATE')
    d.decimate_type = 'COLLAPSE'
    d.ratio = ratio
    d.use_symmetry = True
    d.symmetry_axis = 'X'
    return d


def tris(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    n = 0
    for o in objs:
        if o.type != 'MESH':
            continue
        e = o.evaluated_get(dg)
        me = e.to_mesh()
        me.calc_loop_triangles()
        n += len(me.loop_triangles)
        e.to_mesh_clear()
    return n


def tris_by_coll(names):
    return {c: tris(bpy.data.collections[c].all_objects) for c in names if c in bpy.data.collections}


# ---------------------------------------------------------------- forme di base

def cyl(bm, p0, p1, r0, r1, sides=8, mi=0, spin=None, sy=1.0, caps=True):
    """Prisma o tronco di cono da p0 a p1. spin=None mette una faccia piatta verso +X."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    if spin is None:
        spin = math.pi / sides
    M = (Matrix.Translation(p0) @ align(d) @ Matrix.Diagonal((1, sy, 1, 1))
         @ Matrix.Rotation(spin, 4, 'Z') @ Matrix.Translation((0, 0, d.length / 2)))
    before = set(bm.faces)
    bmesh.ops.create_cone(bm, cap_ends=caps, segments=sides, radius1=r0, radius2=r1, depth=d.length, matrix=M)
    _tag(bm, before, mi)


def box(bm, c, size, mi=0, rot=None):
    R = rot.to_matrix().to_4x4() if rot is not None else Matrix()
    M = Matrix.Translation(Vector(c)) @ R @ Matrix.Diagonal((*size, 1))
    before = set(bm.faces)
    bmesh.ops.create_cube(bm, size=1, matrix=M)
    _tag(bm, before, mi)


def sphere(bm, c, r, mi=0, segs=8, rings=6, scale=(1, 1, 1), rot=None):
    before = set(bm.faces)
    R = rot.to_matrix().to_4x4() if rot is not None else Matrix()
    M = Matrix.Translation(Vector(c)) @ R @ Matrix.Diagonal((*scale, 1)) @ Matrix.Scale(r, 4)
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1, matrix=M)
    _tag(bm, before, mi)


def dome(bm, c, r, axis, scale=(1, 1, 1), mi=0, segs=8, rings=6, cut=-0.01):
    """Calotta con il polo lungo axis."""
    before_v = set(bm.verts)
    before = set(bm.faces)
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1)
    nv = [v for v in bm.verts if v not in before_v]
    bmesh.ops.delete(bm, geom=[v for v in nv if v.co.z < cut], context='VERTS')
    nv = [v for v in bm.verts if v not in before_v]
    M = Matrix.Translation(Vector(c)) @ align(axis) @ Matrix.Diagonal((*scale, 1)) @ Matrix.Scale(r, 4)
    bmesh.ops.transform(bm, matrix=M, verts=nv)
    _tag(bm, before, mi)


def hexnut(bm, c, axis, r, h, mi=0, spin=0.0):
    """Dado esagonale con la faccia piatta verso l'esterno lungo axis."""
    axis = Vector(axis).normalized()
    cyl(bm, Vector(c) - axis * h * 0.5, Vector(c) + axis * h * 0.5, r, r * 0.92, sides=6, mi=mi, spin=spin)


def cone(bm, base, tip, r, sides=6, mi=0):
    cyl(bm, base, tip, r, 0.0005, sides=sides, mi=mi)


def ring_pts(cx, cy, z, w, d, n=16, p=2.6, front=None, wobble=None, back=None, a0=0.0):
    """Anello a superellisse (w, d = semiassi). wobble(a) moltiplica il raggio (pieghe)."""
    pts = []
    for i in range(n):
        a = a0 + 2 * math.pi * i / n
        c, s = math.cos(a), math.sin(a)
        k = wobble(a) if wobble else 1.0
        x = w * k * math.copysign(abs(c) ** (2 / p), c)
        y = d * k * math.copysign(abs(s) ** (2 / p), s)
        if front and y < 0:
            y -= front(x) * min(1.0, -s * 1.5)
        if back and y > 0:
            y += back(x) * min(1.0, s * 1.5)
        pts.append(Vector((cx + x, cy + y, z)))
    return pts


def loft(bm, rings, mi=0, cap0=True, cap1=True, closed=True):
    before = set(bm.faces)
    vr = [[bm.verts.new(p) for p in r] for r in rings]
    for a, b in zip(vr, vr[1:]):
        n = len(a)
        for j in range(n if closed else n - 1):
            bm.faces.new((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))
    if cap0:
        bm.faces.new(list(reversed(vr[0])))
    if cap1:
        bm.faces.new(vr[-1])
    bmesh.ops.recalc_face_normals(bm, faces=[f for f in bm.faces if f not in before])
    _tag(bm, before, mi)
    return vr


def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def bump(x, c, w):
    """Campana morbida centrata in c con semiampiezza w (0 fuori)."""
    t = (x - c) / w
    return max(0.0, 1 - t * t) ** 2


def interp_table(table, z):
    """table = [(z, v1, v2, ...)] ordinata per z: interpolazione morbida."""
    if z <= table[0][0]:
        return list(table[0][1:])
    for a, b in zip(table, table[1:]):
        if a[0] <= z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            t = t * t * (3 - 2 * t)
            return [a[k] + (b[k] - a[k]) * t for k in range(1, len(a))]
    return list(table[-1][1:])


def sculpt_loft(table, n=96, step=0.004, p_of=None, z0=None, z1=None):
    """Forma di base liscia e fitta: table = [(z, semilarghezza, semiprofondità, spostamento Y)]."""
    z = table[0][0] if z0 is None else z0
    z1 = table[-1][0] if z1 is None else z1
    rings = []
    while z <= z1 + 1e-6:
        w, d, cy = interp_table(table, z)[:3]
        p = p_of(z) if p_of else 2.6
        rings.append(ring_pts(0, cy, z, w, d, n=n, p=p, a0=-math.pi / 2))
        z += step
    return rings


def displace(bm, fn, horizontal=True):
    """Sposta ogni vertice lungo la normale (orizzontale) di fn(x, y, z) metri."""
    bm.normal_update()
    moves = []
    for v in bm.verts:
        nrm = Vector((v.normal.x, v.normal.y, 0 if horizontal else v.normal.z))
        if nrm.length < 1e-6:
            continue
        nrm.normalize()
        moves.append((v, nrm * fn(v.co.x, v.co.y, v.co.z)))
    for v, m in moves:
        v.co += m


# ---------------------------------------------------------------- superfici e capelli

def bvh_of(*names):
    dg = bpy.context.evaluated_depsgraph_get()
    return [BVHTree.FromObject(bpy.data.objects[n], dg) for n in names]


def keep_out(p, bvhs, margin):
    for b in bvhs:
        hit, nrm, _, d = b.find_nearest(p)
        if hit is not None and (p - hit).dot(nrm) < margin:
            p = hit + nrm * margin
    return p


def bezier_pts(ctrl, n):
    """Curva di Catmull-Rom per i punti di controllo, n punti equispaziati in parametro."""
    P = [Vector(c) for c in ctrl]
    P = [P[0] * 2 - P[1]] + P + [P[-1] * 2 - P[-2]]
    out = []
    segs = len(P) - 3
    for k in range(n):
        t = k / (n - 1) * segs
        i = min(int(t), segs - 1)
        u = t - i
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u
                          + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u))
    return out


def frames(pts, up):
    """Sistemi di riferimento lungo la guida: (tangente, lato, su)."""
    up = Vector(up).normalized()
    out = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        s = t.cross(up)
        if s.length < 1e-6:
            s = t.orthogonal()
        s.normalize()
        u = s.cross(t).normalized()
        out.append((t, s, u))
    return out


def lock(bm, uv, pts, w0, h0, up, mi=0, sides=8, taper=1.6, tip=0.25, u0=0.0, u1=1.0, twist=0.0,
         flat_tip=True, root_w=None):
    """Ciocca piena e morbida: sezione ellittica larga w0 e alta h0 che si assottiglia
    verso la punta (arrotondata, non a spuntone). UV: u attorno, v dalla radice alla punta."""
    L = [0.0]
    for a, b in zip(pts, pts[1:]):
        L.append(L[-1] + (b - a).length)
    F = frames(pts, up)
    rings = []
    for i, p in enumerate(pts):
        t = L[i] / L[-1]
        k = max(tip, 1.0 - t ** taper)
        if root_w is not None and t < 0.25:
            k *= root_w + (1 - root_w) * smoothstep(0, 0.25, t)
        _, s, u = F[i]
        ang = twist * t
        cs, sn = math.cos(ang), math.sin(ang)
        s2, u2 = s * cs + u * sn, -s * sn + u * cs
        ring = []
        for j in range(sides):
            a = 2 * math.pi * j / sides
            ring.append(bm.verts.new(p + s2 * math.cos(a) * w0 * 0.5 * k + u2 * math.sin(a) * h0 * 0.5 * k))
        rings.append(ring)
    before = set(bm.faces)
    for i in range(len(rings) - 1):
        A, B = rings[i], rings[i + 1]
        for j in range(sides):
            f = bm.faces.new((A[j], A[(j + 1) % sides], B[(j + 1) % sides], B[j]))
            for loop, (jj, ii) in zip(f.loops, ((j, i), (j + 1, i), (j + 1, i + 1), (j, i + 1))):
                loop[uv].uv = (u0 + (u1 - u0) * jj / sides, L[ii] / L[-1])
    # punta chiusa a ventaglio (arrotondata)
    c = bm.verts.new(pts[-1] + F[-1][0] * (w0 * 0.25 * tip))
    for j in range(sides):
        f = bm.faces.new((rings[-1][j], rings[-1][(j + 1) % sides], c))
        for loop, (jj, vv) in zip(f.loops, ((j, 0.97), (j + 1, 0.97), (j + 0.5, 1.0))):
            loop[uv].uv = (u0 + (u1 - u0) * jj / sides, vv)
    f = bm.faces.new(list(reversed(rings[0])))
    for loop in f.loops:
        loop[uv].uv = (u0, 0.0)
    _tag(bm, before, mi)


def card(bm, uv, pts, w0, w1, normal_of, col, ncol, mi=0, curl=0.0):
    """Scheda di capelli: nastro lungo la guida, appoggiato alla superficie (normal_of(p) -> normale).
    col = colonna dell'atlante, ncol = numero di colonne. curl piega il nastro a C."""
    L = [0.0]
    for a, b in zip(pts, pts[1:]):
        L.append(L[-1] + (b - a).length)
    rows = []
    before = set(bm.faces)
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        n = normal_of(p)
        s = t.cross(n)
        if s.length < 1e-6:
            s = t.orthogonal()
        s.normalize()
        nn = s.cross(t).normalized()
        w = w0 + (w1 - w0) * (L[i] / L[-1])
        rows.append([bm.verts.new(p - s * w / 2 + nn * curl * w), bm.verts.new(p + nn * 0.0),
                     bm.verts.new(p + s * w / 2 + nn * curl * w)])
    u0, u1 = col / ncol, (col + 1) / ncol
    us = (u0 + 0.02 / ncol, (u0 + u1) / 2, u1 - 0.02 / ncol)
    for i in range(len(rows) - 1):
        for j in range(2):
            f = bm.faces.new((rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]))
            for loop, (jj, ii) in zip(f.loops, ((j, i), (j + 1, i), (j + 1, i + 1), (j, i + 1))):
                loop[uv].uv = (us[jj], 0.02 + 0.96 * L[ii] / L[-1])
    _tag(bm, before, mi)


# ---------------------------------------------------------------- texture generate

def save_rgba(name, arr, path):
    """arr: float32 (H, W, 4) con la riga 0 in alto. Salva un PNG e restituisce l'immagine."""
    h, w = arr.shape[:2]
    img = bpy.data.images.get(name)
    if img and (img.size[0] != w or img.size[1] != h):
        bpy.data.images.remove(img)
        img = None
    img = img or bpy.data.images.new(name, w, h, alpha=True)
    img.pixels.foreach_set(np.ascontiguousarray(arr[::-1]).ravel().astype(np.float32))
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    return img


def strand_texture(w, h, base, seed=0, contrast=0.45, freq=60, alpha=False, clumps=8, tip_fade=0.25):
    """Texture di ciocche: righe sottili lungo v (verso la punta), radice più scura.
    alpha=True genera l'atlante delle schede (ciuffi con il bordo trasparente)."""
    rng = np.random.default_rng(seed)
    v = np.linspace(0, 1, h)[:, None]          # 0 = radice (in alto nell'array), 1 = punta
    u = np.linspace(0, 1, w)[None, :]
    lum = np.zeros((h, w), np.float32)
    cover = np.zeros((h, w), np.float32)
    nstr = int(freq * (clumps if alpha else 1) * 1.5)
    for _ in range(nstr):
        col = rng.integers(0, clumps) if alpha else 0
        cx = (col + 0.5) / clumps if alpha else rng.uniform(0, 1)
        spread = 0.42 / clumps if alpha else 0.0
        x0 = cx + rng.uniform(-spread, spread)
        ln = rng.uniform(0.75, 1.0) if alpha else 1.0
        wav = rng.uniform(0.002, 0.008) * np.sin(v * rng.uniform(6, 14) + rng.uniform(0, 6.3))
        pinch = (cx - x0) * (v ** 1.4) * (0.7 if alpha else 0.0)
        xc = x0 + wav + pinch
        width = rng.uniform(0.6, 1.4) / w * (1.0 - 0.6 * v)
        d = np.abs(u - xc)
        if not alpha:
            d = np.minimum(d, 1 - d)             # si ripete in u
        s = np.clip(1 - d / (width * 1.5 + 1e-6), 0, 1)
        s = s * (v <= ln)
        b = rng.uniform(0.6, 1.3)
        lum = np.maximum(lum, s * b)
        cover = np.maximum(cover, s)
    root = 0.55 + 0.45 * np.clip(v / 0.35, 0, 1)
    if alpha:
        shade = (0.55 + 0.6 * lum) * root
    else:
        noise = rng.normal(0, 1, (h // 8 + 1, w // 4 + 1))
        noise = np.kron(noise, np.ones((8, 4)))[:h, :w]
        shade = (1 - contrast) + contrast * (0.6 * lum + 0.4 * (0.5 + 0.15 * noise)) * 1.4
        shade = shade * (0.8 + 0.2 * root)
    out = np.zeros((h, w, 4), np.float32)
    for k in range(3):
        out[..., k] = np.clip(base[k] * shade, 0, 1)
    if alpha:
        a = np.clip(cover * 1.6, 0, 1) * (1 - smooth_np(1 - tip_fade, 1.0, v))
        out[..., 3] = a
    else:
        out[..., 3] = 1
    return out


def smooth_np(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def tex_material(name, img, rough=0.5, alpha=False, normal_strength=0.0, sheen=0.0):
    """Materiale con la texture (UV) come colore; con alpha usa alpha test (dithered in Blender)."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type not in ('BSDF_PRINCIPLED', 'OUTPUT_MATERIAL'):
            nt.nodes.remove(n)
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = img
    t.location = (b.location.x - 350, b.location.y)
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = 0.0
    if alpha:
        nt.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
        m.surface_render_method = 'DITHERED'
        m.use_backface_culling = False
    px = np.empty(img.size[0] * img.size[1] * 4, np.float32)
    img.pixels.foreach_get(px)
    m.diffuse_color = (*px.reshape(-1, 4)[:, :3].mean(0), 1)
    return m


# ---------------------------------------------------------------- verifica

def ensure_cam():
    cam = bpy.data.objects.get("CameraVerifica")
    if not cam:
        cam = bpy.data.objects.new("CameraVerifica", bpy.data.cameras.new("CameraVerifica"))
        coll("Riferimenti").objects.link(cam)
    return cam


def light_rig():
    """Luci di verifica: chiave calda, riempimento freddo, controluce."""
    c = coll("Riferimenti")
    spec = {"Luce_Chiave": ((2.5, -3.0, 3.2), 4.0, (1.0, 0.95, 0.88)),
            "Luce_Riempimento": ((-3.0, -2.0, 1.6), 1.4, (0.8, 0.88, 1.0)),
            "Luce_Contro": ((0.5, 3.5, 2.8), 3.0, (1.0, 1.0, 1.0))}
    for n, (loc, e, col) in spec.items():
        o = bpy.data.objects.get(n)
        if not o:
            o = bpy.data.objects.new(n, bpy.data.lights.new(n, 'SUN'))
            c.objects.link(o)
        o.data.energy = e
        o.data.color = col
        o.data.angle = math.radians(8)
        o.location = loc
        o.rotation_mode = 'QUATERNION'
        o.rotation_quaternion = (Vector((0, 0, 1)) - Vector(loc)).to_track_quat('-Z', 'Y')
    w = bpy.context.scene.world or bpy.data.worlds.new("Mondo")
    bpy.context.scene.world = w
    bg = next(n for n in w.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs[0].default_value = (0.05, 0.055, 0.06, 1)
    bg.inputs[1].default_value = 1.0


def look(name, eye, target, res=(600, 900), lens=50, ortho=None, out=None):
    sc = bpy.context.scene
    cam = ensure_cam()
    sc.camera = cam
    eye, target = Vector(eye), Vector(target)
    cam.location = eye
    cam.rotation_mode = 'QUATERNION'
    cam.rotation_quaternion = (target - eye).to_track_quat('-Z', 'Y')
    if ortho:
        cam.data.type = 'ORTHO'
        cam.data.ortho_scale = ortho
    else:
        cam.data.type = 'PERSP'
        cam.data.lens = lens
    cam.data.clip_start = 0.01
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    path = os.path.join(out or SCRATCH, name + ".png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def eevee():
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.eevee.taa_render_samples = 16
    sc.view_settings.view_transform = 'AgX'
    sc.view_settings.look = 'None'


def sheet(paths, out, cols=None):
    """Affianca più render in un'unica immagine (numpy)."""
    ims = []
    for p in paths:
        im = bpy.data.images.load(p, check_existing=False)
        a = np.empty(im.size[0] * im.size[1] * 4, np.float32)
        im.pixels.foreach_get(a)
        ims.append(a.reshape(im.size[1], im.size[0], 4))
        bpy.data.images.remove(im)
    cols = cols or len(ims)
    rows = (len(ims) + cols - 1) // cols
    h = max(i.shape[0] for i in ims)
    w = max(i.shape[1] for i in ims)
    S = np.zeros((h * rows, w * cols, 4), np.float32)
    S[..., 3] = 1
    for k, a in enumerate(ims):
        r, c = k // cols, k % cols
        r = rows - 1 - r                      # le righe di Blender partono dal basso
        S[r * h:r * h + a.shape[0], c * w:c * w + a.shape[1]] = a
    save_rgba("_sheet", S[::-1], out)
    return out


def views(tag, target=(0, 0, 0.92), dist=4.2, res=(520, 860), lens=50, extra=()):
    """Fronte, lato, tre quarti e retro, affiancati in un'immagine."""
    p = []
    t = Vector(target)
    for n, d in (("fronte", (0, -1, 0.06)), ("lato", (1, 0, 0.06)), ("tq", (0.72, -0.72, 0.18)),
                 ("retro", (-0.3, 1, 0.1))) + tuple(extra):
        dv = Vector(d).normalized() * dist
        p.append(look(f"{tag}_{n}", t + dv, t, res=res, lens=lens))
    return sheet(p, os.path.join(SCRATCH, f"{tag}.png"))


def closeup(tag, target, dirs, dist=0.9, lens=60, res=(700, 700)):
    p = []
    t = Vector(target)
    for i, d in enumerate(dirs):
        dv = Vector(d).normalized() * dist
        p.append(look(f"{tag}_{i}", t + dv, t, res=res, lens=lens))
    return sheet(p, os.path.join(SCRATCH, f"{tag}.png"))


def overlay(tag, crop=(90, 560, 610, 1620)):
    """Render ortogonale di fronte alla stessa scala della bozza, fuso con il disegno."""
    x0, y0, x1, y1 = crop
    w, h = x1 - x0, y1 - y0
    cx = px_x((x0 + x1) / 2)
    cz = px_z((y0 + y1) / 2)
    sc = bpy.context.scene
    cam = ensure_cam()
    cam.data.sensor_fit = 'VERTICAL'
    path = look(tag + "_orto", (cx, -5, cz), (cx, 0, cz), res=(w, h), ortho=h * PX)
    cam.data.sensor_fit = 'AUTO'
    r = bpy.data.images.load(path, check_existing=False)
    R = np.empty(w * h * 4, np.float32)
    r.pixels.foreach_get(R)
    R = R.reshape(h, w, 4)[::-1]
    bpy.data.images.remove(r)
    d = bpy.data.images.load(os.path.abspath(BOZZA), check_existing=True)
    DW, DH = d.size
    D = np.empty(DW * DH * 4, np.float32)
    d.pixels.foreach_get(D)
    D = D.reshape(DH, DW, 4)[::-1][y0:y1, x0:x1]
    ink = np.clip((0.75 - D[..., :3].mean(-1)) * 3, 0, 1)[..., None]   # tratto a penna
    out = R.copy()
    out[..., :3] = R[..., :3] * (1 - ink * 0.9) + np.array([1.0, 0.15, 0.1]) * ink * 0.9
    both = np.concatenate([out, np.dstack([D[..., :3], np.ones((h, w))])], axis=1)
    save_rgba("_overlay", both.astype(np.float32), os.path.join(SCRATCH, tag + "_overlay.png"))
    return os.path.join(SCRATCH, tag + "_overlay.png")



# ---------------------------------------------------------------- forme organiche
# Metodo: primitive con misure esatte -> fuse con il voxel remesh -> ammorbidite ->
# ritopologia a quad (Quadriflow) proiettata sulla forma alta.

def _ctx(ob):
    vl = bpy.context.view_layer
    for o in vl.objects:
        if o.select_get():
            o.select_set(False)
    vl.objects.active = ob
    ob.select_set(True)
    return bpy.context.temp_override(object=ob, active_object=ob, selected_objects=[ob],
                                     selected_editable_objects=[ob])


def apply_mods(ob):
    for name in [m.name for m in ob.modifiers]:
        with _ctx(ob):
            bpy.ops.object.modifier_apply(modifier=name)


def ellipsoid(bm, c, abc, rot=None, segs=24, rings=14, mi=0):
    """Ellissoide con semiassi abc (x, y, z), ruotato con rot (Euler in gradi o Quaternion)."""
    before = set(bm.faces)
    if rot is not None and not isinstance(rot, Quaternion):
        rot = Euler([math.radians(a) for a in rot]).to_quaternion()
    R = rot.to_matrix().to_4x4() if rot is not None else Matrix()
    M = Matrix.Translation(Vector(c)) @ R @ Matrix.Diagonal((*abc, 1))
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1, matrix=M)
    _tag(bm, before, mi)


def capsule(bm, p0, p1, r0, r1=None, segs=20, mi=0, sy=1.0):
    """Capsula da p0 a p1 (raggi r0 e r1): tronco con due sfere alle estremità."""
    r1 = r0 if r1 is None else r1
    p0, p1 = Vector(p0), Vector(p1)
    d = (p1 - p0).normalized()
    R = Vector((0, 0, 1)).rotation_difference(d)
    cyl(bm, p0, p1, r0, r1, sides=segs, mi=mi, sy=sy)
    ellipsoid(bm, p0, (r0, r0 * sy, r0), rot=R, segs=segs, rings=10, mi=mi)
    ellipsoid(bm, p1, (r1, r1 * sy, r1), rot=R, segs=segs, rings=10, mi=mi)


def fuse(name, bm, collection, voxel=0.004, smooth=8, factor=0.6, mats=("Pelle",)):
    """Fonde le primitive del bmesh in un volume unico (voxel remesh) e lo ammorbidisce."""
    ob = make(name, bm, list(mats), collection, smooth=True)
    ob.data.remesh_voxel_size = voxel
    ob.data.use_remesh_preserve_volume = True
    with _ctx(ob):
        bpy.ops.object.voxel_remesh()
    if smooth:
        m = ob.modifiers.new("Leviga", 'LAPLACIANSMOOTH')
        m.iterations = smooth
        m.lambda_factor = factor
        m.use_volume_preserve = True
        m.use_normalized = True
        apply_mods(ob)
    return ob


def sculpt_fn(ob, fn, along_normal=True):
    """Sposta ogni vertice di fn(co, normale) metri lungo la normale (numpy)."""
    me = ob.data
    n = len(me.vertices)
    co = np.empty(n * 3, np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    me.update()
    nr = np.empty(n * 3, np.float32)
    me.vertices.foreach_get("normal", nr)
    nr = nr.reshape(-1, 3)
    d = fn(co, nr)
    co = co + nr * d[:, None]
    me.vertices.foreach_set("co", co.ravel())
    me.update()


def retopo(src, faces, name=None, symmetry=True, keep_src=True, sharp=None, flat=False, qvoxel=0.01):
    """Copia di src ritopologizzata a quad (Quadriflow) e proiettata sulla forma alta."""
    name = name or src.name + "_low"
    drop(name)
    low = src.copy()
    low.data = src.data.copy()
    low.name = name
    low.data.name = name
    for c in src.users_collection:
        c.objects.link(low)
    # Quadriflow rifiuta le mesh troppo fitte: gli do una copia a voxel larghi (solo per il flusso dei quad),
    # poi il risultato viene proiettato sulla forma dettagliata
    low.data.remesh_voxel_size = qvoxel
    with _ctx(low):
        bpy.ops.object.voxel_remesh()
        res = bpy.ops.object.quadriflow_remesh(mode="FACES", target_faces=faces, use_mesh_symmetry=symmetry,
                                               use_preserve_sharp=False, use_preserve_boundary=False,
                                               smooth_normals=False, seed=0)
    if res != {"FINISHED"}:
        raise RuntimeError("quadriflow fallito su " + src.name)
    sw = low.modifiers.new("Proietta", 'SHRINKWRAP')
    sw.target = src
    sw.wrap_method = 'PROJECT'
    sw.wrap_mode = 'ON_SURFACE'
    sw.use_negative_direction = sw.use_positive_direction = True
    apply_mods(low)
    if flat:
        low.data.shade_flat()
    else:
        low.data.shade_smooth()
        if sharp:
            mod = low.modifiers.new("Spigoli", 'NODES')
            mod.node_group = _smooth_by_angle_group()
            _set_input(mod, "Angle", math.radians(sharp))
    if keep_src:
        src.hide_set(True)
        src.hide_render = True
    else:
        drop(src.name)
    return low


def np_co(ob):
    n = len(ob.data.vertices)
    co = np.empty(n * 3, np.float32)
    ob.data.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def sbump(x, c, w):
    """bump vettoriale (numpy)."""
    t = (x - c) / w
    return np.clip(1 - t * t, 0, None) ** 2


def ssmooth(e0, e1, x):
    return smooth_np(e0, e1, x)


# ---------------------------------------------------------------- texture dipinte in 3D
# Ogni pixel della texture riceve la posizione 3D del punto di superficie che gli corrisponde
# (rasterizzazione dei triangoli nello spazio UV), così i disegni si descrivono in coordinate del corpo.

def lin2srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def uv_cylinder(ob, z0, z1, cx=0.0, cy=0.0, name="UVMap"):
    """UV cilindriche attorno a Z: u = angolo (0,5 davanti), v = altezza. Corregge i triangoli sulla cucitura."""
    me = ob.data
    uv = me.uv_layers.get(name) or me.uv_layers.new(name=name)
    for p in me.polygons:
        us = []
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            u = 0.5 + math.atan2(co.x - cx, -(co.y - cy)) / (2 * math.pi)
            us.append((li, u, (co.z - z0) / (z1 - z0)))
        lo = min(u for _, u, _ in us)
        for li, u, v in us:
            if u - lo > 0.5:
                u -= 1.0
            uv.data[li].uv = (u, v)
    return uv


def rasterize(ob, res, uvname="UVMap"):
    """Per ogni pixel coperto: indice del pixel, posizione e normale 3D interpolate."""
    me = ob.data
    me.calc_loop_triangles()
    uv = me.uv_layers[uvname].data
    tri_l = np.array([t.loops[:] for t in me.loop_triangles], np.int64)
    tri_v = np.array([t.vertices[:] for t in me.loop_triangles], np.int64)
    UV = np.array([uv[i].uv[:] for i in range(len(uv))], np.float64)
    CO = np_co(ob).astype(np.float64)
    nr = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("normal", nr)
    NR = nr.reshape(-1, 3).astype(np.float64)
    idx_all, pos_all, nrm_all = [], [], []
    for tl, tv in zip(tri_l, tri_v):
        P = UV[tl] * res
        x0, y0 = np.floor(P.min(0)).astype(int)
        x1, y1 = np.ceil(P.max(0)).astype(int)
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        xs, ys = xs.ravel(), ys.ravel()
        a, b, c = P
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12:
            continue
        w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        w2 = 1 - w0 - w1
        m = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
        if not m.any():
            continue
        W = np.stack([w0[m], w1[m], w2[m]], 1)
        px = np.floor(xs[m]).astype(int) % res
        py = np.clip(np.floor(ys[m]).astype(int), 0, res - 1)
        idx_all.append(py * res + px)
        pos_all.append(W @ CO[tv])
        nrm_all.append(W @ NR[tv])
    return np.concatenate(idx_all), np.concatenate(pos_all), np.concatenate(nrm_all)


def dilate(img, mask, it=8):
    """Allarga i colori oltre i bordi delle isole UV (evita righe sulle cuciture)."""
    for _ in range(it):
        acc = np.zeros_like(img)
        cnt = np.zeros(mask.shape, np.float32)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            acc += np.roll(np.roll(img * mask[..., None], dx, 1), dy, 0)
            cnt += np.roll(np.roll(mask, dx, 1), dy, 0)
        grow = (cnt > 0) & (mask == 0)
        img[grow] = acc[grow] / cnt[grow][:, None]
        mask = mask.copy()
        mask[grow] = 1
    return img


def vnoise(p, scale, seed=0):
    """Rumore di valore 3D (numpy), valori in 0..1."""
    rng = np.random.default_rng(seed)
    G = rng.random((64, 64, 64)).astype(np.float32)
    q = p * scale
    i = np.floor(q).astype(int)
    f = q - i
    f = f * f * (3 - 2 * f)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + w * G[(i[:, 0] + dx) % 64, (i[:, 1] + dy) % 64, (i[:, 2] + dz) % 64]
    return out


def bake_paint(ob, res, paint, name, path, uvname="UVMap"):
    """paint(pos, nrm) -> colori lineari (N, 3). Scrive la texture e la restituisce."""
    idx, pos, nrm = rasterize(ob, res, uvname)
    col = paint(pos, nrm)
    img = np.zeros((res * res, 3), np.float32)
    mask = np.zeros(res * res, np.float32)
    img[idx] = col
    mask[idx] = 1
    img = dilate(img.reshape(res, res, 3), mask.reshape(res, res), it=6)
    rgba = np.ones((res, res, 4), np.float32)
    rgba[..., :3] = lin2srgb(img)
    return save_rgba(name, rgba[::-1], path)
