# Personaggio N.1

Primo personaggio giocabile. Bozza a penna: `blender/Peronaggio_N1_bozza.jpeg` (vista frontale, testa di profilo, braccio robotico di lato, mano robotica).

## Riferimenti

In `blender/personaggi/riferimenti/`. La cartella è solo locale ed esclusa da git, perché contiene immagini di terzi e la foto di una persona reale.
- `stile_poligonale.png`: lo **stile** da seguire. Superfici a facce grandi e piatte, forme massicce, materiali leggibili.
- `anatomia.png`: l'**anatomia** del corpo, per quanto stilizzata. Contiene i gruppi muscolari di fronte e da dietro.
- `capelli_mullet.png` e `capelli_mullet_2.png`: il **taglio**. Sopra corti, ricci e scompigliati che ricadono in avanti; lati sfumati sopra e dietro l'orecchio; dietro mullet mosso fino alla base del collo.
- `bozza_viso.webp`: **bozza del viso** (fonte principale per testa, collo e barba).
  - Collo largo e corto che parte da sotto le orecchie.
  - Barba corta: baffi collegati a un pizzetto pieno sul mento.
  - Lati rasati scuri, ciuffi a punta sopra e dietro le orecchie.

## Design

- **Altezza:** 1,72 m.
- **Fisico:** muscoloso, spalle larghe, proporzioni della bozza.
- **Capelli:** come `capelli_mullet.png`. Castano scuro.
- **Viso:** testa proporzionata, non grande né tonda. Baffi e pizzetto **solo accennati, quasi rasati**. **Niente occhi:** al loro posto una zona d'ombra voluta.
- **Collana:** catenina con una targhetta rettangolare sul petto.
- **Maglia:** nera, attillata.
- **Braccia:** robotiche dalle spalle alle mani, **acciaio chiaro pulito**, senza luci.
  - Segmentate: braccio, gomito, avambraccio con una fila di bulloni esagonali lungo il lato.
  - Mani robotiche: vite a croce sul dorso, borchie sulle nocche, polsino.
- **Spallacci:** piastre sulle spalle con il bullone centrale e le **punte**, sopra gli anelli di pelliccia.
- **Pelliccia:** un pezzo unico agganciato al busto, con tre parti:
  - due anelli folti che passano sotto le ascelle e circondano l'inserzione spalla-torso;
  - un **cappuccio abbassato** che li collega dietro e scende sulle scapole;
  - non sta sul braccio robotico.
- **Cintura:** fibbia con la "C". La striscia che pende davanti sulla bozza era solo un tratto: davanti i cargo sono lisci.
- **Pantaloni:** cargo neri larghi, tasche laterali, raccolti dentro gli scarponi.
- **Scarponi:** anfibi neri e marroni.

## Stile tecnico

- Low-poly in stile Deep Rock Galactic: forme grosse e leggibili, colori pieni, pochi materiali, niente texture dipinte.
- Il budget indicativo per tutto il personaggio è di 8.000–15.000 triangoli.
- Le braccia in prima persona saranno una copia separata e più curata delle braccia robotiche, perché in un FPS sono la parte che si vede sempre.

## Metodo: le skill di progetto

Dal 3 novembre 2026 il personaggio si rifà **da zero** seguendo le skill `blender-*` in `.claude/skills/` (origine e licenza in `BLENDER_SKILLS_ORIGINE.md`). La traccia è la ricetta 3 di `blender-workflow-recipes` ("Game character"), adattata allo stile del gioco. Le regole di questa scheda e del `RECAP.md` hanno la precedenza sulle skill.

**Cosa cambia rispetto alla versione precedente:**
- **Prima il corpo, poi i vestiti.** Si fa un corpo base unico (testa compresa) e si mette lo scheletro; maglia, cargo e scarponi nascono dal corpo (`garment.py`) e ne copiano i pesi, così si muovono insieme. Prima ogni pezzo era modellato a sé.
- **Topologia pensata per piegarsi:** retopologia a quad con gli anelli ai giunti (3 a gomiti e ginocchia, più anelli alla spalla), invece del Decimate a faccette che andava bene solo da fermo.
- **Ogni fase si chiude con un controllo automatico** (`qa_check.py`: normali, pezzi staccati, z-fighting, scala) oltre ai render.
- **Script delle skill invece di una libreria nostra:** si lanciano dal vivo con l'MCP oppure senza finestra con `run_in_blender.py`, che trova da solo il Blender di Steam.

