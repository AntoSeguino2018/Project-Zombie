"""Fase 9 del Personaggio N.1: animazioni (skill blender-animation).

Le clip si animano sul rig di controllo `RIG_N1_Corpo` e si cuociono sullo scheletro da gioco
`GAME_RIG_N1_Corpo` con `bake_action.py` della skill (una azione per clip, `GAME_RIG_N1_Corpo|<Clip>`,
più una traccia NLA muta per clip, così l'export glTF le porta tutte).
- Gambe in IK (`foot_ik`): i piedi poggiano a terra senza scivolare; braccia in FK.
- Clip sul posto: il gioco muove la capsula. Ogni clip ha una velocità nominale (passo × 2 / durata
  del ciclo): Godot regola la velocità di riproduzione su quella reale.
- I cicli nascono da funzioni periodiche campionate a ogni fotogramma: l'ultimo fotogramma è uguale
  al primo, e `loop_check.py` lo verifica.
- 30 fotogrammi al secondo.

Clip: Ferma, Cammina (corsetta), Corsa (scatto), Indietro, Sinistra, Destra (laterali), Salto
(una volta, finisce in aria), ATerra (a terra che striscia), Rianima (in ginocchio, mani sul compagno).

    python -B .claude/skills/blender-core/scripts/run_in_blender.py --blend blender/personaggi/personaggio_n1.blend blender/personaggi/script/fase9_animazioni.py
"""
import bpy, json, math, os, sys
from mathutils import Vector, Matrix

PROGETTO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
sys.path.insert(0, os.path.join(PROGETTO, ".claude", "skills", "blender-animation", "scripts"))
import _bpyx as bx      # noqa: E402
import bake_action      # noqa: E402
import loop_check       # noqa: E402

RIG, GAME = "RIG_N1_Corpo", "GAME_RIG_N1_Corpo"
FPS = 30
PASSO_CAMPIONI = 1      # un tasto per fotogramma: la cottura legge le pose calcolate, senza curve in mezzo
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
LATI = (("L", 1), ("R", -1))


# ---------------------------------------------------------------- posa

class Posa:
    """Operazioni nello spazio del rig (= mondo: il rig sta nell'origine), applicate in ordine."""

    def __init__(self, rig):
        self.rig = rig
        self.toccate = set()

    def pb(self, nome):
        self.toccate.add(nome)
        return self.rig.pose.bones[nome]

    def ruota(self, nome, asse, gradi, perno=None):
        """Ruota l'osso attorno a un asse del mondo che passa per la sua testa (o per `perno`)."""
        p = self.pb(nome)
        bpy.context.view_layer.update()
        c = (perno if perno is not None else p.head).copy()
        R = Matrix.Rotation(math.radians(gradi), 4, asse)
        p.matrix = Matrix.Translation(c) @ R @ Matrix.Translation(-c) @ p.matrix

    def sposta(self, nome, d):
        p = self.pb(nome)
        bpy.context.view_layer.update()
        p.matrix = Matrix.Translation(d) @ p.matrix


def braccia(P, giu, avanti_L, avanti_R, gomito, aperte=0.0):
    """Braccia dall'A-pose verso i fianchi (`giu` gradi), oscillazione avanti/indietro e gomito."""
    for lato, s, avanti in (("L", 1, avanti_L), ("R", -1, avanti_R)):
        P.ruota(f"upper_arm_fk.{lato}", Y, (giu - aperte) * s)
        P.ruota(f"upper_arm_fk.{lato}", X, -avanti)           # negativo: la mano va avanti (-Y)
        P.ruota(f"forearm_fk.{lato}", X, -gomito)


def piede(P, lato, d, beccheggio=0.0):
    P.sposta(f"foot_ik.{lato}", d)
    if beccheggio:
        P.ruota(f"foot_ik.{lato}", X, beccheggio)            # positivo: la punta scende


