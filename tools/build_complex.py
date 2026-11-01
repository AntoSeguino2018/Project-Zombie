# Genera game/levels/complex.tscn: la mappa grande in greybox ("Il Complesso").
# Assi: X verso est, Z verso sud (nord = -Z). Unità: metri.
# Uso (dalla cartella del progetto): python tools/build_complex.py
# Attenzione: riscrive la scena da zero; le modifiche fatte a mano nell'editor
# vanno riportate qui, oppure da quel momento si lavora solo nell'editor.
import math, os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "levels", "complex.tscn")

WALL_H = 6.0
WALL_T = 0.5
DOOR = 4.0

ext = []          # (type, path, id)
nodes = []        # testo dei nodi
counter = {}


def res(kind, path):
    for k, p, i in ext:
        if p == path:
            return i
    i = f"{len(ext) + 1}_{os.path.splitext(os.path.basename(path))[0]}"
    ext.append((kind, path, i))
    return i


MAT = {
    "floor": res("Material", "res://assets/materials/greybox_floor.tres"),
    "wall": res("Material", "res://assets/materials/greybox_wall.tres"),
    "accent": res("Material", "res://assets/materials/greybox_accent.tres"),
    "danger": res("Material", "res://assets/materials/greybox_danger.tres"),
    "yellow": res("Material", "res://assets/materials/greybox_yellow.tres"),
    "green": res("Material", "res://assets/materials/greybox_green.tres"),
    "blue": res("Material", "res://assets/materials/greybox_blue.tres"),
    "dark": res("Material", "res://assets/materials/greybox_dark.tres"),
    "tile": res("Material", "res://assets/materials/greybox_tile.tres"),
}