**Lo stile sfaccettato** non viene da texture o bake. Viene da un Decimate *collapse* (rapporto 0,45, scelto nella fase 2) sopra la mesh a quad, con ombreggiatura piatta e colori pieni. Per questo la cottura di normal map della ricetta si salta, salvo decisione diversa nella fase dei colori.

## Fasi

Ogni fase si chiude con `qa_check.py` superato, le immagini di fronte, di lato e di tre quarti, e l'approvazione prima di passare alla successiva.

0. **Preparazione** (`blender-scene-setup`): file `blender/personaggi/personaggio_n1.blend` nuovo, unità in metri, collezioni, bozza come immagine di riferimento in scala, guida d'altezza a 1,72 m e capsula del giocatore (1,8 m, camera a 1,6 m).
1. **Corpo base** (`blender-sculpting`): corpo nudo stilizzato con la testa, in A-pose a 45°, da primitive unite con il remesh a voxel e muscoli procedurali. Si confronta con la bozza e con `anatomia.png`. Di questo corpo si vedranno solo testa, collo e la pelle sotto lo scollo.
2. **Retopologia e UV** (`blender-retopology-uv`): mesh low-poly a quad con gli anelli ai giunti, dentro il budget; UV `min_stretch`.
3. **Scheletro** (`blender-character-rigging`): Rigify `basic_human` senza faccia, articolazioni messe a mano sulla mesh, pesi con `bind_mesh.py`, pose di stress. Niente collassi a gomiti, ginocchia e spalle.
4. **Vestiti** (`blender-clothing`): maglia attillata (scarto 5 mm), cargo larghi (15–20 mm, con caduta in simulazione), cintura, scarponi; il corpo coperto si nasconde. Controllo delle compenetrazioni in ogni posa di stress.
5. **Braccia robotiche e spallacci** (`blender-hardsurface-modeling`): pezzi rigidi, ognuno al 100% su un osso; sostituiscono le braccia del corpo, che si nascondono.
6. **Viso e accessori:** arcata, zona d'ombra al posto degli occhi, naso, bocca, barba accennata, collana e targhetta.
7. **Capelli e pelliccia** (`blender-hair-grooming`): tecnica da decidere qui, tra ciocche solide sfaccettate e carte con texture (`groom.py --cards`), tenendo conto dello stile e del budget.
8. **Colori** (`blender-pbr-materials`): materiali piatti, controllo finale del budget (`blender-game-optimization`).
9. **Animazioni** (`blender-animation`): ferma, camminata, corsa, salto, a terra (downed), rianimazione; scheletro da gioco con `--game-skeleton`.
10. **In Godot** (`blender-export-pipelines`, preset `godot`): modello visto dagli altri giocatori in co-op, braccia in prima persona sulla camera.

## Blender

**File:** `blender/personaggi/personaggio_n1.blend`, creato da `blender/personaggi/script/fase0_preparazione.py`. Lo script riparte da una scena vuota e **sovrascrive il file**: si rilancia solo per rifare la fase 0.

**Collezioni:** tutto sta sotto `Personaggio_N1`.
- `N1_Riferimenti`:
  - `Bozza_Fronte`, l'immagine della bozza nel piano XZ, dietro il personaggio (+Y);
  - `Bozza_Profilo`, la stessa immagine nel piano YZ, per la testa di profilo vista da destra, con la posizione ripresa dalla versione precedente;
  - `CameraVerifica`, ortogonale di fronte, nascosta nella vista ma usata dai render.
- `N1_Guide`, solo filo, non selezionabili e fuori dal render:
  - `Guida_Quote`: le linee alle quote della bozza più la verticale di 1,72 m;
  - `Guida_Capsula`: la capsula del giocatore, raggio 0,4 e altezza 1,8;
  - `Guida_CameraGioco`: il punto della camera a 1,6 m.