def traiettoria(p, passo, alzata, appoggio=0.5):
    """Piede nel ciclo (fase p in 0..1): in appoggio va da davanti (-passo/2) a dietro (+passo/2) a terra,
    in volo torna avanti alzandosi. Restituisce (lungo, alto, beccheggio)."""
    p %= 1.0
    if p < appoggio:
        u = p / appoggio
        return -passo / 2 + passo * u, 0.0, -8.0 * max(0.0, (u - 0.8) / 0.2)   # tallone su a fine appoggio
    u = (p - appoggio) / (1 - appoggio)
    lungo = passo / 2 - passo * (0.5 - 0.5 * math.cos(math.pi * u))
    # seno al quadrato: il piede si stacca e riatterra senza scatti in verticale
    return lungo, alzata * math.sin(math.pi * u) ** 2, 25.0 * math.sin(math.pi * u) ** 2


# ---------------------------------------------------------------- clip

def ferma(P, t):
    a = 2 * math.pi * t
    P.sposta("torso", Vector((0, 0, -0.004 * (0.5 - 0.5 * math.cos(a)))))
    P.ruota("chest", X, 1.5 * math.sin(a))
    P.ruota("head", Z, 3.0 * math.sin(a + 1.0))
    braccia(P, 38 + 1.5 * math.sin(a), 4, 4, 14 + 2 * math.sin(a))


def ciclo_corsa(P, t, passo, alzata, saltello, piega, oscilla, gomito, verso=1):
    """Corsa sul posto. verso=1 avanti, -1 indietro."""
    a = 2 * math.pi * t
    P.sposta("torso", Vector((0, 0, -saltello * math.cos(2 * a - math.pi) - 0.02)))
    P.ruota("torso", X, piega * verso)
    P.ruota("hips", Z, 6.0 * math.sin(a))
    P.ruota("chest", Z, -5.0 * math.sin(a))
    P.ruota("head", X, -piega * 0.7 * verso)                 # lo sguardo resta dritto
    braccia(P, 34, oscilla * math.cos(a) * verso, -oscilla * math.cos(a) * verso, gomito)
    for lato, fase in (("L", 0.0), ("R", 0.5)):
        lungo, alto, becc = traiettoria(t + fase, passo, alzata, appoggio=0.4)
        piede(P, lato, Vector((0, lungo * verso, alto)), becc * verso)


def laterale(P, t, verso):
    """Corsetta laterale: verso=1 verso la propria sinistra (+X), -1 verso la destra.
    Il piede in volo passa davanti a quello in appoggio, così non si incrociano."""
    a = 2 * math.pi * t
    P.sposta("torso", Vector((0, 0, -0.025 * math.cos(2 * a - math.pi) - 0.02)))
    P.ruota("torso", Y, -5.0 * verso)                        # si sbilancia verso dove va
    P.ruota("chest", Z, 4.0 * math.sin(a))
    braccia(P, 30, 10 * math.cos(a), -10 * math.cos(a), 40, aperte=6 * math.sin(a))
    for lato, fase in (("L", 0.0), ("R", 0.5)):
        lungo, alto, _b = traiettoria(t + fase, 0.32, 0.10, appoggio=0.45)
        davanti = -0.09 * alto / 0.10                        # in volo, un po' avanti
        piede(P, lato, Vector((lungo * verso, davanti, alto)))


def salto(P, t):
    """Una volta: piegamento, spinta, gambe raccolte in aria (l'ultimo fotogramma si tiene in volo)."""
    def tra(a, b, u):
        u = max(0.0, min(1.0, u))
        u = u * u * (3 - 2 * u)
        return a + (b - a) * u
    giu = tra(0, -0.12, t / 0.22) if t < 0.22 else tra(-0.12, 0.06, (t - 0.22) / 0.14)
    P.sposta("torso", Vector((0, 0, giu)))
    P.ruota("torso", X, tra(0, 14, t / 0.22) if t < 0.3 else tra(14, 4, (t - 0.3) / 0.3))
    raccolto = tra(0, 1, (t - 0.38) / 0.3)
    for lato, s in LATI:
        piede(P, lato, Vector((0, 0.04 * raccolto, 0.26 * raccolto + max(0.0, giu) * 1.5)), 20 * raccolto)
    braccia(P, tra(38, 10, (t - 0.25) / 0.3), tra(-10, 25, (t - 0.2) / 0.3), tra(-10, 25, (t - 0.2) / 0.3), 30)


