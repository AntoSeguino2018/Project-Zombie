# Genera game/levels/campus.tscn: "Monte Sant'Arcangelo", il campus dell'università
# "Federico III" (ispirato al complesso di Monte Sant'Angelo), in greybox.
#
# La mappa è divisa in zone (MapZone) che sono anche i "chunk" per la rete e le
# ondate (ZoneManager). Si parte dall'aula studio sotterranea e si aprono le altre
# zone comprando le porte (ZoneDoor). In cima alla torre c'è il tetto (elicottero,
# passo 4.2).
#
# Assi: X verso est, Z verso sud (nord = -Z), Y in alto. Unità: metri.
# Uso (dalla cartella del progetto): python tools/build_campus.py
# Attenzione: riscrive la scena da zero; le modifiche fatte a mano nell'editor
# vanno riportate qui, oppure da quel momento si lavora solo nell'editor.
import math, os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "levels", "campus.tscn")

WALL_T = 0.5
DOOR = 4.0          # larghezza delle aperture con porta
PROP_RANGE = 70.0   # gli oggetti piccoli non si disegnano oltre questa distanza

ext = []
nodes = []
counter = {}
stats = {"forme": 0}


def res(kind, path):
    for k, p, i in ext:
        if p == path:
            return i
    i = f"{len(ext) + 1}_{os.path.splitext(os.path.basename(path))[0]}"
    ext.append((kind, path, i))
    return i


MAT = {m: res("Material", f"res://assets/materials/greybox_{m}.tres")
       for m in ("floor", "wall", "accent", "danger", "yellow", "green", "blue", "dark", "tile", "white", "concrete")}