- `N1_Alto`: `N1_Corpo_alto`, la sorgente fitta del corpo (fase 1), da cui la fase 2 ricava la mesh di gioco. Materiale provvisorio `M_N1_Provvisorio`.
- `N1_Gioco`: `N1_Corpo`, la mesh di gioco del corpo (fase 2), tutta a quad, simmetrica, con le UV; dalla fase 3 è legata a `GAME_RIG_N1_Corpo`.
- `N1_Scheletro` (fase 3):
  - `META_N1_Corpo`: il metarig Rigify, nascosto;
  - `RIG_N1_Corpo`: il rig di controllo, quello che si anima; ha l'azione `QA_Stress` con le pose di prova;
  - `GAME_RIG_N1_Corpo`: lo scheletro da gioco, con la radice e le ossa deformanti senza prefisso `DEF-`; copia le pose del rig di controllo;
  - i widget di Rigify (collezione `WGTS_…`), esclusi dalla vista.
- `N1_Vestiti` (fase 4): `N1_Maglia`, `N1_Cargo`, `N1_Tasca.L`/`.R`, `N1_Cintura`, `N1_Fibbia`, `N1_Scarponi`, `N1_Suole`, `N1_Lacci`, tutti legati a `GAME_RIG_N1_Corpo`.
  - Sul corpo ci sono i gruppi `Zona_*` (le zone da cui nascono i capi) e i modificatori Mask `Hidden_*`, che nascondono la pelle coperta.
  - L'attributo `N1_braccio` segna braccia e mani del corpo.
- Le altre collezioni del modello si aggiungono fase per fase.

**Script** in `blender/personaggi/script/`, tutti senza finestra con `run_in_blender.py`:
- `fase0_preparazione.py`: riscrive il file da zero (riferimenti e guide);
- `fase1_corpo_base.py`: rifà solo `N1_Alto`;
- `fase2_retopologia.py [-- --quad N --prova]`: rifà `N1_Corpo` da `N1_Corpo_alto` (con `--prova` riporta solo i triangoli per zona, senza salvare);
- `fase3_scheletro.py`: rifà metarig, rig, pesi, scheletro da gioco e pose di prova (toglie quelli vecchi);
- `fase4_vestiti.py`: rifà tutti i vestiti (toglie i vecchi, le maschere e i gruppi `Zona_*`/`Hidden_*`) e misura le compenetrazioni nelle pose;
- `verifica_pose.py -- --out FILE.png`: foglio con le pose di prova (fotogrammi 1, 10, 20, 30, 40, 50) di fronte e di tre quarti;
- `verifica_bozza.py -- --out CARTELLA`: render ortogonale allineato pixel per pixel alla bozza, sovrapposto in trasparenza, di fronte e di profilo.

I render di verifica vanno in `blender/personaggi/render/` (esclusa da git).

**Da sapere:** dal vivo la vista 3D di Blender non si ridisegna mentre la finestra è in secondo piano, quindi le schermate via MCP possono mostrare un fotogramma vecchio. Per i confronti valgono i render senza finestra.

**Corpo base (fase 1):** forme a sezioni, con le stesse tabelle di busto e testa della versione precedente, interpolate in modo morbido (Catmull-Rom; quella lineare lasciava una fascia a ogni riga). Le parti si fondono in una griglia SDF a 4 mm con Geometry Nodes.
- **Busto e braccia** passano dal raccordo delle giunture concave (`SDF Grid Fillet`, 12 passate): così spalle e ascelle sono morbide.
- **Testa, gambe e mani** si uniscono dopo, senza raccordo: il raccordo riempiva la mandibola, l'interno delle cosce e lo spazio tra le dita.
- Poi levigatura (20 passate, viso e mani quasi fermi), muscoli come rilievi lungo la normale (pettorali, addominali, clavicole, scapole, dorsali, glutei) e simmetria da +X.
- Nel nodo `SDF Grid Boolean` in modalità unione le griglie vanno tutte nell'ingresso multiplo "Grid": "Grid 1" serve solo alla differenza.

