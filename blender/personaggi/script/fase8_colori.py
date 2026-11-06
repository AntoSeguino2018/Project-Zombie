"""Fase 8 del Personaggio N.1: colori definitivi (materiali piatti) e sfaccettatura.

Colori (skill blender-pbr-materials, valori in references/pbr-values.md):
- metallo solo 0 o 1; i metalli hanno il colore di base chiaro (acciaio, sRGB ~200);
- il "metallo scuro" (bulloni, giunti, fasce) diventa metallo verniciato scuro, che conta come
  non metallo: un metallo con il colore di base scuro non esiste;
- i non metalli stanno tra sRGB 30 e 240: niente nero puro (maglia e cargo sono antracite, l'ombra
  degli occhi è il minimo, 30);
- pelle mediterranea tra i valori misurati della pelle chiara e di quella scura.
I colori sono scritti qui in sRGB (come in un programma di disegno) e convertiti in lineare.

Sfaccettatura (scelta nella fase 2): Decimate *collapse* simmetrico in X, rapporto 0,45, prima
dell'Armature (e del Solidify sui vestiti), così l'export la applica e i pesi la seguono.
Sul corpo va dopo le maschere: si sfaccetta solo la pelle che si vede. Con `--viso protetto`
il viso (gruppo `N1_Viso`) è escluso, per non perdere i tratti; con `--viso bordi` (scelta definitiva)
sono esclusi solo i vertici dove si incontrano due colori, così le zone del viso tengono la forma.

Va lanciato dopo fase7_capelli.py:
    python -B .claude/skills/blender-core/scripts/run_in_blender.py --blend blender/personaggi/personaggio_n1.blend blender/personaggi/script/fase8_colori.py [-- --viso bordi|protetto|sfaccettato --prova]
--prova: non salva, riporta solo i triangoli.
"""
import bpy, json, math, os, sys

PROGETTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
sys.path.insert(0, os.path.join(PROGETTO, ".claude", "skills", "blender-core", "scripts"))
import _bpyx as bx      # noqa: E402

RAPPORTO = 0.45
VISO = "bordi"           # deciso con lo sviluppatore nella fase 8: sfaccettato, con i bordi dei colori protetti

# nome: (colore sRGB 0-255, metallo, ruvidità)
TAVOLOZZA = {
    "M_N1_Pelle": ((214, 166, 138), 0, 0.55),          # mediterranea chiara, dalle foto dello sviluppatore
    "M_N1_Ombra": ((30, 28, 28), 0, 1.0),              # zona d'ombra degli occhi: il minimo ammesso
    "M_N1_Bocca": ((112, 64, 54), 0, 0.6),             # spenta: una linea, non una bocca aperta
    "M_N1_Barba": ((70, 48, 35), 0, 0.85),             # baffi, pizzetto e sopracciglia: scuri come nelle foto
    "M_N1_Barbetta": ((150, 112, 90), 0, 0.85),        # barba corta su mascella e collo: tra pelle e barba
    "M_N1_Capelli": ((58, 40, 29), 0, 0.7),            # castano scuro
    "M_N1_Rasato": ((118, 84, 64), 0, 0.8),            # sfumatura: tra pelle e castano
    "M_N1_Pelliccia": ((86, 60, 41), 0, 0.95),         # marrone scuro
    "M_N1_Maglia": ((40, 40, 42), 0, 0.85),            # nera (antracite)
    "M_N1_Cargo": ((50, 49, 46), 0, 0.9),              # nera, appena più calda della maglia
    "M_N1_Cuoio": ((110, 66, 36), 0, 0.55),            # cintura
    "M_N1_ScarponeNero": ((44, 42, 40), 0, 0.6),
    "M_N1_ScarponeMarrone": ((120, 76, 42), 0, 0.6),
    "M_N1_Suola": ((84, 56, 36), 0, 0.9),
    "M_N1_Acciaio": ((205, 207, 210), 1, 0.35),        # acciaio chiaro pulito
    "M_N1_MetalloScuro": ((52, 53, 56), 0, 0.45),      # metallo verniciato scuro: non metallo
}
# oggetti da sfaccettare (organici); i pezzi rigidi e già sfaccettati restano come sono
SFACCETTA = ("N1_Corpo", "N1_Maglia", "N1_Cargo", "N1_Scarponi", "N1_Cintura")
PIATTE = ("N1_Suole",)     # quasi solo facce piatte: Decimate planare