def a_terra(P, t):
    """A terra, prono, che striscia: il corpo è disteso in avanti, le braccia tirano a turno."""
    a = 2 * math.pi * t
    P.ruota("root", X, 82.0, perno=Vector((0, 0, 0)))      # disteso a pancia in giù, testa avanti
    # indietro di 0,75 m: il bacino resta sull'origine (la capsula in Godot), non i piedi
    P.sposta("root", Vector((0, 0.75, 0.15)))
    P.ruota("chest", X, -14.0)                               # busto un po' su, sulle braccia
    P.ruota("head", X, -40.0 + 4 * math.sin(a))              # testa su: guarda avanti
    P.ruota("hips", Y, 5.0 * math.sin(a))
    for lato, s, fase in (("L", 1, 0.0), ("R", -1, math.pi)):
        tira = math.sin(a + fase)                            # 1 braccio steso avanti, -1 tirato indietro
        P.ruota(f"upper_arm_fk.{lato}", Y, 20 * s)
        P.ruota(f"upper_arm_fk.{lato}", X, -(60 + 45 * tira))
        P.ruota(f"forearm_fk.{lato}", X, -(25 + 35 * (1 - tira)))
        P.sposta(f"foot_ik.{lato}", Vector((0, 0.02 * math.sin(a + fase), 0.03 * max(0.0, math.sin(a + fase)))))


def rianima(P, t):
    """In ginocchio (destro a terra), busto in avanti, mani premute sul compagno a ritmo."""
    a = 2 * math.pi * t
    spinta = 0.5 - 0.5 * math.cos(2 * a)                     # due spinte per ciclo
    P.sposta("torso", Vector((0, 0.02, -0.40 - 0.03 * spinta)))
    P.ruota("torso", X, 28 + 6 * spinta)
    P.ruota("head", X, -12)
    piede(P, "L", Vector((0, -0.30, 0.0)))                   # piede sinistro avanti, ginocchio su
    piede(P, "R", Vector((0, 0.30, 0.035)), 50)              # destro dietro, ginocchio a terra
    braccia(P, 26, 62 + 6 * spinta, 62 + 6 * spinta, 18 - 12 * spinta, aperte=10)


# I cicli di passo partono con un piede a metà appoggio e l'altro a metà volo: lì le velocità sono
# costanti e il giro del ciclo non sembra uno strappo (partendo dallo stacco, loop_check vedeva
# l'accelerazione naturale del piede come un "hitch").
INIZIO = 0.2
CLIP = {   # nome: (funzione, fotogrammi, ciclo, velocità nominale m/s)
    "Ferma": (ferma, 60, True, 0.0),
    "Cammina": (lambda P, t: ciclo_corsa(P, t + INIZIO, 0.95, 0.16, 0.025, 8, 28, 55), 18, True, 2 * 0.95 / (18 / FPS)),
    "Corsa": (lambda P, t: ciclo_corsa(P, t + INIZIO, 1.25, 0.24, 0.04, 14, 42, 80), 16, True, 2 * 1.25 / (16 / FPS)),
    "Indietro": (lambda P, t: ciclo_corsa(P, t + INIZIO, 0.70, 0.12, 0.02, 4, 18, 45, verso=-1), 20, True, 2 * 0.70 / (20 / FPS)),
    "Sinistra": (lambda P, t: laterale(P, t + INIZIO, 1), 18, True, 2 * 0.32 / (18 / FPS)),
    "Destra": (lambda P, t: laterale(P, t + INIZIO, -1), 18, True, 2 * 0.32 / (18 / FPS)),
    "Salto": (salto, 24, False, 0.0),
    "ATerra": (a_terra, 30, True, 0.0),
    "Rianima": (rianima, 40, True, 0.0),
}