**Mesh di gioco (fase 2):** stessa procedura di `auto_retopo.py --method quadriflow` della skill. Prima si fa una copia della sorgente con remesh a voxel, poi Quadriflow simmetrico a 5.000 quad richiesti (ne dà 4.133), poi la proiezione sulla sorgente. Le UV sono automatiche, con `uv_pack.py --method smart`: i colori sono pieni, e le UV servono a vestiti ed export.
- **Quadriflow e i lati corti:** Quadriflow rifiuta i lati più corti di 0,1 mm, che il remesh a volte lascia, con il messaggio "The mesh needs to be manifold and have face normals that point in a consistent direction" anche se la mesh è chiusa. Lo script fonde i vertici entro 0,3 mm prima di lanciarlo. Lo script della skill non lo fa, ed è per questo che fallisce su questo corpo.
- **La densità è uniforme:** Quadriflow mette lo stesso numero di quad per metro quadro dappertutto. Se il viso nella fase 6 avesse bisogno di più geometria, si suddivide solo la testa.
- **Le dita escono schiacciate:** non è un problema, perché le mani del corpo si nascondono sotto quelle robotiche. Servono solo a piazzare le ossa.
- **Gli script delle skill lanciati senza `--objects`** lavorano sugli oggetti selezionati. Per questo `fase2_retopologia.py` salva il file senza selezione.
- **Lo stile sfaccettato** (prova in `render/fase2_stile_prova.png`):
  - i quad con ombreggiatura piatta sembrano una griglia di pixel;
  - un Decimate *collapse* simmetrico sopra i quad dà invece facce irregolari come in `stile_poligonale.png`.

  Proposta: la mesh di lavoro resta a quad, per scheletro, pesi e vestiti, e la sfaccettatura è un modificatore Decimate tenuto attivo prima dell'Armature, applicato all'export. Il Decimate interpola i gruppi di vertici, quindi i pesi restano validi.

**Scheletro (fase 3):** metarig `human` senza viso. Il `basic_human` suggerito dalla skill non ha le dita, che servono alle mani robotiche; i pettorali sono rigidi, quindi le ossa `breast` sono tolte.
- **Articolazioni:** si mettono con le stesse quote usate per costruire il corpo nella fase 1.
  - Braccia in A-pose a 45°, gomiti spostati indietro di 12 mm e ginocchia in avanti di 14 mm, così l'IK sa da che parte piegare.
  - Dita e pollice sono sulle basi e sulle punte modellate.
  - Il rollio segue il metarig: Z davanti per le braccia, Z verso il palmo per palmo e dita, Z verso le altre dita per il pollice, Z dietro per le gambe.
- **Generazione:** si genera con Rigify, poi i pesi automatici di `bind_mesh.py` (calore delle ossa, 4 influenze, normalizzati). Infine `rigify_build.game_skeleton` crea lo scheletro da gioco, e la mesh passa a quello.
- **Da sapere:**
  - Le ossa dello scheletro da gioco hanno vincoli verso il rig di controllo: prima dell'export l'animazione va cotta (`bake_action.py`, fase 9).
  - Lo script `rig_check.py` della skill aveva un errore con Blender 5.2: è corretto in locale e annotato in `.claude/skills/BLENDER_SKILLS_ORIGINE.md`.

**Vestiti (fase 4):** ogni capo nasce dalla sua zona del corpo con `garment.py`: copia delle facce spinta in fuori, spessore con Solidify verso l'esterno, pesi copiati dal corpo (4 influenze). Così segue lo stesso scheletro.
- **Maglia:** scarto 4 mm, spessore 2 mm, senza maniche.
  - Lo scalfo è tagliato all'attacco del braccio.
  - Scollo girocollo con la forma della versione precedente, 2 cm più in basso (su questo corpo saliva a collo alto). Il bordo del collo è riportato sulla linea dello scollo, altrimenti seguirebbe i quad a dente di sega.
  - Sotto, entra nei cargo (da 0,955 m).
- **Cargo:** scarto 1 cm, spessore 3 mm, da 0,20 a 0,995 m.
  - **Allargati dopo la copia dei pesi**, così ogni punto tiene le ossa del punto del corpo da cui viene:
    - raggio di circa 12 cm attorno all'asse della gamba (gamba larga circa 24 cm, come la bozza), con il centro spostato in fuori fino a 3 cm;
    - pieghe a 5 onde che girano scendendo;
    - raccolti in fondo (6 cm di raggio a 0,20 m) dentro gli scarponi, con un rigonfiamento sopra.
  - Il passaggio ai fianchi è graduale tra 0,78 e 0,90 m.
  - I pesi sono levigati (12 passate): con il cambio netto coscia/stinco copiato dal corpo, il ginocchio piegato faceva una palla.