def lineare(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def argomenti():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    viso = a[a.index("--viso") + 1] if "--viso" in a else VISO
    return viso, "--prova" in a


def colori():
    fatti = {}
    for nome, (srgb, metallo, ruvido) in TAVOLOZZA.items():
        m = bpy.data.materials.get(nome)
        if m is None:
            continue
        col = tuple(lineare(c) for c in srgb)
        m.diffuse_color = (*col, 1.0)
        m.metallic, m.roughness = float(metallo), ruvido
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (*col, 1.0)
            bsdf.inputs["Metallic"].default_value = float(metallo)
            bsdf.inputs["Roughness"].default_value = ruvido
        fatti[nome] = [round(c, 3) for c in col]
    return fatti


def gruppo_viso(corpo, viso):
    """Vertici protetti dalla sfaccettatura.
    protetto: tutto il viso (davanti alla testa, dal mento all'attaccatura);
    bordi: solo i vertici della testa dove si incontrano due colori (ombra degli occhi, bocca, barba,
    attaccatura e sfumatura dei capelli) e quelli del naso, così le zone e il naso tengono la forma
    e il resto si sfaccetta."""
    me = corpo.data
    vg = corpo.vertex_groups.get("N1_Viso") or corpo.vertex_groups.new(name="N1_Viso")
    vg.remove(range(len(me.vertices)))
    if viso == "bordi":
        mat_v = [set() for _ in me.vertices]
        for p in me.polygons:
            for i in p.vertices:
                mat_v[i].add(p.material_index)
        scelti = [v.index for v in me.vertices if v.co.z > 1.44 and len(mat_v[v.index]) > 1]
        # e il naso, che sfaccettato sparisce, e le fasce d'ombra degli occhi intere (sfaccettate si sfrangiano)
        scelti += [v.index for v in me.vertices
                   if abs(v.co.x) < 0.028 and 1.525 < v.co.z < 1.600 and v.co.y < -0.088]
        scelti += [v.index for v in me.vertices
                   if 0.008 < abs(v.co.x) < 0.072 and 1.565 < v.co.z < 1.610 and v.co.y < -0.040]
    else:
        scelti = [v.index for v in me.vertices if 1.455 < v.co.z < 1.665 and v.co.y < -0.02 and abs(v.co.x) < 0.080]
    vg.add(scelti, 1.0, "REPLACE")
    return vg.name, len(scelti)


def sfaccetta(ob, viso):
    for m in [m for m in ob.modifiers if m.name == "Faccette"]:
        ob.modifiers.remove(m)
    d = ob.modifiers.new("Faccette", "DECIMATE")
    d.decimate_type = "COLLAPSE"
    d.ratio = RAPPORTO
    d.use_symmetry, d.symmetry_axis = True, "X"
    if ob.name == "N1_Corpo" and viso in ("protetto", "bordi"):
        d.vertex_group = "N1_Viso"
        d.invert_vertex_group = True       # il gruppo protegge invece di indicare cosa ridurre
    # posizione: sul corpo dopo le maschere e prima dell'Armature; sui vestiti prima dello spessore
    nomi = [m.name for m in ob.modifiers]
    if ob.name == "N1_Corpo":
        arm = nomi.index("Armature")
        ob.modifiers.move(nomi.index("Faccette"), len(nomi) - 1)
        ob.modifiers.move(arm, len(nomi) - 1)
    else:
        ob.modifiers.move(nomi.index("Faccette"), 0)
        # lo spessore sulla mesh sfaccettata: "offset uniforme" più "normali di qualità" mandavano un
        # vertice del cargo a 224 m (z -21 m). Una delle due da sola va bene: si tolgono le normali di qualità.
        for m in ob.modifiers:
            if m.type == "SOLIDIFY":
                m.use_quality_normals = False
    return [m.name for m in ob.modifiers]


def piatte(ob):
    """Decimate planare (skill blender-game-optimization): toglie i lati sulle facce piatte senza
    cambiare la forma. Per le suole, fatte quasi solo di facce piatte."""
    for m in [m for m in ob.modifiers if m.name == "Piatte"]:
        ob.modifiers.remove(m)
    d = ob.modifiers.new("Piatte", "DECIMATE")
    d.decimate_type = "DISSOLVE"
    d.angle_limit = math.radians(3)
    d.delimit = {"MATERIAL", "SEAM"}
    nomi = [m.name for m in ob.modifiers]
    ob.modifiers.move(nomi.index("Piatte"), 0)
    return [m.name for m in ob.modifiers]


def run():
    viso, prova = argomenti()
    bx.object_mode()
    sc = bpy.context.scene
    sc.frame_set(1)
    out = {"viso": viso, "colori": colori()}
    corpo = bpy.data.objects["N1_Corpo"]
    out["gruppo_viso"] = gruppo_viso(corpo, viso)
    out["pile"] = {n: sfaccetta(bpy.data.objects[n], viso) for n in SFACCETTA}
    out["pile"].update({n: piatte(bpy.data.objects[n]) for n in PIATTE})
    tutti = [o for c in bpy.data.collections if c.name.startswith("N1_") and c.name not in ("N1_Riferimenti", "N1_Guide", "N1_Alto")
             for o in c.all_objects if o.type == "MESH" and not o.name.startswith("WGT-")]
    out["triangoli"] = {o.name: bx.mesh_tris(o) for o in tutti}
    out["triangoli_totale"] = sum(out["triangoli"].values())
    out["materiali"] = len({m.name for o in tutti for m in o.data.materials if m})
    if not prova:
        for o in sc.objects:
            o.select_set(False)
        bpy.ops.wm.save_mainfile(compress=True)
    return {"ok": True, **out}


print("@@JSON@@" + json.dumps(run(), default=str))