def ossa_usate(rig):
    """Tutte le ossa che almeno una clip muove. Ogni clip le chiave tutte: un osso senza chiavi in una
    clip tiene la posa della clip di prima (Rianima ereditava la radice ruotata di ATerra, ATerra il
    busto del Salto), sia qui sia in Godot quando si passa da una clip all'altra."""
    usate = set()
    for funzione, _n, _c, _v in CLIP.values():
        P = Posa(rig)
        funzione(P, 0.0)
        usate |= P.toccate
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix()
    return usate


def anima(rig, nome, funzione, n, ciclo, ossa):
    act = bpy.data.actions.get(nome)
    if act:
        bpy.data.actions.remove(act)
    act = bpy.data.actions.new(nome)
    act.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = act
    sc = bpy.context.scene
    fot = list(range(1, n + 1, PASSO_CAMPIONI))
    if fot[-1] != n + (1 if ciclo else 0):
        fot.append(n + 1 if ciclo else n)
    for f in fot:
        sc.frame_set(f)
        for pb in rig.pose.bones:
            pb.matrix_basis = Matrix()
        P = Posa(rig)
        t = (f - 1) / n if ciclo else (f - 1) / max(n - 1, 1)
        funzione(P, t)
        bpy.context.view_layer.update()
        for b in ossa:
            pb = rig.pose.bones[b]
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
    act.frame_range = (1, fot[-1])
    if ciclo:
        # curve cicliche prima della cottura: senza, le Bezier si appiattiscono al primo e all'ultimo
        # fotogramma e al giro del ciclo la velocità cambia di colpo (loop_check: "hitches")
        act.use_frame_range = True
        act.use_cyclic = True
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    for fc in cb.fcurves:
                        fc.modifiers.new("CYCLES")
                        fc.update()
    return act


def run():
    bx.object_mode()
    sc = bpy.context.scene
    sc.render.fps = FPS
    rig, game = bpy.data.objects[RIG], bpy.data.objects[GAME]
    # gambe in IK, braccia in FK
    for lato in ("L", "R"):
        rig.pose.bones[f"thigh_parent.{lato}"]["IK_FK"] = 0.0
        rig.pose.bones[f"upper_arm_parent.{lato}"]["IK_FK"] = 1.0
    # lo scheletro da gioco segue il rig di controllo mentre si cuoce
    bake_action.run(target=GAME, follow=True)
    for a in [a for a in bpy.data.actions if a.name.startswith(f"{GAME}|")]:
        bpy.data.actions.remove(a)
    bx.select_only([rig])
    bpy.ops.object.mode_set(mode="POSE")
    try:
        ossa = sorted(ossa_usate(rig))
        for nome, (fn, n, ciclo, _v) in CLIP.items():
            anima(rig, nome, fn, n, ciclo, ossa)
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")
    cotte = bake_action.run(source=RIG, target=GAME, actions=list(CLIP))
    out = {"cotte": cotte, "loop": {}}
    for nome, (fn, n, ciclo, v) in CLIP.items():
        if ciclo:
            r = loop_check.run(object=GAME, action=f"{GAME}|{nome}", fix=True)
            out["loop"][nome] = {k: r.get(k) for k in ("ok", "pops", "hitches", "fixed") if k in r}
    out["velocita_nominali_ms"] = {k: round(v, 2) for k, (_f, _n, _c, v) in CLIP.items() if v}
    # a riposo il rig torna senza azione, lo scheletro da gioco sulla prima clip
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix()
    game.animation_data.action = bpy.data.actions.get(f"{GAME}|Ferma")
    sc.frame_start, sc.frame_end = 1, 60
    sc.frame_set(1)
    for ob in sc.objects:
        ob.select_set(False)
    bpy.ops.wm.save_mainfile(compress=True)
    return {"ok": True, **out}


print("@@JSON@@" + json.dumps(run(), default=str))