- **Tasche:** a toppa sul lato esterno della coscia, con patta e bottone, rigide al 100% sulla coscia.
- **Cintura:** anello pulito attorno alla vita, ricavato con raggi dal centro e non dai quad del corpo, da 0,935 a 0,995 m; davanti sporge di 5 mm dai cargo.
- **Fibbia:** piastra d'acciaio con la "C" in rilievo scuro (barra curva unica), rigida sulla colonna.
- **Scarponi:** dal piede, scarto 12 mm e spessore 4 mm.
  - Il gambale è un cerchio attorno all'asse della gamba, da 6 a 7 cm di raggio.
  - Fondo piatto a 2,5 cm. Tomaia nera, puntale e tallone marroni.
  - **Suole** separate: il fondo allargato di 9 mm, da terra a 3,4 cm.
  - **Lacci:** quattro barrette sul davanti.
- **Corpo coperto:** è nascosto con i Mask di `garment.py`, lasciando un anello di pelle sotto i bordi. All'export quelle facce vanno cancellate.
- **Compenetrazioni:** la misura delle pose esclude le braccia del corpo, segnate con l'attributo `N1_braccio` e destinate a sparire. Contandole, a gomiti piegati le mani entrano in maglia e cargo, ma non è compenetrazione vera.
- **Vertici e oggetti:** l'operatore `vertex_group_smooth` non funziona fuori dalla modalità pesi, quindi la levigatura dei pesi è fatta nello script. Una copia di un oggetto nascosto nei render eredita il nascondimento: `fase2_retopologia.py` ora lo azzera.


Le bozze si vedono solo nelle viste allineate (frontale e laterale), semitrasparenti.

**Convenzioni:**
- Piedi sull'origine, Z in alto, scala e rotazioni applicate.
- Il personaggio guarda **-Y**, quindi il suo lato sinistro è +X e i pezzi si chiamano `.L`/`.R`.
- In Godot andrà ruotato di 180° oppure gestito all'import.
- **A-pose:** braccia aperte a 45° dalla verticale, non lungo i fianchi come nella bozza. È la posa che facilita scheletro e pesi.

**Scala della bozza:** 1,72 m / 967 px, cioè 1,78 mm per pixel. Riferimenti presi sulla bozza: punta dei capelli al pixel 608, suola al pixel 1575, linea centrale x 340.

**Quote ricavate dalla bozza** (valide anche per il nuovo modello):
- occhi 1,60 m, uguali alla camera del gioco (`Head` a 1,6 m, capsula 1,8 m);
- mento 1,47 m;
- spalla 1,37 m;
- cintura 0,935–0,995 m;
- ginocchio 0,48 m;
- risvolti 0,15–0,24 m.

**Lezioni dalla versione precedente** (da non ripetere):
- il tratteggio sotto la bocca nella bozza è la barba con la sua ombra, non il mento;
- il collo è largo e corto: un collo sottile e lungo lascia troppo spazio tra mento e petto;
- evitare il busto "ad ampolla" (fianchi curvi e spalle tonde che si stringono di colpo);
- l'anello di pelliccia è un colletto attorno all'attaccatura del braccio, con lo spallaccio che spunta dal centro, non un anello attorno al braccio;
- la pelliccia da sola costava circa 4.300 triangoli: va pensata dentro il budget fin dall'inizio.

## Versione precedente

Archiviata il 3 novembre 2026 in `blender/personaggi/archivio/`, solo come riferimento:
- `personaggio_n1_v1.blend`: il modello completo a pezzi separati e Decimate a faccette (circa 15.700 triangoli, fasi 0–5, braccia approvate);
- `personaggio_n1.blend` e `script/`: un secondo tentativo appena iniziato (libreria `lib_n1.py`, braccia, busto, testa con Quadriflow e texture generata);
- `tex/`: le ciocche a texture della prima versione, mai usate nel modello finale.

La storia delle revisioni è nella cronologia git di questo file.

## Stato