def f(v):
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def basis_yaw(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    # Righe della base (come le scrive Godot): rotazione attorno a Y.
    return [c, 0, s, 0, 1, 0, -s, 0, c]


def basis_pitch(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [1, 0, 0, 0, c, -s, 0, s, c]


def transform(pos, basis=None):
    b = basis or [1, 0, 0, 0, 1, 0, 0, 0, 1]
    return "Transform3D(%s)" % ", ".join(f(v) for v in b + list(pos))


def unique(name):
    counter[name] = counter.get(name, 0) + 1
    return name if counter[name] == 1 else f"{name}{counter[name]}"


def node(text):
    nodes.append(text.strip("\n") + "\n")


def box(parent, name, center, size, mat, basis=None):
    node(f'''[node name="{unique(name)}" type="CSGBox3D" parent="{parent}"]
transform = {transform(center, basis)}
use_collision = true
size = Vector3({f(size[0])}, {f(size[1])}, {f(size[2])})
material = ExtResource("{MAT[mat]}")
''')


def wall_x(parent, name, z, x0, x1, doors=(), h=WALL_H, mat="wall", door=DOOR):
    """Muro lungo X a quota z, da x0 a x1, con aperture centrate in doors."""
    cuts = sorted(doors)
    start = x0
    for d in cuts + [None]:
        end = x1 if d is None else d - door / 2
        if end - start > 0.05:
            box(parent, name, ((start + end) / 2, h / 2, z), (end - start, h, WALL_T), mat)
        if d is not None:
            start = d + door / 2


def wall_z(parent, name, x, z0, z1, doors=(), h=WALL_H, mat="wall", door=DOOR):
    cuts = sorted(doors)
    start = z0
    for d in cuts + [None]:
        end = z1 if d is None else d - door / 2
        if end - start > 0.05:
            box(parent, name, (x, h / 2, (start + end) / 2), (WALL_T, h, end - start), mat)
        if d is not None:
            start = d + door / 2


def floor(parent, name, x0, x1, z0, z1, mat, top=0.0):
    box(parent, name, ((x0 + x1) / 2, top - 0.5, (z0 + z1) / 2), (x1 - x0, 1.0, z1 - z0), mat)


def ramp(parent, name, x, z_low, z_high, height, width, mat="accent"):
    """Rampa che sale verso nord (da z_low, a sud, a z_high, a nord) fino a height."""
    run = z_low - z_high
    length = math.hypot(run, height)
    angle = math.degrees(math.atan2(height, run))
    t = 0.4
    a = math.radians(angle)
    cy = height / 2 - (t / 2) * math.cos(a)
    cz = (z_low + z_high) / 2 - (t / 2) * math.sin(a)
    box(parent, name, (x, cy, cz), (width, t, length), mat, basis_pitch(angle))


# --- Zone --------------------------------------------------------------------
G = "Geometry"

# Pavimenti, uno per zona (senza sovrapposizioni).
floor(G, "FloorAtrio", -14, 14, 0, 24, "tile")
floor(G, "FloorAula", -56, -14, 0, 30, "floor")
floor(G, "FloorCortile", 14, 56, 0, 36, "green")
floor(G, "FloorCorridoio", -56, 56, -6, 0, "tile")
floor(G, "FloorArchivio", -56, -8, -40, -6, "floor")
floor(G, "FloorSalaAlta", -8, 8, -40, -6, "tile")
floor(G, "FloorMagazzino", 8, 56, -40, -6, "floor")

# Muri esterni.
wall_x(G, "WallNorth", -40, -56, 56, h=8)
wall_z(G, "WallWest", -56, -40, 0, h=8)
wall_z(G, "WallWestAula", -56, 0, 30, h=8, mat="yellow")
wall_z(G, "WallEast", 56, -40, 36, h=8)
wall_x(G, "WallSouthAula", 30, -56, -14, h=8, mat="yellow")
wall_x(G, "WallSouthAtrio", 24, -14, 14, h=8)
wall_x(G, "WallSouthCortile", 36, 14, 56, h=8)
wall_z(G, "WallAulaSouthEnd", -14, 24, 30, h=8)
wall_z(G, "WallCortileSouthEnd", 14, 24, 36, h=8)

# Corridoio: muro sud (verso aula, atrio, cortile) e nord (verso archivio, sala alta, magazzino).
wall_x(G, "WallCorridorSouth", 0, -56, 56, doors=[-35, -8, 8, 35])
wall_x(G, "WallCorridorNorth", -6, -56, 56, doors=[-40, -15, 0, 15, 40])

# Atrio tra aula e cortile.
wall_z(G, "WallAulaAtrio", -14, 0, 24, doors=[12])
wall_z(G, "WallAtrioCortile", 14, 0, 24, doors=[12])

# Zone nord: archivio | sala alta | magazzino, con un passaggio tra ognuna.
wall_z(G, "WallArchivioSala", -8, -40, -6, doors=[-24])
wall_z(G, "WallSalaMagazzino", 8, -40, -6, doors=[-24])

# Atrio: pilastri.
for x, z in [(-7, 6), (7, 6), (-7, 17), (7, 17)]:
    box(G, "PillarAtrio", (x, 3, z), (1.2, 6, 1.2), "wall")

# Aula studio gialla: tavoli in file, lavagna, muri gialli bassi a separare.
for x in (-46, -35, -24):
    for z in (6, 12, 18, 24):
        box(G, "Tavolo", (x, 0.4, z), (5, 0.8, 1.6), "yellow")
box(G, "Lavagna", (-55.6, 2.6, 15), (0.2, 2.4, 8), "dark")
box(G, "Cattedra", (-51, 0.5, 15), (1.6, 1.0, 4), "accent")
for z in (3, 27):
    box(G, "PillarAula", (-35, 3, z), (1.2, 6, 1.2), "yellow")

# Cortile: aiuole e tronchi.
for x, z in [(22, 8), (34, 6), (48, 10), (24, 26), (40, 30), (50, 22)]:
    box(G, "Aiuola", (x, 0.45, z), (3, 0.9, 3), "green")
for x, z in [(28, 18), (44, 16), (18, 32)]:
    box(G, "Albero", (x, 2.5, z), (0.8, 5, 0.8), "accent")

# Archivio: scaffali in file con corridoi stretti.
for z in (-10, -14, -18, -22, -26, -30, -34):
    box(G, "Scaffale", (-47, 1.6, z), (12, 3.2, 1.0), "blue")
    box(G, "Scaffale", (-26, 1.6, z), (12, 3.2, 1.0), "blue")

# Sala alta: soppalco a nord a 3 m, due rampe, pilastri.
box(G, "Soppalco", (0, 1.5, -35), (15.5, 3, 10), "wall")
ramp(G, "RampaSoppalcoOvest", -5, -21.5, -30, 3, 3.5)
ramp(G, "RampaSoppalcoEst", 5, -21.5, -30, 3, 3.5)
for x in (-4, 4):
    box(G, "PillarSala", (x, 3, -14), (1.2, 6, 1.2), "wall")

# Magazzino: pile di casse, piattaforma rialzata a 2 m con rampa.
for x, z, h in [(14, -12, 2), (20, -16, 4), (14, -34, 2), (26, -36, 4), (32, -12, 2), (38, -24, 2), (30, -28, 4)]:
    box(G, "PilaCasse", (x, h / 2, z), (2.4, h, 2.4), "accent")
box(G, "Piattaforma", (48, 1.0, -34), (15.5, 2, 11.5), "danger")
ramp(G, "RampaPiattaforma", 48, -20, -28.25, 2, 3.5)

# --- Strutture distruttibili --------------------------------------------------
DESTRUCTIBLE = res("Script", "res://game/levels/destructible/destructible_blocks.gd")
destructibles = [
    ("MuroCortileA", (30, 0, 14), 0, (6, 2.5, 0.5), (0.78, 0.45, 0.32)),
    ("MuroCortileB", (44, 0, 26), 90, (6, 2.5, 0.5), (0.78, 0.45, 0.32)),
    ("MuroMagazzinoA", (24, 0, -22), 0, (8, 3, 0.5), (0.6, 0.6, 0.65)),
    ("MuroMagazzinoB", (40, 0, -14), 90, (6, 3, 0.5), (0.6, 0.6, 0.65)),
    ("ParetinaAula", (-30, 0, 15), 90, (5, 2, 0.5), (0.92, 0.8, 0.4)),
]

# --- Punti di comparsa (lontani dalla partenza, in ogni zona) -----------------
spawns = [
    ("AulaNO", (-53, 0, 3)), ("AulaSO", (-53, 0, 27)), ("AulaSE", (-18, 0, 28)),
    ("CortileNE", (53, 0, 3)), ("CortileSE", (53, 0, 33)), ("CortileSO", (18, 0, 34)),
    ("ArchivioNO", (-53, 0, -38)), ("ArchivioNE", (-12, 0, -38)), ("ArchivioSO", (-53, 0, -8)),
    ("SalaAlta", (6.5, 0, -9)),
    ("MagazzinoNE", (53, 0, -9)), ("MagazzinoNO", (12, 0, -38)), ("MagazzinoN", (32, 0, -38)),
    ("CorridoioO", (-53, 0, -3)), ("CorridoioE", (53, 0, -3)),
]

# --- Casse e macchinette ------------------------------------------------------
crates = [
    ("CassaAtrio", (9, 0, 20), 20),
    ("CassaAula", (-50, 0, 27), -30),
    ("CassaCortile", (50, 0, 32), 15),
    ("CassaArchivio", (-36, 0, -37), 0),
    ("CassaSoppalco", (0, 3, -37), 10),
    ("CassaMagazzino", (52, 2, -37), -15),
]
# yaw: la macchinetta guarda verso +Z ruotata di yaw (0 = sud, 180 = nord, 90 = est, -90 = ovest).
machines = [
    ("EspressoAtrio", (-9, 0, 23.1), 180, "espresso"),
    ("DoppioAtrio", (-7.8, 0, 23.1), 180, "doppio"),
    ("MerendinaAtrio", (-6.6, 0, 23.1), 180, "merendina"),
    ("EspressoCortile", (55.3, 0, 6), -90, "espresso"),
    ("DoppioArchivio", (-55.3, 0, -8), 90, "doppio"),
    ("MerendinaMagazzino", (8.7, 0, -30), 90, "merendina"),
    ("EspressoSoppalco", (-6.5, 3, -39.3), 0, "espresso"),
]

labels = [
    ("Atrio", (0, 4.5, 2)), ("Aula studio", (-14, 4.5, 12)), ("Cortile", (14, 4.5, 12)),
    ("Corridoio", (0, 4.5, -3)), ("Archivio", (-15, 4.5, -7)), ("Sala alta", (0, 4.5, -7)),
    ("Magazzino", (15, 4.5, -7)),
]

# --- Scrittura ---------------------------------------------------------------
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

top = f'''[node name="Complex" type="Node3D"]

[node name="PlayerSpawner" type="MultiplayerSpawner" parent="."]
spawn_path = NodePath("../Players")
script = ExtResource("{player_spawner}")
player_scene = ExtResource("{player}")
spawn_origin = Vector3(-2, 0.1, 15)

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
directional_shadow_max_distance = 80.0

[node name="Players" type="Node3D" parent="."]

[node name="Navigation" type="NavigationRegion3D" parent="."]
navigation_mesh = SubResource("NavigationMesh_level")
script = ExtResource("{nav_script}")

[node name="Geometry" type="Node3D" parent="." groups=["navigation_source"]]
'''

out = "\n".join(head) + "\n" + top + "\n" + "\n".join(nodes)
out += '\n[node name="Destructibles" type="Node3D" parent="." groups=["navigation_source"]]\n'
for name, pos, yaw, size, color in destructibles:
    out += f'''
[node name="{name}" type="Node3D" parent="Destructibles"]
transform = {transform(pos, basis_yaw(yaw))}
script = ExtResource("{DESTRUCTIBLE}")
size = Vector3({f(size[0])}, {f(size[1])}, {f(size[2])})
color = Color({color[0]}, {color[1]}, {color[2]}, 1)
'''
out += f'''
[node name="Enemies" type="Node3D" parent="."]

[node name="Run" type="Node" parent="."]
script = ExtResource("{run_script}")

[node name="Waves" type="Node3D" parent="."]
script = ExtResource("{waves_script}")
enemies = Array[Resource]([ExtResource("{walker_wave}"), ExtResource("{runner_wave}"), ExtResource("{brute_wave}")])
'''
for name, pos in spawns:
    out += f'''
[node name="Spawn{name}" type="Marker3D" parent="Waves"]
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
out += '\n[node name="Pickups" type="Node3D" parent="."]\n\n[node name="Labels" type="Node3D" parent="."]\n'
for text, pos in labels:
    out += f'''
[node name="{unique("Label" + text.replace(" ", ""))}" type="Label3D" parent="Labels"]
transform = {transform(pos)}
billboard = 1
text = "{text}"
font_size = 96
outline_size = 16
visibility_range_end = 40.0
'''
open(OUT, "w", encoding="utf-8", newline="\n").write(out)
print("scritto", OUT, len(nodes), "forme")