def f(v):
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def basis_yaw(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [c, 0, s, 0, 1, 0, -s, 0, c]


def transform(pos, basis=None):
    b = basis or [1, 0, 0, 0, 1, 0, 0, 0, 1]
    return "Transform3D(%s)" % ", ".join(f(v) for v in b + list(pos))


def unique(name):
    counter[name] = counter.get(name, 0) + 1
    return name if counter[name] == 1 else f"{name}{counter[name]}"


def node(text):
    nodes.append(text.strip("\n") + "\n")


def box(parent, name, center, size, mat, basis=None, collide=True, prop=False):
    """Una forma CSG. prop: oggetto piccolo, non si disegna da lontano."""
    stats["forme"] += 1
    node(f'''[node name="{unique(name)}" type="CSGBox3D" parent="{parent}"]
transform = {transform(center, basis)}
use_collision = {"true" if collide else "false"}
size = Vector3({f(size[0])}, {f(size[1])}, {f(size[2])})
material = ExtResource("{MAT[mat]}")
{"visibility_range_end = %s" % f(PROP_RANGE) if prop else ""}''')


def span(a0, a1, cuts):
    """Tratti pieni da a0 ad a1 lasciando le aperture cuts = [(centro, larghezza)]."""
    out, start = [], a0
    for c, w in sorted(cuts):
        end = c - w / 2
        if end - start > 0.05:
            out.append((start, end))
        start = c + w / 2
    if a1 - start > 0.05:
        out.append((start, a1))
    return out


def wall_x(parent, name, z, x0, x1, doors=(), h=8.0, y0=0.0, mat="concrete", t=WALL_T):
    """Muro lungo X alla quota z. doors: centri delle aperture (larghe DOOR) o (centro, larghezza)."""
    cuts = [d if isinstance(d, tuple) else (d, DOOR) for d in doors]
    for a, b in span(x0, x1, cuts):
        box(parent, name, ((a + b) / 2, y0 + h / 2, z), (b - a, h, t), mat)


def wall_z(parent, name, x, z0, z1, doors=(), h=8.0, y0=0.0, mat="concrete", t=WALL_T):
    cuts = [d if isinstance(d, tuple) else (d, DOOR) for d in doors]
    for a, b in span(z0, z1, cuts):
        box(parent, name, (x, y0 + h / 2, (a + b) / 2), (t, h, b - a), mat)


def slab(parent, name, x0, x1, z0, z1, mat, top=0.0, t=1.0):
    """Pavimento (o soffitto) da x0 a x1 e da z0 a z1, con la faccia di sopra a top."""
    box(parent, name, ((x0 + x1) / 2, top - t / 2, (z0 + z1) / 2), (x1 - x0, t, z1 - z0), mat)


def slab_between(parent, name, a, b, width, t=0.4, mat="accent", collide=True, prop=False):
    """Piano inclinato largo width con la faccia di sopra da a = (x, y, z) a b."""
    dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    along = (dx / length, dy / length, dz / length)
    hx, hz = dx, dz
    hl = math.hypot(hx, hz)
    side = (-hz / hl, 0.0, hx / hl)          # orizzontale, perpendicolare
    # normale = along x side (verso l'alto)
    nx = along[1] * side[2] - along[2] * side[1]
    ny = along[2] * side[0] - along[0] * side[2]
    nz = along[0] * side[1] - along[1] * side[0]
    if ny < 0:
        side = (-side[0], 0.0, -side[2])
        nx, ny, nz = -nx, -ny, -nz
    center = ((a[0] + b[0]) / 2 - nx * t / 2, (a[1] + b[1]) / 2 - ny * t / 2, (a[2] + b[2]) / 2 - nz * t / 2)
    basis = [side[0], nx, along[0], side[1], ny, along[1], side[2], nz, along[2]]
    box(parent, name, center, (width, t, length), mat, basis, collide, prop)


def stairs(parent, name, a, b, width, step=0.45, mat="accent"):
    """Scala: rampa con collisione (gli zombie e la navigazione la usano) e gradini solo visivi."""
    slab_between(parent, name + "Rampa", a, b, width, mat=mat)
    run = math.hypot(b[0] - a[0], b[2] - a[2])
    n = max(int(run / step), 1)
    ux, uz = (b[0] - a[0]) / run, (b[2] - a[2]) / run
    rise = (b[1] - a[1]) / n
    yaw = math.degrees(math.atan2(ux, uz))
    for i in range(n):
        cx = a[0] + ux * (i + 0.5) * run / n
        cz = a[2] + uz * (i + 0.5) * run / n
        top = a[1] + rise * (i + 1)
        box(parent, name + "Gradino", (cx, top - 0.12, cz), (width, 0.24, run / n), mat,
            basis_yaw(yaw), collide=False, prop=True)


def railing_between(parent, name, a, b, h=1.1):
    """Ringhiera inclinata: una lastra sottile in verticale sopra la linea da a a b."""
    slab_between(parent, name, (a[0], a[1] + h, a[2]), (b[0], b[1] + h, b[2]), 0.15, t=h, mat="dark")


lights = []
labels = []
spawns = []
crates = []
machines = []
doors = []
zones = []
destructibles = []

G = "Geometry"

# =============================================================================
# Aula studio sotterranea (partenza): X -10..10, Z 62..90, pavimento a -6.
# Guardando l'uscita (a nord) la lavagna bianca occupa tutta la parete sinistra (ovest).
# =============================================================================
AY = -6.0
slab(G, "PavimentoAula", -10, 10, 46, 90, "floor", top=AY)
slab(G, "SoffittoAula", -10.5, 10.5, 60, 90.5, "concrete", top=0.0)
wall_z(G, "MuroAulaOvest", -10, 62, 90, h=5, y0=AY, mat="yellow")
wall_z(G, "MuroAulaEst", 10, 62, 90, h=5, y0=AY, mat="yellow")
wall_x(G, "MuroAulaSud", 90, -10, 10, h=5, y0=AY, mat="yellow")
wall_x(G, "MuroAulaNord", 62, -10, 10, doors=[(0, 5.5)], h=5, y0=AY, mat="yellow")
# lavagna enorme: tutta la parete ovest, con cornice e vaschetta dei pennarelli
box(G, "Lavagna", (-9.68, AY + 2.4, 76), (0.12, 2.8, 27), "white")
box(G, "LavagnaCornice", (-9.7, AY + 3.85, 76), (0.16, 0.1, 27.2), "dark")
box(G, "LavagnaCornice", (-9.7, AY + 0.95, 76), (0.16, 0.1, 27.2), "dark")
box(G, "LavagnaVaschetta", (-9.5, AY + 0.95, 76), (0.25, 0.06, 26), "dark", prop=True)
for z in (66, 70, 74, 78, 82, 86):
    for x in (-4.5, 4.5):
        box(G, "TavoloAula", (x, AY + 0.4, z), (5, 0.8, 1.6), "yellow", prop=True)
        for dx in (-1.5, 0, 1.5):
            box(G, "SediaAula", (x + dx, AY + 0.25, z + 1.3), (0.5, 0.5, 0.5), "accent", prop=True)
box(G, "Cattedra", (0, AY + 0.5, 64.5), (3.5, 1.0, 1.2), "accent", prop=True)
for x in (-8.6, 8.6):    # prese d'aria: da qui entrano gli zombie
    box(G, "PresaAria", (x, AY + 0.6, 89.65), (1.6, 1.2, 0.2), "dark", collide=False)
    spawns.append(("Aula", (x, AY, 88.2), "aula"))
for z in (68, 78, 87):
    lights.append(((0, AY + 4.5, z), (1.0, 0.92, 0.75), 14.0, 1.3))
# scala verso i Centri comuni: dall'uscita (Z 62, -6) al piano terra (Z 48, 0)
stairs(G, "ScalaAula", (0, AY, 62), (0, 0, 48), 5.0)
wall_z(G, "MuroScalaOvest", -2.75, 46, 62, h=5.5, y0=AY, mat="concrete")
wall_z(G, "MuroScalaEst", 2.75, 46, 62, h=5.5, y0=AY, mat="concrete")
box(G, "SottoScala", (0, AY / 2 - 0.5, 46.5), (5.5, -AY - 1, 1.0), "concrete")
lights.append(((0, -2.0, 55), (1.0, 0.95, 0.85), 10.0, 1.0))
zones.append(("aula", "Aula studio", True, [(-10, -8, 46, 20, 7.4, 44)], ["centri"]))
labels.append(("Aula studio", (0, AY + 4.3, 62.4)))

# =============================================================================
# Centri comuni (atrio, partenza): X -30..30, Z 12..60. Buco della scala X ±2.5, Z 48..60.
# =============================================================================
slab(G, "PavimentoCentri", -30, 30, 12, 48, "tile")
slab(G, "PavimentoCentri", -30, -2.5, 48, 60, "tile")
slab(G, "PavimentoCentri", 2.5, 30, 48, 60, "tile")
wall_z(G, "RingheraScala", -2.75, 48, 60, h=1.1, mat="dark", t=0.15)
wall_z(G, "RingheraScala", 2.75, 48, 60, h=1.1, mat="dark", t=0.15)
wall_x(G, "MuroCentriSud", 60, -30, 30, h=8)
for x in (-18, -6, 6, 18):
    for z in (22, 36):
        box(G, "PilastroCentri", (x, 4, z), (1.4, 8, 1.4), "concrete")
box(G, "BanconeCentri", (-14, 0.55, 50), (8, 1.1, 1.5), "accent", prop=True)
for x, z in [(12, 28), (12, 44), (-12, 28)]:
    box(G, "Panca", (x, 0.25, z), (4, 0.5, 0.8), "accent", prop=True)
spawns += [("Centri", (-27, 0, 15), "centri"), ("Centri", (27, 0, 15), "centri"),
           ("Centri", (-27, 0, 57), "centri"), ("Centri", (27, 0, 57), "centri")]
crates.append(("CassaCentri", (24, 0, 22), -90))
machines.append(("MerendinaCentri", (-6, 0, 59.1), 180, "merendina"))
zones.append(("centri", "Centri comuni", True, [(-30, -0.6, 12, 60, 11.6, 48)], ["aula", "viale_ovest", "viale_est", "mensa", "parcheggio"]))
labels.append(("Centri comuni", (0, 6, 30)))

# =============================================================================
# Viale centrale: X -115..115, Z -12..12, con la passerella a 4 m. Due zone (ovest/est).
# =============================================================================
slab(G, "PavimentoViale", -115, 115, -12, 12, "floor")
wall_z(G, "MuroVialeOvest", -115, -12, 12)
wall_z(G, "MuroVialeEst", 115, -12, 12)
# muro nord (verso aulario, biblioteca, torre) e sud (verso mensa, centri, parcheggio)
wall_x(G, "MuroVialeNord", -12, -115, 115, doors=[-66, 0, 75])
wall_x(G, "MuroVialeSud", 12, -115, 115, doors=[-75, 0, 75])
# passerella sopraelevata: Z -6..-2 a 4 m, da X -60 a 60, con le rampe alle estremità
slab(G, "Passerella", -60, 60, -6, -2, "concrete", top=4.0, t=0.5)
for x in range(-55, 60, 10):
    box(G, "PilastroPasserella", (x, 1.875, -4), (0.8, 3.75, 0.8), "concrete")
wall_x(G, "RingheraPasserella", -6.1, -60, 60, h=1.1, y0=4.0, mat="dark", t=0.15)
wall_x(G, "RingheraPasserella", -1.9, -60, 60, h=1.1, y0=4.0, mat="dark", t=0.15)
stairs(G, "ScalaPasserellaOvest", (-60, 4, -4), (-72, 0, -4), 4.0)
stairs(G, "ScalaPasserellaEst", (60, 4, -4), (72, 0, -4), 4.0)
for x in (-95, -40, -20, 20, 40, 95):
    box(G, "Aiuola", (x, 0.45, 7), (4, 0.9, 2.5), "green", prop=True)
    box(G, "Albero", (x, 2.5, 7), (0.7, 5, 0.7), "accent", prop=True)
for x in (-105, -85, -50, -30, 30, 50, 85, 105):
    box(G, "Lampione", (x, 2.5, -10.5), (0.25, 5, 0.25), "dark", prop=True)
destructibles += [("MurettoVialeA", (-30, 0, 2), 0, (6, 1.6, 0.5), (0.65, 0.63, 0.6)),
                  ("MurettoVialeB", (30, 0, 3), 0, (6, 1.6, 0.5), (0.65, 0.63, 0.6)),
                  ("MurettoVialeC", (90, 0, -3), 90, (5, 1.6, 0.5), (0.65, 0.63, 0.6))]
spawns += [("VialeOvest", (-112, 0, 0), "viale_ovest"), ("VialeOvest", (-45, 0, 9), "viale_ovest"),
           ("VialeOvest", (-90, 0, -9), "viale_ovest"),
           ("VialeEst", (112, 0, 0), "viale_est"), ("VialeEst", (45, 0, 9), "viale_est"),
           ("VialeEst", (95, 0, -9), "viale_est")]
crates.append(("CassaViale", (-100, 0, 9.5), 180))
machines.append(("EspressoViale", (55, 0, 11.1), 180, "espresso"))
zones.append(("viale_ovest", "Viale", False, [(-115, -0.6, -12, 115, 11.6, 24)],
              ["viale_est", "centri", "mensa", "aulario", "biblioteca"]))
zones.append(("viale_est", "Viale", False, [(0, -0.6, -12, 115, 11.6, 24)],
              ["viale_ovest", "centri", "parcheggio", "biblioteca", "torre"]))
labels += [("Viale", (-30, 6.5, 0)), ("Viale", (30, 6.5, 0))]

# =============================================================================
# Mensa e bar: X -115..-30, Z 12..60.
# =============================================================================
slab(G, "PavimentoMensa", -115, -30, 12, 60, "tile")
wall_z(G, "MuroMensaOvest", -115, 12, 60)
wall_x(G, "MuroMensaSud", 60, -115, -30)
wall_z(G, "MuroMensaCentri", -30, 12, 60, doors=[36])
for x in (-100, -88, -76, -64):
    for z in (22, 32, 42):
        box(G, "TavoloMensa", (x, 0.4, z), (6, 0.8, 2), "blue", prop=True)
box(G, "BanconeMensa", (-50, 0.55, 52), (18, 1.1, 1.6), "accent")
wall_z(G, "MuroCucina", -42, 12, 44, doors=[(28, 4)], h=4, mat="wall")
machines += [("EspressoMensa", (-58, 0, 59.1), 180, "espresso"),
             ("DoppioMensa", (-56.8, 0, 59.1), 180, "doppio"),
             ("MerendinaMensa", (-55.6, 0, 59.1), 180, "merendina")]
crates.append(("CassaMensa", (-110, 0, 55), 0))
spawns += [("Mensa", (-112, 0, 15), "mensa"), ("Mensa", (-112, 0, 57), "mensa"),
           ("Mensa", (-36, 0, 15), "mensa"), ("Mensa", (-80, 0, 57), "mensa")]
zones.append(("mensa", "Mensa", False, [(-115, -0.6, 12, 85, 11.6, 48)], ["centri", "viale_ovest"]))
labels.append(("Mensa e bar", (-72, 6, 36)))

# =============================================================================
# Aulario: X -115..-35, Z -85..-12. Corridoio Z -48..-42, quattro aule a nord e quattro a sud.
# =============================================================================
slab(G, "PavimentoAulario", -115, -35, -85, -12, "floor")
wall_z(G, "MuroAularioOvest", -115, -85, -12)
wall_x(G, "MuroAularioNord", -85, -115, -35)
wall_z(G, "MuroAularioBiblioteca", -35, -85, -12, doors=[-45])
room_x = [(-115, -96), (-96, -76), (-76, -56), (-56, -35)]
mids = [(a + b) / 2 for a, b in room_x]
wall_x(G, "MuroCorridoioNord", -48, -115, -35, doors=[(m, 3) for m in mids], h=5, mat="yellow")
wall_x(G, "MuroCorridoioSud", -42, -115, -35, doors=[(m, 3) for m in mids], h=5, mat="yellow")
for x in (-96, -76, -56):
    wall_z(G, "MuroAula", x, -85, -48, h=5, mat="yellow")
    wall_z(G, "MuroAula", x, -42, -12, h=5, mat="yellow")
for i, (a, b) in enumerate(room_x):
    m = (a + b) / 2
    for z0, z1, nome in ((-85, -48, f"A{i + 1}"), (-42, -12, f"A{i + 5}")):
        # lavagna: a nord sulla parete di fondo, a sud su quella laterale (sulle altre ci sono le porte)
        if z0 == -85:
            box(G, "LavagnaAula", (m, 2.2, -84.6), (8, 2, 0.12), "white", prop=True)
        else:
            box(G, "LavagnaAula", (a + 0.4, 2.2, (z0 + z1) / 2), (0.12, 2, 8), "white", prop=True)
        for z in range(int(z0) + 9, int(z1) - 2, 5):
            box(G, "BancoAula", (m, 0.4, z), (b - a - 6, 0.8, 1.2), "yellow", prop=True)
        labels.append((nome, (m, 4.2, (z0 + z1) / 2)))
spawns += [("Aulario", (-112, 0, -82), "aulario"), ("Aulario", (-38, 0, -82), "aulario"),
           ("Aulario", (-112, 0, -15), "aulario"), ("Aulario", (-100, 0, -45), "aulario")]
crates.append(("CassaAulario", (-110, 0, -80), 90))
zones.append(("aulario", "Aulario", False, [(-115, -0.6, -85, 80, 11.6, 73)], ["viale_ovest", "biblioteca"]))
labels.append(("Aulario", (-75, 6.5, -45)))

# =============================================================================
# Biblioteca: X -35..35, Z -85..-12, con il soppalco a 4 m sul lato nord.
# =============================================================================
slab(G, "PavimentoBiblioteca", -35, 35, -85, -12, "floor")
wall_x(G, "MuroBibliotecaNord", -85, -35, 35)
wall_z(G, "MuroBibliotecaTorre", 35, -85, -12, doors=[-45])
slab(G, "Soppalco", -34.75, 34.75, -84.75, -72, "wall", top=4.0, t=0.5)
for x in (-25, -10, 10, 25):
    box(G, "PilastroSoppalco", (x, 1.875, -72.5), (0.8, 3.75, 0.8), "concrete")
wall_x(G, "RingheraSoppalco", -71.9, -34.75, 34.75, doors=[(-20, 4.4), (20, 4.4)], h=1.1, y0=4.0, mat="dark", t=0.15)
stairs(G, "ScalaSoppalco", (-20, 0, -58), (-20, 4, -71.9), 4.0)
stairs(G, "ScalaSoppalco", (20, 0, -58), (20, 4, -71.9), 4.0)
for z in (-20, -26, -32, -38, -44, -50):
    for x in (-27, -9, 9, 27):
        box(G, "Scaffale", (x, 1.6, z), (10, 3.2, 1.0), "blue", prop=True)
for x in (-24, -8, 8, 24):
    box(G, "Scaffale", (x, 4 + 1.4, -80), (10, 2.8, 1.0), "blue", prop=True)
for x in (-6, 6):
    box(G, "TavoloLettura", (x, 0.4, -62), (4, 0.8, 6), "accent", prop=True)
crates.append(("CassaSoppalco", (0, 4, -83), 0))
spawns += [("Biblioteca", (-32, 0, -82), "biblioteca"), ("Biblioteca", (32, 0, -82), "biblioteca"),
           ("Biblioteca", (-32, 0, -15), "biblioteca"), ("Biblioteca", (32, 0, -15), "biblioteca")]
zones.append(("biblioteca", "Biblioteca", False, [(-35, -0.6, -85, 70, 11.6, 73)], ["viale_ovest", "viale_est", "aulario", "torre"]))
labels.append(("Biblioteca", (0, 7.5, -45)))

# =============================================================================
# Torre dei dipartimenti: zona X 35..115, Z -85..-12 (piazzale + piano terra).
# Edificio X 55..95, Z -75..-35, alto 12 m, scale interne fino al tetto.
# =============================================================================
TY = 12.0
slab(G, "PavimentoTorre", 35, 115, -85, -12, "floor")
wall_x(G, "MuroTorreNord", -85, 35, 115)
wall_z(G, "MuroTorreEst", 115, -85, -12)
# l'edificio
wall_x(G, "FacciataNord", -75, 55, 95, h=TY)
wall_x(G, "FacciataSud", -35, 55, 95, doors=[(75, 6)], h=TY)
box(G, "Architrave", (75, (4 + TY) / 2, -35), (6, TY - 4, WALL_T), "concrete")
wall_z(G, "FacciataOvest", 55, -75, -35, h=TY)
wall_z(G, "FacciataEst", 95, -75, -35, h=TY)
for y in (4, 8):     # fasce delle finestre
    for z_face in (-75.3, -34.7):
        box(G, "FasciaFinestre", (75, y + 1.2, z_face), (38, 1.2, 0.12), "blue", collide=False)
# scale: prima rampa lungo la parete ovest (X 56..60) verso nord, pianerottolo, seconda rampa (X 62..66) verso sud
stairs(G, "ScalaTorre1", (58, 0, -38), (58, 6, -48.4), 4.0)
slab(G, "Pianerottolo", 55.25, 66.5, -53.4, -48.4, "concrete", top=6.0, t=0.5)
stairs(G, "ScalaTorre2", (64, 6, -48.4), (64, TY, -38), 4.0)
# alte 1,8 m: dal pianerottolo non si salta sulla rampa aggirando la porta del tetto
railing_between(G, "RingheraScalaTorre", (61.9, 6, -48.4), (61.9, TY, -38), h=1.8)
railing_between(G, "RingheraScalaTorre", (66.1, 6, -48.4), (66.1, TY, -38), h=1.8)
# tetto con il buco sopra la seconda rampa (X 62..66, Z -48.4..-38)
slab(G, "Tetto", 55, 62, -75, -35, "concrete", top=TY, t=0.5)
slab(G, "Tetto", 66, 95, -75, -35, "concrete", top=TY, t=0.5)
slab(G, "Tetto", 62, 66, -75, -48.4, "concrete", top=TY, t=0.5)
slab(G, "Tetto", 62, 66, -38, -35, "concrete", top=TY, t=0.5)
wall_x(G, "Parapetto", -74.9, 55, 95, h=1.2, y0=TY, mat="concrete", t=0.3)
wall_x(G, "Parapetto", -35.1, 55, 95, h=1.2, y0=TY, mat="concrete", t=0.3)
wall_z(G, "Parapetto", 55.1, -75, -35, h=1.2, y0=TY, mat="concrete", t=0.3)
wall_z(G, "Parapetto", 94.9, -75, -35, h=1.2, y0=TY, mat="concrete", t=0.3)
wall_x(G, "RingheraBotola", -48.3, 61.9, 66.1, h=1.1, y0=TY, mat="dark", t=0.15)
box(G, "Eliporto", (80, TY + 0.03, -55), (14, 0.06, 14), "danger", collide=False)
# l'elicottero (passo 3.8): sull'eliporto, con la radio dell'esercito vicino alla botola
HELI = ((80, TY, -55), (-12, 0, 12))
for x in (72, 88):
    for z in (-65, -45):
        box(G, "PilastroTorre", (x, TY / 2 - 0.25, z), (1.2, TY - 0.5, 1.2), "concrete")
for x, z in [(80, -70), (80, -55), (90, -55)]:
    box(G, "BancoLab", (x, 0.45, z), (6, 0.9, 1.4), "white", prop=True)
for x, z in [(45, -25), (105, -25), (45, -80), (105, -80)]:
    box(G, "Albero", (x, 2.5, z), (0.7, 5, 0.7), "accent", prop=True)
    box(G, "Aiuola", (x, 0.45, z), (3, 0.9, 3), "green", prop=True)
for z in (-42, -55, -68):
    lights.append(((80, 3.6, z), (0.9, 0.95, 1.0), 16.0, 1.2))
crates.append(("CassaTorre", (90, 0, -40), -90))
machines.append(("DoppioTorre", (94.4, 0, -60), -90, "doppio"))
spawns += [("Torre", (38, 0, -82), "torre"), ("Torre", (112, 0, -82), "torre"),
           ("Torre", (112, 0, -15), "torre"), ("Torre", (88, 0, -70), "torre")]
zones.append(("torre", "Torre dei dipartimenti", False,
              [(35, -0.6, -85, 80, 6.0, 73), (55, 5.4, -75, 12, 1.2, 27.6)], ["viale_est", "biblioteca", "tetto"]))
zones.append(("tetto", "Tetto", False, [(55, 11, -75, 40, 9, 40), (61.5, 5.9, -48.4, 5, 6, 10.4)], ["torre"]))
spawns += [("Tetto", (58, TY, -72), "tetto"), ("Tetto", (92, TY, -72), "tetto"), ("Tetto", (92, TY, -38), "tetto")]
labels += [("Torre dei dipartimenti", (75, TY + 4, -34)), ("Tetto", (80, TY + 3, -55))]

# =============================================================================
# Parcheggio e stazione: X 30..115, Z 12..88. Buco della rampa dei laboratori X 100..108, Z 24..42.
# =============================================================================
slab(G, "PavimentoParcheggio", 30, 115, 12, 24, "floor")
slab(G, "PavimentoParcheggio", 30, 100, 24, 42, "floor")
slab(G, "PavimentoParcheggio", 108, 115, 24, 42, "floor")
slab(G, "PavimentoParcheggio", 30, 115, 42, 88, "floor")
wall_z(G, "MuroParcheggioOvest", 30, 12, 88, doors=[36])
wall_z(G, "MuroParcheggioEst", 115, 12, 88)
wall_x(G, "MuroParcheggioSud", 88, 30, 115)
# recinzione alta attorno alla rampa: non si scavalca con un salto (si entra solo dalla porta)
wall_z(G, "RecinzioneRampa", 99.75, 24, 42, h=2.6, mat="dark", t=0.15)
wall_z(G, "RecinzioneRampa", 108.25, 24, 42, h=2.6, mat="dark", t=0.15)
wall_x(G, "RecinzioneRampa", 42, 99.75, 108.25, h=2.6, mat="dark", t=0.15)
for i, (x, z) in enumerate([(40, 20), (46, 20), (52, 20), (40, 32), (46, 32), (60, 50), (66, 50), (72, 50),
                            (60, 62), (78, 62), (84, 62)]):
    box(G, "Auto", (x, 0.7, z), (2, 1.4, 4.4), ["blue", "danger", "accent", "white"][i % 4], prop=True)
    box(G, "AutoTetto", (x, 1.7, z + 0.3), (1.8, 0.6, 2.2), "dark", prop=True)
for x, z in [(90, 22), (88, 75)]:     # camion dell'esercito
    box(G, "Camion", (x, 1.4, z), (3, 2.8, 8), "green")
    box(G, "CamionCabina", (x, 1.2, z - 5), (3, 2.4, 2.4), "dark")
# stazione "Monte Sant'Arcangelo"
wall_x(G, "StazioneNord", 70, 38, 62, doors=[(50, 5)], h=5, mat="wall")
wall_z(G, "StazioneOvest", 38, 70, 88, h=5, mat="wall")
wall_z(G, "StazioneEst", 62, 70, 88, h=5, mat="wall")
slab(G, "StazioneTetto", 37.75, 62.25, 69.75, 88, "concrete", top=5.5, t=0.5)
box(G, "TornelliChiusi", (50, 0.6, 80), (14, 1.2, 0.5), "danger")
lights.append(((50, 4.5, 78), (1.0, 0.85, 0.6), 10.0, 1.0))
crates.append(("CassaParcheggio", (110, 0, 84), 0))
machines.append(("EspressoStazione", (61.4, 0, 82), -90, "espresso"))
destructibles.append(("MurettoParcheggio", (75, 0, 35), 90, (6, 1.8, 0.5), (0.65, 0.63, 0.6)))
spawns += [("Parcheggio", (112, 0, 15), "parcheggio"), ("Parcheggio", (112, 0, 85), "parcheggio"),
           ("Parcheggio", (33, 0, 85), "parcheggio"), ("Parcheggio", (80, 0, 85), "parcheggio"),
           ("Parcheggio", (65, 0, 30), "parcheggio")]
zones.append(("parcheggio", "Parcheggio", False, [(30, -0.6, 12, 85, 11.6, 76)], ["centri", "viale_est", "laboratori"]))
labels += [("Parcheggio", (72, 6, 40)), ("Stazione Monte Sant'Arcangelo", (50, 7, 70))]

# =============================================================================
# Laboratori segreti: sotto il parcheggio, X 50..110, Z 36..80, pavimento a -7.
# Rampa dei mezzi dal parcheggio (X 100..108, Z 24 a quota 0 -> Z 42 a -7).
# =============================================================================
LY = -7.0
slab(G, "PavimentoLab", 50, 110, 36, 80, "tile", top=LY)
slab(G, "PavimentoRampaLab", 99.75, 108.25, 22, 36, "concrete", top=LY)
# il soffitto è il pavimento del parcheggio (spesso 1 m, quindi a -1)
stairs(G, "RampaMezzi", (104, 0, 24), (104, LY, 42), 8.0, mat="concrete")
wall_z(G, "MuroRampaLab", 99.75, 22, 42, h=-LY, y0=LY, mat="concrete")
wall_z(G, "MuroRampaLab", 108.25, 22, 42, h=-LY, y0=LY, mat="concrete")
# fino al soffitto (-1): più alti spunterebbero a filo del parcheggio
wall_x(G, "MuroLabNord", 36, 50, 110, doors=[(104, 8.5)], h=-LY - 1, y0=LY, mat="wall")
wall_x(G, "MuroLabSud", 80, 50, 110, h=-LY - 1, y0=LY, mat="wall")
wall_z(G, "MuroLabOvest", 50, 36, 80, h=-LY - 1, y0=LY, mat="wall")
wall_z(G, "MuroLabEst", 110, 36, 80, h=-LY - 1, y0=LY, mat="wall")
# progetto segreto al centro e banconi
box(G, "ProgettoSegreto", (75, LY + 2, 58), (6, 4, 6), "danger")
box(G, "ProgettoBase", (75, LY + 0.25, 58), (9, 0.5, 9), "dark")
for x, z in [(58, 44), (58, 72), (92, 72), (66, 44)]:
    box(G, "BanconeLab", (x, LY + 0.45, z), (8, 0.9, 1.5), "white", prop=True)
for x, z in [(54, 58), (96, 50), (96, 62)]:
    box(G, "CasseEsercito", (x, LY + 0.6, z), (2.4, 1.2, 2.4), "green", prop=True)
for x, z in [(62, 50), (88, 50), (62, 68), (88, 68)]:
    lights.append(((x, LY + 5.2, z), (0.75, 0.9, 1.0), 16.0, 1.3))
crates.append(("CassaLab", (105, LY, 76), 0))
machines.append(("MerendinaLab", (50.6, LY, 44), 90, "merendina"))
spawns += [("Lab", (52, LY, 78), "laboratori"), ("Lab", (108, LY, 78), "laboratori"),
           ("Lab", (52, LY, 38), "laboratori"), ("Lab", (80, LY, 46), "laboratori")]
zones.append(("laboratori", "Laboratori", False, [(50, -8, 22, 60, 7.4, 58)], ["parcheggio"]))
labels.append(("Laboratori", (75, LY + 5, 40)))

# =============================================================================
# Porte a pagamento: (nome, posizione, yaw, prezzo, zone che apre, dimensioni)
# =============================================================================
doors += [
    ("PortaCentriViale", (0, 0, 12), 0, 250, ["viale_ovest", "viale_est"], (4, 3.2, 0.3)),
    ("PortaCentriMensa", (-30, 0, 36), 90, 300, ["mensa"], (4, 3.2, 0.3)),
    ("PortaCentriParcheggio", (30, 0, 36), 90, 600, ["parcheggio"], (4, 3.2, 0.3)),
    ("PortaVialeMensa", (-75, 0, 12), 0, 300, ["mensa"], (4, 3.2, 0.3)),
    ("PortaVialeParcheggio", (75, 0, 12), 0, 600, ["parcheggio"], (4, 3.2, 0.3)),
    ("PortaVialeAulario", (-66, 0, -12), 0, 400, ["aulario"], (4, 3.2, 0.3)),
    ("PortaVialeBiblioteca", (0, 0, -12), 0, 400, ["biblioteca"], (4, 3.2, 0.3)),
    ("PortaVialeTorre", (75, 0, -12), 0, 750, ["torre"], (4, 3.2, 0.3)),
    ("PortaAularioBiblioteca", (-35, 0, -45), 90, 400, ["aulario", "biblioteca"], (4, 3.2, 0.3)),
    ("PortaBibliotecaTorre", (35, 0, -45), 90, 750, ["biblioteca", "torre"], (4, 3.2, 0.3)),
    ("PortaLaboratori", (104, 0, 23.8), 0, 1000, ["laboratori"], (8.5, 3.6, 0.4)),
    ("PortaTetto", (64, 6, -48.7), 0, 1500, ["tetto"], (4.6, 3.2, 0.3)),
]

# =============================================================================
# Scrittura
# =============================================================================
player = res("PackedScene", "res://game/player/player.tscn")
nav_script = res("Script", "res://game/levels/level_navigation.gd")
walker = res("PackedScene", "res://game/enemies/walker.tscn")
runner = res("PackedScene", "res://game/enemies/runner.tscn")
brute = res("PackedScene", "res://game/enemies/brute.tscn")
player_spawner = res("Script", "res://game/net/player_spawner.gd")
enemy_rep = res("Script", "res://game/net/enemy_replicator.gd")
pickup_rep = res("Script", "res://game/net/pickup_replicator.gd")
weapon_pickup = res("PackedScene", "res://game/pickups/weapon_pickup.tscn")
item_pickup = res("PackedScene", "res://game/pickups/item_pickup.tscn")
crate_scene = res("PackedScene", "res://game/pickups/weapon_crate.tscn")
machine_scene = res("PackedScene", "res://game/pickups/vending_machine.tscn")
waves_script = res("Script", "res://game/waves/wave_director.gd")
walker_wave = res("Resource", "res://game/waves/walker_wave.tres")
runner_wave = res("Resource", "res://game/waves/runner_wave.tres")
brute_wave = res("Resource", "res://game/waves/brute_wave.tres")
run_script = res("Script", "res://game/run/run_manager.gd")
zones_script = res("Script", "res://game/levels/zones/zone_manager.gd")
zone_script = res("Script", "res://game/levels/zones/map_zone.gd")
door_script = res("Script", "res://game/levels/zones/zone_door.gd")
destructible_script = res("Script", "res://game/levels/destructible/destructible_blocks.gd")
heli_script = res("Script", "res://game/levels/props/helicopter.gd")
boosts = {b: res("Resource", f"res://game/boosts/{b}.tres") for b in ("espresso", "doppio", "merendina")}

head = ['[gd_scene format=3]\n']
for kind, path, i in ext:
    head.append(f'[ext_resource type="{kind}" path="{path}" id="{i}"]')
head.append('''
[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_sky"]
sky_horizon_color = Color(0.66, 0.7, 0.78, 1)
ground_horizon_color = Color(0.66, 0.7, 0.78, 1)

[sub_resource type="Sky" id="Sky_main"]
sky_material = SubResource("ProceduralSkyMaterial_sky")

[sub_resource type="Environment" id="Environment_main"]
background_mode = 2
sky = SubResource("Sky_main")
tonemap_mode = 2

[sub_resource type="NavigationMesh" id="NavigationMesh_level"]
geometry_source_geometry_mode = 1
geometry_source_group_name = &"navigation_source"
agent_height = 1.75
agent_radius = 0.75
agent_max_climb = 0.25
agent_max_slope = 40.0
''')

top = f'''[node name="Campus" type="Node3D"]

[node name="PlayerSpawner" type="MultiplayerSpawner" parent="."]
spawn_path = NodePath("../Players")
script = ExtResource("{player_spawner}")
player_scene = ExtResource("{player}")
spawn_origin = Vector3(-1.5, -5.9, 80.4)

[node name="EnemyReplicator" type="MultiplayerSpawner" parent="."]
spawn_path = NodePath("../Enemies")
script = ExtResource("{enemy_rep}")
enemy_scenes = Array[PackedScene]([ExtResource("{walker}"), ExtResource("{runner}"), ExtResource("{brute}")])

[node name="PickupReplicator" type="MultiplayerSpawner" parent="."]
spawn_path = NodePath("../Pickups")
script = ExtResource("{pickup_rep}")
pickup_scene = ExtResource("{weapon_pickup}")
item_scene = ExtResource("{item_pickup}")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_main")

[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866025, -0.383022, 0.321394, 0, 0.642788, 0.766044, -0.5, -0.663414, 0.55667, 0, 10, 0)
shadow_enabled = true
directional_shadow_max_distance = 90.0

[node name="Players" type="Node3D" parent="."]

[node name="Zones" type="Node3D" parent="."]
script = ExtResource("{zones_script}")
'''


def aabb(b):
    return "AABB(%s)" % ", ".join(f(v) for v in b)


for name, title, start, bounds, near in zones:
    top += f'''
[node name="{name}" type="Node3D" parent="Zones"]
script = ExtResource("{zone_script}")
display_name = "{title}"
start_unlocked = {"true" if start else "false"}
bounds = Array[AABB]([{", ".join(aabb(b) for b in bounds)}])
neighbors = Array[StringName]([{", ".join('&"%s"' % n for n in near)}])
'''

top += f'''
[node name="Navigation" type="NavigationRegion3D" parent="."]
navigation_mesh = SubResource("NavigationMesh_level")
script = ExtResource("{nav_script}")

[node name="Geometry" type="Node3D" parent="." groups=["navigation_source"]]
'''

out = "\n".join(head) + "\n" + top + "\n" + "\n".join(nodes)
out += '\n[node name="Doors" type="Node3D" parent="."]\n'
for name, pos, yaw, price, opens, size in doors:
    out += f'''
[node name="{name}" type="StaticBody3D" parent="Doors"]
transform = {transform(pos, basis_yaw(yaw))}
script = ExtResource("{door_script}")
price = {price}
opens = Array[StringName]([{", ".join('&"%s"' % o for o in opens)}])
size = Vector3({f(size[0])}, {f(size[1])}, {f(size[2])})
'''
out += '\n[node name="Destructibles" type="Node3D" parent="." groups=["navigation_source"]]\n'
for name, pos, yaw, size, color in destructibles:
    out += f'''
[node name="{name}" type="Node3D" parent="Destructibles"]
transform = {transform(pos, basis_yaw(yaw))}
script = ExtResource("{destructible_script}")
size = Vector3({f(size[0])}, {f(size[1])}, {f(size[2])})
color = Color({color[0]}, {color[1]}, {color[2]}, 1)
'''
out += '\n[node name="Lights" type="Node3D" parent="."]\n'
for i, (pos, color, rng, energy) in enumerate(lights):
    out += f'''
[node name="Luce{i + 1}" type="OmniLight3D" parent="Lights"]
transform = {transform(pos)}
light_color = Color({color[0]}, {color[1]}, {color[2]}, 1)
light_energy = {f(energy)}
omni_range = {f(rng)}
'''
out += f'''
[node name="Enemies" type="Node3D" parent="."]

[node name="Run" type="Node" parent="."]
script = ExtResource("{run_script}")

[node name="Waves" type="Node3D" parent="."]
script = ExtResource("{waves_script}")
enemies = Array[Resource]([ExtResource("{walker_wave}"), ExtResource("{runner_wave}"), ExtResource("{brute_wave}")])
'''
for name, pos, _zone in spawns:
    out += f'''
[node name="{unique("Spawn" + name)}" type="Marker3D" parent="Waves"]
transform = {transform(pos)}
'''
out += '\n[node name="Crates" type="Node3D" parent="."]\n'
for name, pos, yaw in crates:
    out += f'''
[node name="{name}" parent="Crates" instance=ExtResource("{crate_scene}")]
transform = {transform(pos, basis_yaw(yaw))}
'''
out += '\n[node name="Machines" type="Node3D" parent="."]\n'
for name, pos, yaw, boost in machines:
    out += f'''
[node name="{name}" parent="Machines" instance=ExtResource("{machine_scene}")]
transform = {transform(pos, basis_yaw(yaw))}
boost = ExtResource("{boosts[boost]}")
'''
out += f'''
[node name="Elicottero" type="Node3D" parent="."]
transform = {transform(HELI[0])}
script = ExtResource("{heli_script}")
radio_offset = Vector3({f(HELI[1][0])}, {f(HELI[1][1])}, {f(HELI[1][2])})
'''
out += '\n[node name="Pickups" type="Node3D" parent="."]\n\n[node name="Labels" type="Node3D" parent="."]\n'
for text, pos in labels:
    out += f'''
[node name="{unique("Scritta" + "".join(c for c in text if c.isalnum()))}" type="Label3D" parent="Labels"]
transform = {transform(pos)}
billboard = 1
text = "{text}"
font_size = 96
outline_size = 16
visibility_range_end = 45.0
'''
open(OUT, "w", encoding="utf-8", newline="\n").write(out)
print("scritto", OUT, stats["forme"], "forme,", len(zones), "zone,", len(doors), "porte,", len(spawns), "punti di comparsa")