- (3 novembre 2026) Ripartenza da zero con le skill di progetto. Design confermato.
- Verificato: Blender 5.2.3 LTS risponde sia dal vivo (MCP) sia senza finestra (`run_in_blender.py`); Rigify è disponibile.
- (3 novembre 2026) **Fase 0 fatta**, in attesa di approvazione.
  - `scene_audit.py`: unità in metri a scala 1, nessuna immagine mancante, nessun percorso assoluto, nessun dato orfano.
  - L'unico avviso dell'audit è "senza materiale" sulle due guide a filo, ed è voluto.
  - Controllo a vista, di fronte: le linee delle quote cadono su occhi, mento, spalle, cintura, ginocchia e risvolti della bozza; i piedi sono sull'origine.
  - Controllo a vista, di lato: la camera di gioco (1,6 m) cade all'altezza della fascia degli occhi del profilo.
  - Da sapere: con spallacci e braccia la bozza è larga circa 0,65 m, quindi sta dentro la capsula (0,8 m). Solo gli scarponi sporgono un poco in basso, dove la capsula si arrotonda.
- (3 novembre 2026) Fase 0 approvata.
- (3 novembre 2026) **Fase 1 fatta (corpo base)**, in attesa di approvazione.
  - `N1_Corpo_alto`: 153.457 vertici, 306.910 triangoli, un solo pezzo chiuso; 1,363 × 0,302 × 1,697 m (1,697 è la sommità del cranio, i capelli arrivano a 1,72).
  - `qa_check.py --profile render` superato. Restano due avvisi, accettati: niente UV (si fanno nella fase 2 sulla mesh di gioco) e controlli di z-fighting saltati oltre i 300.000 triangoli (il corpo è un solo pezzo, quindi non servono).
  - Confronto con la bozza (`confronto_fronte.png`, `confronto_profilo.png`): testa, mento, spalle sotto gli spallacci, cintura, gambe dentro i cargo e piedi negli scarponi cadono al posto giusto; di profilo la testa coincide con il viso disegnato.
  - Corretti dopo i render:
    - bacino squadrato "a pantaloncini";
    - deltoidi a pallina staccati dal busto;
    - fasce orizzontali a ogni riga delle tabelle;
    - naso a becco;
    - addominali troppo incisi;
    - interno delle cosce unito dal raccordo;
    - mandibola cancellata dal raccordo;
    - suole 9 mm sotto il pavimento;
    - vertici doppi della simmetria.
  - Volutamente semplici, perché coperti o rifatti dopo: gambe a tubo (sotto i cargo), braccia (sostituite da quelle robotiche), piedi (negli scarponi), viso senza tratti (fase 6). Le dita sono separate ma grossolane, quanto basta per piazzare le ossa.
- (5 novembre 2026) Fase 1 approvata.
- (5 novembre 2026) **Fase 2 fatta (mesh di gioco e UV)**, in attesa di approvazione.
  - `N1_Corpo`: 4.133 quad (8.266 triangoli), nessun triangolo né n-gon, un pezzo solo, simmetrico; 1,344 × 0,301 × 1,697 m.
  - Triangoli per zona: testa e collo 826, busto 2.778, braccia 1.200, mani 506, gambe 2.256, piedi 700.
  - **Stima del budget finale**, circa 13.000 triangoli: testa e collo 826, maglia e cargo dal corpo circa 5.000, scarponi circa 1.000, braccia robotiche circa 3.500, capelli e pelliccia circa 3.000. Braccia e mani del corpo (circa 1.700) si tolgono.
  - Con la sfaccettatura a 0,45 il corpo scende a circa 3.700 triangoli.
  - `qa_check.py --profile game` superato senza avvisi: UV dentro 0–1, nessuna sovrapposizione, nessuna faccia a area zero.
  - Densità UV: 423 px/m a 1024 px, con uno scarto di 1,27 tra le isole. È dentro 1,3, il limite della skill.
- (5 novembre 2026) **Sfaccettatura scelta: C, media.** Fase 2 approvata.
  - Decimate *collapse* simmetrico in X, rapporto 0,45, sui pezzi organici (corpo e vestiti), con ombreggiatura piatta.
  - Si aggiunge come modificatore attivo prima dell'Armature quando si prepara l'export (fasi 8–10).
  - Fino ad allora scheletro, pesi e vestiti si fanno sulla mesh a quad.
