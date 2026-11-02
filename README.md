# Project Zombie

FPS roguelike in prima persona, co-op online da 1 a 4 giocatori, grafica low-poly colorata.
Motore: **Godot 4** (GDScript). Piano di lavoro: [ROADMAP.md](ROADMAP.md). Riassunto per chi riprende il lavoro: [RECAP.md](RECAP.md).

## Struttura delle cartelle

```
assets/          File importati in Godot (generati, non si modificano qui)
  models/          .glb esportati da Blender
  textures/        texture e palette di colori
  materials/       materiali Godot (.tres)
  audio/           effetti sonori e musica
  fonts/
game/            Il gioco, organizzato per funzionalità
  player/          controller FPS, camera, input
  characters/      definizioni dei personaggi e delle loro abilità
  weapons/         armi e proiettili
  combat/          vita, danno, numeri di danno (comuni a giocatori e nemici)
  enemies/         nemici, IA, boss
  items/           oggetti della run (passivi, attivi)
  director/        logica degli spawn e della difficoltà
  levels/          livelli e arene (props/ per oggetti di scena come i manichini)
  net/             lobby, connessione, sincronizzazione
  ui/              HUD e menu
shared/          Codice e risorse comuni
  shaders/         shader dello stile grafico
  utils/
docs/armi/       Una scheda per ogni arma: danni, difetti da correggere in Blender e in Godot
tests/           Test automatici (bash tests/run_tests.sh; ignorati da Godot)
tools/           Script di supporto, es. il generatore della mappa (ignorati da Godot)
blender/         File sorgente .blend (ignorati da Godot)
references/      Disegni 2D di riferimento (ignorati da Godot)
builds/          Build esportate (non versionate)
```

Ogni funzionalità tiene scene (`.tscn`) e script (`.gd`) nella propria cartella.

## Convenzioni
- **Scala:** 1 unità = 1 metro. Un personaggio è alto circa 1,8 m.
- **Nomi file:** `snake_case` (`fps_controller.gd`, `zombie_runner.tscn`).
- **Nomi nodi e classi:** `PascalCase` (`FpsController`).
- **Modelli:** si lavora in `blender/` e si esporta in glTF (`.glb`) dentro `assets/models/`.
- **Multiplayer:** l'host decide su danni, nemici e loot. I client inviano solo input e richieste.

## Setup
1. Installa [Godot 4](https://godotengine.org/download) (versione standard, non .NET).
2. Apri Godot, scegli **Import** e seleziona `project.godot` in questa cartella.