- (5 novembre 2026) **Fase 3 fatta (scheletro)**, in attesa di approvazione.
  - Rig di controllo: 404 ossa, di cui 71 deformanti. Scheletro da gioco: 72 ossa, cioè la radice più le 71 deformanti.
  - Pesi: tutti i 4.135 vertici pesati, al massimo 4 influenze, normalizzati, simmetrici (nessuna asimmetria nel campione di `rig_check`), nessun peso sulla radice o su ossa non deformanti.
  - `rig_check.py --profile game` superato. Un solo avviso, atteso: l'animazione va cotta prima dell'export.
  - Pose di stress (`render/fase3_pose.png`, primi piani in `render/fase3_giunture.png`): braccia alzate, gomiti a 130°, anca e ginocchio a 120°, accovacciato, busto ruotato.
    - Nessun collasso di volume a spalle, gomiti, ginocchia e anche.
    - Sotto l'ascella, con le braccia alzate, si forma una piega.
    - Accovacciato, le anche si allargano di lato; le coprono i cargo.
- (5 novembre 2026) Fase 3 approvata.
- (5 novembre 2026) **Fase 4 fatta (vestiti)**, in attesa di approvazione.
  - **Triangoli** (con lo spessore, prima della sfaccettatura), 13.220 in tutto:

    | Pezzo | Triangoli |
    |---|---|
    | Maglia | 4.060 |
    | Cargo | 5.396 |
    | Scarponi | 2.392 |
    | Suole | 524 |
    | Cintura | 512 |
    | Fibbia | 128 |
    | Lacci | 96 |
    | Tasche | 112 |

    Il corpo visibile scende a 2.700 triangoli. Con la sfaccettatura a 0,45 i vestiti diventano circa 6.000.
  - `qa_check.py --profile game` superato su corpo e vestiti, con tolleranza di contatto 6 mm, perché i vestiti stanno di proposito a 4–12 mm dalla pelle. Restano tre avvisi accettati:
    - facce nascoste schiena contro schiena tra la "C" e la piastra e tra piastra e cintura (poche decine di triangoli);
    - un lato senza facce lasciato sul corpo dalla maschera, che sparisce quando all'export si cancellano le facce coperte.
  - **Compenetrazioni** (vertici del corpo, braccia escluse): zero in tutte le pose tranne le braccia alzate, dove 2 vertici della spalla escono dallo scalfo della maglia fino a 2,9 cm. Lì andranno spallaccio e pelliccia.
  - Confronto con la bozza (`render/confronto_fronte.png`): cargo, cintura, scarponi e maglia coincidono con il disegno.
  - Corretti dopo i render e i controlli:
    - maglia a collo alto;
    - "C" della fibbia rovesciata;
    - ginocchio dei cargo a palla nelle pose;
    - tasca destra rovesciata;
    - facce sovrapposte tra scarpone e suola, cargo e cintura, maglia e cintura, tasca e cargo, e dentro la fibbia;
    - suole con UV schiacciate e uno slot di materiale vuoto;
    - pezzi senza UV;
    - corpo nascosto nei render.
  - **Da sistemare nella fase 5:** gli scalfi della maglia sono a dente di sega, con fessure tra maglia e spalla. Si rifiniscono quando si sa dove si attacca il braccio robotico; li copriranno spallacci e pelliccia.
  - **Da tenere d'occhio:**
    - Accovacciato e con l'anca piegata, i cargo fanno un ginocchio tondo e voluminoso: accettabile per pantaloni larghi.
    - Lo spessore raddoppia i triangoli dei capi: se il budget stringe, si può tenere solo sui bordi visibili.

## Problemi aperti

- **Stile e skill:** le skill puntano a personaggi lisci con normal map; lo stile del gioco vuole facce grandi e piatte. Va verificato già nella fase 2 che la retopologia a quad, con ombreggiatura piatta, dia l'aspetto di `stile_poligonale.png` e resti dentro il budget.
- **Personaggi organici:** il `RECAP.md` li valuta il punto debole di Claude in Blender. Le skill aiutano su scheletro, pesi e vestiti, non sulla scultura fine: il viso potrebbe richiedere ritocchi a mano.
