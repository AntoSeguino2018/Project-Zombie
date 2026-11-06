# Personaggio N.1

Primo personaggio giocabile. Bozza a penna: `blender/Peronaggio_N1_bozza.jpeg` (vista frontale, testa di profilo, braccio robotico di lato, mano robotica).

## Riferimenti

In `blender/personaggi/riferimenti/`. La cartella è solo locale ed esclusa da git, perché contiene immagini di terzi e la foto di una persona reale.
- `stile_poligonale.png`: lo **stile** da seguire. Superfici a facce grandi e piatte, forme massicce, materiali leggibili.
- `anatomia.png`: l'**anatomia** del corpo, per quanto stilizzata. Contiene i gruppi muscolari di fronte e da dietro.
- `capelli_mullet.png` e `capelli_mullet_2.png`: il **taglio**. Sopra corti, ricci e scompigliati che ricadono in avanti; lati sfumati sopra e dietro l'orecchio; dietro mullet mosso fino alla base del collo.
- `foto_viso_fronte.webp`, `foto_viso_profilo.webp`: **foto dello sviluppatore** (6 novembre 2026). Sono il riferimento principale per viso, barba e capelli: il personaggio è lui.
- `bozza_viso.webp`: **bozza del viso**, per testa e collo.
  - Collo largo e corto che parte da sotto le orecchie.
  - Barba corta: baffi collegati a un pizzetto pieno sul mento.
  - Lati rasati scuri, ciuffi a punta sopra e dietro le orecchie.

## Design

- **Altezza:** 1,72 m.
- **Fisico:** muscoloso, spalle larghe, proporzioni della bozza.
- **Capelli:** mullet moderno, castano scuro (rivisto il 5 novembre 2026 con lo sviluppatore).
  - Sopra un **ciuffo in avanti**.
  - Ai lati una sfumatura corta: le orecchie restano scoperte.
  - Dietro una **massa unica e folta**, non troppo lunga, che si ferma sopra la base del collo.
- **Viso:** testa proporzionata, non grande né tonda. **Niente occhi:** al loro posto una zona d'ombra voluta, simmetrica.
  - Rivisto il 5 novembre 2026 con lo sviluppatore:
    - **naso ben piazzato**, all'italiana;
    - **mento ben squadrato**;
    - **baffi e pizzetto simil Tony Stark**, con il pizzetto che copre solo il mento.
  - Rivisto sulle foto il 6 novembre 2026:
    - pelle mediterranea chiara;
    - sopracciglia folte e scure;
    - **baffi pieni** sul labbro superiore fino agli angoli della bocca;
    - **barba scura sul mento** con la striscia sotto il labbro;
    - barba corta più chiara lungo la mascella e sotto il mento;
    - guance pulite.
- **Collana:** catenina con una targhetta rettangolare sul petto.
- **Maglia:** nera, attillata.
- **Braccia:** robotiche dalle spalle alle mani, **acciaio chiaro pulito**, senza luci.
  - Segmentate: braccio, gomito, avambraccio con una fila di bulloni esagonali lungo il lato.
  - Mani robotiche: vite a croce sul dorso, borchie sulle nocche, polsino.
- **Spallacci:** piastre sulle spalle con il bullone centrale e le **punte**.
- **Pelliccia** (rivista il 5 novembre 2026 con lo sviluppatore): folta, sul **busto**, a fare da separatore tra busto e braccia.
  - Per lato, un cumulo simile a un anello che passa sopra il trapezio, continua dietro sulla schiena e si chiude ad anello sotto l'ascella.
  - Molto folta sopra, poco sotto.
  - **Non copre le spalle metalliche.**
  - Niente cappuccio.
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
  - `GAME_RIG_N1_Corpo`: lo scheletro da gioco, con la radice e le ossa deformanti senza prefisso `DEF-`; copia le pose del rig di controllo. Dalla fase 9 ha le clip cotte `GAME_RIG_N1_Corpo|<clip>` (a riposo è su `Ferma`), mentre le clip del rig di controllo hanno il nome semplice;
  - i widget di Rigify (collezione `WGTS_…`), esclusi dalla vista.
- `N1_Vestiti` (fase 4): `N1_Maglia`, `N1_Cargo`, `N1_Tasca.L`/`.R`, `N1_Cintura`, `N1_Fibbia`, `N1_Scarponi`, `N1_Suole`, `N1_Lacci`, tutti legati a `GAME_RIG_N1_Corpo`.
  - Sul corpo ci sono i gruppi `Zona_*` (le zone da cui nascono i capi) e i modificatori Mask `Hidden_*`, che nascondono la pelle coperta.
  - L'attributo `N1_braccio` segna braccia e mani del corpo.
- `N1_Braccia` (fase 5): `N1_Braccio.L`/`.R` e `N1_Spallaccio.L`/`.R`, legati a `GAME_RIG_N1_Corpo` con pesi rigidi. Le braccia del corpo sono nascoste dal Mask `Hidden_N1_Braccia`.
- `N1_Accessori` (fase 6): `N1_Collana`, cioè catenina, targhetta e anellino in un oggetto, con i pesi copiati dal corpo.
- `N1_Capelli` (fase 7):
  - `N1_Capelli`: massa, ciuffo in avanti e ciocche, rigidi sull'osso della testa `spine.006`;
  - `N1_Pelliccia`: i due anelli sul busto, con i pesi copiati dal corpo e limitati a colonna e clavicole.
- Le altre collezioni del modello si aggiungono fase per fase.

**Script** in `blender/personaggi/script/`, tutti senza finestra con `run_in_blender.py`:
- `fase0_preparazione.py`: riscrive il file da zero (riferimenti e guide);
- `fase1_corpo_base.py`: rifà solo `N1_Alto`;
- `fase2_retopologia.py [-- --quad N --prova]`: rifà `N1_Corpo` da `N1_Corpo_alto` (con `--prova` riporta solo i triangoli per zona, senza salvare);
- `fase3_scheletro.py`: rifà metarig, rig, pesi, scheletro da gioco e pose di prova (toglie quelli vecchi);
- `fase4_vestiti.py`: rifà tutti i vestiti (toglie i vecchi, le maschere e i gruppi `Zona_*`/`Hidden_*`) e misura le compenetrazioni nelle pose;
- `fase5_braccia.py`: rifà braccia e spallacci e nasconde le braccia del corpo. **Va rilanciato dopo ogni `fase4_vestiti.py`**, perché quello toglie tutte le maschere del corpo;
- `fase6_viso.py`: colora le zone del viso sul corpo e rifà la collana;
- `fase7_capelli.py`: colora il cuoio capelluto sul corpo e rifà capelli e pelliccia. Va rilanciato dopo ogni `fase6_viso.py`, che rifà i materiali del corpo;
- `fase8_colori.py [-- --viso bordi|protetto|sfaccettato --prova]`: colori definitivi e modificatori di sfaccettatura. Va rilanciato dopo le fasi che rifanno corpo o vestiti, perché quelle tolgono i modificatori;
- `fase9_animazioni.py`: rifà le clip sul rig di controllo, le cuoce sullo scheletro da gioco e controlla i cicli. Va rilanciato dopo ogni `fase3_scheletro.py`, che rifà i rig;
- `fase10_export.py`: esporta per Godot `assets/models/characters/personaggio_n1.glb` e `personaggio_n1_pugno.glb`. Lavora solo in memoria e non salva il `.blend`: si rilancia dopo qualunque altra fase.

**Ordine di rilancio:** ogni fase lavora su quello che producono le precedenti. Se cambia il corpo (fase 1 o 2), si rilancia tutto in fila: 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10. Gli script danno sempre lo stesso risultato e la catena intera dura circa un minuto.
- `verifica_pose.py -- --out FILE.png`: foglio con le pose di prova (fotogrammi 1, 10, 20, 30, 40, 50) di fronte e di tre quarti;
- `verifica_bozza.py -- --out CARTELLA`: render ortogonale allineato pixel per pixel alla bozza, sovrapposto in trasparenza, di fronte e di profilo;
- `verifica_export.py -- --out FILE.png` (senza `--blend`): reimporta i due `.glb` in una scena vuota e li rende con i colori della texture, il personaggio in cinque clip e il pugno da sei lati.

I render di verifica vanno in `blender/personaggi/render/` (esclusa da git).

**Da sapere:** dal vivo la vista 3D di Blender non si ridisegna mentre la finestra è in secondo piano, quindi le schermate via MCP possono mostrare un fotogramma vecchio. Per i confronti valgono i render senza finestra.

**Corpo base (fase 1):** forme a sezioni, con le stesse tabelle di busto e testa della versione precedente, interpolate in modo morbido (Catmull-Rom; quella lineare lasciava una fascia a ogni riga). Le parti si fondono in una griglia SDF a 4 mm con Geometry Nodes.
- **Busto e braccia** passano dal raccordo delle giunture concave (`SDF Grid Fillet`, 12 passate): così spalle e ascelle sono morbide.
- **Testa, gambe e mani** si uniscono dopo, senza raccordo: il raccordo riempiva la mandibola, l'interno delle cosce e lo spazio tra le dita.
- Poi levigatura (20 passate, viso e mani quasi fermi), muscoli come rilievi lungo la normale (pettorali, addominali, clavicole, scapole, dorsali, glutei) e simmetria da +X.
- Nel nodo `SDF Grid Boolean` in modalità unione le griglie vanno tutte nell'ingresso multiplo "Grid": "Grid 1" serve solo alla differenza.

**Mesh di gioco (fase 2):** stessa procedura di `auto_retopo.py --method quadriflow` della skill. Prima si fa una copia della sorgente con remesh a voxel, poi Quadriflow simmetrico, poi la proiezione sulla sorgente.
- **Quanti quad:** Quadriflow ne dà meno di quanti se ne chiedono, e quanti dipende dalla sorgente: con 5.000 richiesti ha dato 4.133 e poi 3.333, con 6.000 ne ha dati 5.129. Ora se ne chiedono 4.800, per stare a circa 4.000 sul corpo.
- **Testa più fitta (dalla fase 6):** sopra il mento (1,465 m) la testa si suddivide una volta, quindi ogni quad diventa quattro, e i punti nuovi vanno sulla sorgente. I pochi n-gon del bordo si triangolano. Le UV sono automatiche, con `uv_pack.py --method smart`: i colori sono pieni, e le UV servono a vestiti ed export.
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

**Braccia robotiche (fase 5):** rifatte da zero con la skill `blender-hardsurface-modeling`, approccio mid-poly. Le braccia approvate della versione precedente sono rimaste in archivio, per scelta.
- **Costruzione:** ogni pezzo segue l'osso che lo muove (testa e coda lette dallo scheletro da gioco) ed è rigido, con tutti i vertici al 100% su quell'osso. Un oggetto per braccio con un gruppo per osso (18), più uno per spallaccio.
- **Pezzi**, in acciaio chiaro e metallo scuro:

  | Pezzo | Osso | Com'è |
  |---|---|---|
  | Flangia | spalla (`shoulder`) | anello scuro attorno all'attacco del braccio, copre lo scalfo |
  | Giunto | braccio (`upper_arm`) | sfera scura |
  | Omero | braccio | due segmenti ottagonali e una fascia scura sopra il gomito |
  | Gomito | avambraccio (`forearm`) | cerniera scura con l'asse verso l'esterno e calotta dietro |
  | Avambraccio | avambraccio | prisma ottagonale rastremato con cinque bulloni esagonali sul lato esterno |
  | Polsino | avambraccio | anello scuro |
  | Mano | mano (`hand`) | palmo con la vite a croce sul dorso (un pezzo solo) e borchie sulle nocche |
  | Dita | una falange per osso | pollice compreso |
- **Spallaccio:** piastra esagonale di circa 16 × 14 cm, poco bombata (sfera di 16 cm di raggio, 30°), con bullone centrale e due punte, verso il collo e verso l'esterno.
  - Sta sull'osso del braccio: legato alla spalla, alzando il braccio veniva attraversato.
  - Lascia lo spazio per gli anelli di pelliccia.
- **Smusso:** 1,5 mm, solo sugli spigoli oltre i 50° dei pezzi grandi, segnati con il peso di smusso. Sui pezzi piccoli (bulloni, borchie, dita, punte) collassava in facce degeneri.
- **Scalfi della maglia** (in `fase4_vestiti.py`): il bordo è riportato sul piano del taglio, 2,5 cm prima del perno della spalla.


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
  - ~~Da sistemare nella fase 5: scalfi della maglia a dente di sega.~~ Fatto nella fase 5.
  - **Da tenere d'occhio:**
    - Accovacciato e con l'anca piegata, i cargo fanno un ginocchio tondo e voluminoso: accettabile per pantaloni larghi.
    - Lo spessore raddoppia i triangoli dei capi: se il budget stringe, si può tenere solo sui bordi visibili.
- (5 novembre 2026) Fase 4 approvata e committata.
- (5 novembre 2026) **Fase 5 fatta (braccia robotiche e spallacci)**, in attesa di approvazione.
  - **Triangoli:** 1.356 per braccio e 352 per spallaccio, 3.416 in tutto, dentro i circa 3.500 previsti.
  - **Stima del totale**, circa 13.000 triangoli, dentro il budget:

    | Parte | Triangoli |
    |---|---|
    | Corpo visibile (testa e collo) | circa 1.000 |
    | Vestiti sfaccettati | circa 6.000 |
    | Braccia | 3.416 |
    | Capelli e pelliccia, previsti | circa 3.000 |

  - **`qa_check.py --profile game`** superato sulle braccia e su tutto il personaggio insieme. Restano avvisi accettati:
    - 44 n-gon per braccio, tutti tappi piatti di pezzi rigidi, che la skill ammette;
    - facce nascoste schiena contro schiena, cioè le basi dei bulloni affondate di 2 mm;
    - 28 lati senza facce lasciati sul corpo dalle maschere, che spariscono quando all'export si cancellano le facce coperte.
  - **Confronto con la bozza:** gli spallacci cadono dove li disegna la bozza, con la stessa misura.
  - **Pose di stress:** i pezzi si muovono rigidi con le ossa e lo spallaccio segue il braccio alzato.
  - **Compenetrazione:** con le braccia alzate escono dallo scalfo 16 vertici della spalla, fino a 3,4 cm (prima della pulizia del bordo erano 2). Stanno sotto flangia e spallaccio, e li coprirà la pelliccia.
  - **Corretti dopo i controlli:**
    - spallaccio troppo piccolo, che lasciava scoperti giunto e omero;
    - spallaccio attraversato dal braccio alzato;
    - facce degeneri dello smusso sui pezzi piccoli;
    - croce della vite in due barre sovrapposte;
    - tappi della cerniera del gomito complanari con la fascia;
    - triangoli quasi doppi rispetto alla stima, per lo smusso a 35° anche sui lati degli ottagoni.
- (5 novembre 2026) Fase 5 approvata.
- (5 novembre 2026) **Fase 6 fatta (viso, collana e targhetta)**, in attesa di approvazione.
  - **Tratti del viso** (`viso()` in `fase1_corpo_base.py`), come rilievi nella sorgente:
    - arcata a tettoia;
    - fascia degli occhi incavata;
    - naso lungo e dritto, dalla radice a sopra la bocca;
    - zigomi, labbra con la linea della bocca, mento squadrato.

    Le ampiezze sono marcate (8–12 mm sull'arcata), perché con quad di 1 cm i rilievi di pochi millimetri spariscono.
  - **Colori a zone sulla mesh del corpo** (`fase6_viso.py`):
    - pelle mediterranea `M_N1_Pelle`;
    - zona d'ombra `M_N1_Ombra` solo nelle orbite, con la radice del naso in mezzo così non sembra una benda;
    - linea della bocca `M_N1_Bocca`;
    - baffi collegati al pizzetto pieno `M_N1_Barba`, appena più scuri della pelle (quasi rasati).

    Le zone seguono le facce, quindi i bordi sono a gradini, come il resto dello stile.
  - **Collana:** catenina a sezione triangolare che gira attorno alla base del collo sulla pelle e scende a V sulla maglia.
    - Si appoggia alla superficie più esterna, pelle o maglia, cercandole insieme; prima faceva gli scalini sul bordo dello scollo.
    - Finisce sulla targhetta d'acciaio, di 2,4 × 3,6 cm con l'anellino, a 1,35 m, inclinata di 12° come il petto.
  - **Effetto sulle altre fasi:** la testa più fitta ha cambiato il corpo, quindi le fasi 2–5 sono state rilanciate. Nella fase 4 lo scalfo si riporta sul piano solo dove il taglio è il piano: sotto l'ascella è il cilindro attorno al braccio, e portarlo sul piano scopriva una striscia di pelle. Nella fase 5 le braccia del corpo si nascondono senza l'anello di margine.
  - **Triangoli prima della sfaccettatura:** 21.154 in tutto.

    | Parte | Triangoli |
    |---|---|
    | Corpo visibile | 3.278 |
    | Vestiti | 14.000 |
    | Braccia | 3.416 |
    | Collana | 460 |

    Con la sfaccettatura a 0,45 su corpo e vestiti il totale scende a circa 11.600; con capelli e pelliccia (circa 3.000) arriva intorno a 14.600, **al limite dei 15.000**. Se il viso resta senza sfaccettatura, perché perderebbe i tratti, si arriva a circa 16.000: lo si decide nella fase 8.
  - **`qa_check.py --profile game`** superato su tutto il personaggio. Restano gli avvisi accettati delle fasi precedenti:
    - n-gon dei tappi piatti delle braccia;
    - basi dei bulloni affondate;
    - lati e vertici lasciati sul corpo dalle maschere, che spariscono all'export.
  - **Compenetrazione del corpo nella maglia** (portata 3 cm; con 10 cm i raggi attraversavano l'ascella e davano falsi positivi):
    - a riposo 3 vertici, sotto 1 mm;
    - braccia alzate: 9 vertici, fino a 3 cm, sotto spallaccio e pelliccia;
    - busto ruotato: 4 vertici, fino a 2,8 cm.

- (5 novembre 2026) Fase 6 approvata.
- (5 novembre 2026) **Fase 7 fatta (capelli e pelliccia)**, in attesa di approvazione.
  - **Tecnica scelta: ciocche solide sfaccettate**, a colori pieni, nello stile del resto del modello. Niente carte con texture.
  - **Cuoio capelluto** (facce della testa del corpo):
    - castano scuro `M_N1_Capelli` sopra e sulla nuca (517 facce);
    - ricrescita `M_N1_Rasato`, tra pelle e castano, sui lati e dietro le orecchie (246 facce).
  - **Capelli** (1.538 triangoli), in un solo oggetto rigido sulla testa:
    - **calotta:** piena e bitorzoluta, costruita per raggi dal centro della testa. L'attaccatura è bassa sulla fronte, alta sui lati rasati e bassissima dietro. Spessore da 1 a 2 cm, con un lato interno 2 mm sotto la pelle.
    - **ciuffi** a sezione di rombo che si stringono fino alla punta e restano fuori dalla testa:
      - frangia di 7 ciuffi che ricade sulla fronte con la punta che si alza;
      - 15 ricci scompigliati sopra;
      - 2 dietro ogni orecchio;
    - **mullet:** 9 ciocche larghe e mosse dalla nuca alla base del collo, a lunghezze alterne, con la punta all'indietro.
  - **Pelliccia** marrone scuro (1.102 triangoli):
    - due anelli bitorzoluti attorno all'attacco del braccio, sotto gli spallacci (raggio 8 cm, sezione 2,6 cm), con 8 ciuffi corti ciascuno;
    - cappuccio abbassato che segue la schiena dal collo alle scapole: bordo basso a U fino a 1,225 m al centro, rotolo spesso attorno al collo e una frangia di 7 ciuffi in basso.
  - **Corretti dopo i render:**
    - ciocche attaccate sul lato sbagliato della testa (mullet sul viso), per il verso del raggio rovesciato;
    - anelli di pelliccia che uscivano sopra gli spallacci;
    - frangia a coroncina di punte;
    - mullet a fili sottili;
    - lato interno del cappuccio complanare con la maglia.
  - **`qa_check.py --profile game`** superato su tutto il personaggio (17 oggetti), con gli stessi avvisi accettati di prima.
  - **Confronto con la bozza:** la cima dei capelli arriva a 1,72 m come nel disegno.
  - **Triangoli:** 23.794 prima della sfaccettatura. Con la sfaccettatura a 0,45 su corpo e vestiti si stimano circa 14.300; se il viso resta senza sfaccettatura, circa 16.000.
- (5 novembre 2026) **Fase 7 rifatta** su indicazione dello sviluppatore: i capelli diventano un mullet moderno e la pelliccia passa dalle spalle al busto. In attesa di approvazione.
  - **Riferimenti del mullet moderno** cercati in rete ([menshairstylestoday.com](https://www.menshairstylestoday.com/modern-mullet-haircuts-men/), [thefashionisto.com](https://www.thefashionisto.com/mullet-haircut-men/)):
    - dietro un blocco unico e tondo fatto a strati, che arriva al massimo a sfiorare il colletto;
    - ai lati una sfumatura graduale, quasi a pelle vicino all'orecchio;
    - sopra più lungo e mosso, con la frangia o un ciuffo in avanti.
  - **Capelli** (1.126 triangoli, rigidi sulla testa):
    - **massa unica** costruita per raggi dal centro della testa, con spessore variabile:
      - circa 2,5 cm sopra;
      - sottile dove comincia la sfumatura sui lati, con le orecchie scoperte;
      - dietro un blocco pieno che scende fino alla nuca e si ferma sopra la base del collo.
    - **ciuffo in avanti:** 5 ciocche grosse (larghe 4–5 cm) che escono dalla parte alta davanti, salgono e spingono in avanti. La punta resta sopra l'arcata, così non copre gli occhi. Ognuna è ruotata un po' sul suo asse, perché affiancate e parallele avevano lati coincidenti.
    - 7 ciocche corte pettinate indietro sopra e 5 punte corte sul bordo basso del blocco.
    - Niente più ciuffi dietro le orecchie.
  - **Cuoio capelluto:** castano sopra e sulla nuca (600 facce), sfumatura su lati e orecchie (278 facce).
  - **Pelliccia** (1.620 triangoli), un anello per lato appoggiato alla maglia, nel piano quasi verticale che passa sopra il trapezio e si chiude sotto l'ascella (centro a ±0,15 m, 1,32 m):
    - la sezione è un mezzo ellisse più alto e largo sopra (fino a 6 cm) e sottile già sul petto e sulla schiena, con la base affondata di 1 cm sotto la maglia;
    - i ciuffi sono molti sopra e pochi sotto;
    - resta medialmente rispetto alla spalla metallica e non la copre;
    - i pesi sono solo del busto (colonna `spine.001`–`.003` e clavicole): con il braccio alzato la pelliccia resta dov'è e fa da separatore.
  - **`qa_check.py --profile game`** superato su tutto il personaggio. In più ci sono solo 2 coppie di facce nascoste tra maglia e base della pelliccia.
  - **Triangoli:** 23.900 prima della sfaccettatura. Con la sfaccettatura la stima resta circa 14.300.

- (5 novembre 2026) Fase 7 approvata.
- (5 novembre 2026) **Fase 8 fatta (colori e sfaccettatura)**, in attesa di approvazione.
  - **Tavolozza definitiva** in `fase8_colori.py`: colori scritti in sRGB e convertiti in lineare, con le regole di `blender-pbr-materials`.
    - Il metallo è solo 0 o 1, e i metalli hanno il colore di base chiaro: acciaio sRGB 205, ruvidità 0,35.
    - Il "metallo scuro" (bulloni, giunti, fasce, la "C") diventa **metallo verniciato scuro**, cioè non metallo (sRGB 52): un metallo con il colore di base scuro non esiste.
    - I non metalli stanno tra sRGB 30 e 240:
      - maglia e cargo neri sono antracite (40 e 50);
      - l'ombra degli occhi è il minimo (30);
      - la pelle mediterranea (196, 142, 110) sta tra i valori misurati della pelle chiara e di quella scura.
  - **Sfaccettatura:** modificatore `Faccette` (Decimate *collapse* 0,45, simmetrico in X) su corpo, maglia, cargo, scarponi e cintura.
    - Sul corpo va dopo le maschere e prima dell'Armature, quindi si sfaccetta solo la pelle visibile; sui vestiti va prima dello spessore.
    - **Viso: "bordi protetti"**, scelto con lo sviluppatore dopo il confronto in `render/fase8_viso_confronto.png`. Il gruppo `N1_Viso` contiene solo i vertici della testa dove si incontrano due colori (ombra degli occhi, bocca, barba, attaccatura e sfumatura, 268 vertici). Così il viso è sfaccettato come il resto, ma le zone tengono la forma. Interamente sfaccettato, la barba spariva e la bocca diventava un triangolo; protetto per intero, il viso restava a griglia in mezzo a una testa a faccette.
  - **Suole:** Decimate planare (Dissolve, 3°, delimitato da materiali e cuciture), da 672 a 228 triangoli. Erano quasi solo facce piatte.
  - **Budget** (`mesh_stats.py` della skill `blender-game-optimization`): **14.747 triangoli**, dentro l'indicativo di 15.000, e 72 ossa.

    | Parte | Triangoli |
    |---|---|
    | Corpo visibile | 1.475 |
    | Vestiti | circa 6.300 |
    | Braccia e spallacci | 3.416 |
    | Capelli | 1.126 |
    | Pelliccia | 1.620 |
    | Collana | 460 |
  - **Unica voce fuori budget: i materiali**, 15 contro i 6 consigliati, per circa 28 chiamate di disegno. La soluzione della skill è una tavolozza in una texture sola: un materiale, con le UV di ogni faccia sul suo quadratino di colore, e metallo e ruvidità in una seconda texture. È proposta per la fase 10, insieme all'unione delle mesh all'export.
  - **`qa_check.py --profile game`** superato sulla versione sfaccettata, cioè quella che si esporta. In più ci sono solo avvisi accettati: 7 n-gon piatti sulle suole e poche facce nascoste.
  - **Pose di stress:** sfaccettatura e pesi si muovono insieme.

- (5 novembre 2026) **Viso rivisto** su indicazione dello sviluppatore; rilanciata tutta la catena 1 → 8.
  - **Occhi simmetrici:** la mesh di gioco ora è esattamente simmetrica. In `fase2_retopologia.py`, dopo la suddivisione della testa, il lato +X si copia sul lato -X; gli n-gon della cucitura al centro si triangolano. Quadriflow "simmetrico" non lo era al decimo di millimetro, e le zone colorate seguono le facce.
  - **Naso** (`naso()` in `fase1_corpo_base.py`):
    - dorso dritto dalla radice tra gli occhi (1,594 m) alla punta (1,541 m), che esce di circa 3 cm dal viso;
    - un riempimento dietro il dorso, la punta e le ali delle narici.

    Prima usciva solo di circa 1 cm e con la sfaccettatura spariva; ora i suoi vertici sono anche nel gruppo protetto `N1_Viso`.
  - **Mento squadrato:**
    - le ultime righe della tabella della testa sono più larghe e più piatte (sezioni quasi rettangolari, esponente 3);
    - il rilievo del mento è piatto davanti con i fianchi raccordati: con i fianchi netti sembrava una scatoletta attaccata.
  - **Barba simil Stark**, colorata a zone in `fase6_viso.py`:
    - baffi sopra il labbro;
    - una striscia sotto il labbro;
    - il pizzetto, che copre solo il mento;
    - due linee sottili agli angoli della bocca.

    Il colore `M_N1_Barba` è ora marrone scuro (sRGB 78, 53, 39), poco più chiaro dei capelli: con il vecchio colore, vicino alla pelle, il pizzetto spariva. La bocca è un rosso spento (112, 64, 54), con una banda un po' più alta: con facce di 1 cm una banda stretta prendeva due facce sole.
  - **Spessore dei vestiti:** con le normali di qualità e l'offset uniforme insieme, lo spessore sulla mesh sfaccettata mandava un vertice del cargo a 224 m. In `fase8_colori.py` le normali di qualità sono tolte.
  - **Controlli:**
    - **`qa_check.py --profile game`** superato su tutto il personaggio;
    - **Triangoli:** 14.804;
    - **Maglia:** a riposo il corpo la tocca in 10 punti sul bordo dello scalfo, sopra la spalla, sotto 1 mm, sotto flangia, spallaccio e pelliccia.
  - **Limite:** con facce di circa 1 cm, i bordi di baffi, pizzetto e bocca sono a gradini. Si possono rendere più netti suddividendo ancora la parte bassa del viso (circa +300 triangoli, il totale arriverebbe a circa 15.100).
- (6 novembre 2026) **Seconda revisione del viso**, su indicazione dello sviluppatore: naso meno appuntito, bocca e mento in volume (prima sotto il naso c'era una parete troncata), baffi e pizzetto con spessore. Rilanciata la catena 1 → 8.
  - **Naso:** la punta esce di circa 2,5 cm invece di 3 ed è tonda (ellissoide più largo).
  - **Bocca e mento in volume** (`viso()`):
    - labbro superiore e inferiore sporgenti di circa 8 mm, con la linea della bocca in mezzo;
    - il solco sotto il labbro;
    - il mento squadrato che sporge di 1 cm.
  - **Densità:** la parte bassa del viso, il naso e le fasce degli occhi sono suddivisi una volta in più (quad di circa 5 mm). Le fasce degli occhi hanno così un bordo pulito: prima i triangoli al confine della zona suddivisa le sfrangiavano.
  - **Proiezione lungo la normale:** in `fase2_retopologia.py` i vertici della testa vanno sulla sorgente lungo la normale, verso fuori o verso dentro, il più vicino. Con il punto più vicino, un vertice sul piano davanti al naso andava sul viso dietro, e la mesh di gioco perdeva 1,7 cm di naso.
  - **Bocca:** una riga di facce scure (una linea), con le labbra color pelle. Baffi sopra il labbro superiore e striscia sotto il labbro inferiore.
  - **Barba solida** `N1_Barba` (720 triangoli):
    - un guscio chiuso sulle facce colorate a barba, 3,5 mm sopra la pelle e con il lato interno 1 mm sotto, così il bordo non lascia fessure;
    - rigido sull'osso della testa;
    - sta nella collezione `N1_Accessori` e lo rifà `fase6_viso.py`.
  - **Fasce degli occhi:** sono intere nel gruppo protetto dalla sfaccettatura, insieme a naso e bordi dei colori.
  - **Pelliccia:** la sezione degli anelli è aperta sotto. Il lato di chiusura stava dentro il corpo e coincideva con la maglia.
  - **Controlli:**
    - **`qa_check.py --profile game`** superato su tutto il personaggio (18 oggetti);
    - **Triangoli:** 14.688.

- (6 novembre 2026) **Viso e capelli sulle foto dello sviluppatore** (`riferimenti/foto_viso_*.webp`, solo in locale). Rilanciate le fasi 6 → 8.
  - **Zone del viso** (`zona_viso()` in `fase6_viso.py`):
    - sopracciglia folte subito sopra la fascia d'ombra;
    - baffi pieni sul labbro superiore che scendono agli angoli della bocca;
    - barba scura sul mento con la striscia sotto il labbro;
    - barba corta `M_N1_Barbetta` lungo la mascella fino alle orecchie e sotto il mento, sul collo;
    - guance pulite.
  - **Guscio con spessore** `N1_Barba` (1.152 triangoli): 4,5 mm sui baffi, 3,5 mm su mento e striscia sotto il labbro, 2,5 mm sulle sopracciglia. La barba corta è solo colore.
  - **Colori** (`fase8_colori.py`):
    - pelle più chiara (sRGB 214, 166, 138);
    - barba e sopracciglia scure (70, 48, 35);
    - barba corta a metà tra pelle e barba (150, 112, 90).
  - **Capelli** (`fase7_capelli.py`):
    - le ciocche del ciuffo vanno in avanti e ricadono sulla fronte;
    - sopra 8 ciocche corte a punte che salgono in avanti o di lato, come nella foto;
    - lati sfumati e mullet com'erano.
  - **Budget:** gli anelli di pelliccia passano da 28 a 24 sezioni per stare nel budget.
  - **Controlli:**
    - **`qa_check.py --profile game`** superato su tutto il personaggio;
    - **Triangoli:** 14.974;
    - **Materiali:** 16.

- (6 novembre 2026) Fase 8 approvata, con il viso rivisto.
- (6 novembre 2026) **Fase 9 fatta (animazioni)**, in attesa di approvazione. Le clip sono fatte da script (`fase9_animazioni.py`), scelta dello sviluppatore: niente mocap.
  - **Come sono fatte:**
    - si animano i controlli del rig `RIG_N1_Corpo`, con le gambe in IK (piedi a terra) e le braccia in FK;
    - poi `bake_action.py` le cuoce sullo scheletro da gioco, in azioni `GAME_RIG_N1_Corpo|<clip>` (sono queste che vanno in Godot);
    - le clip di movimento sono sul posto, senza spostamento della radice: in Godot la velocità di riproduzione si regola sulla velocità del giocatore partendo da quella nominale qui sotto;
    - 30 fotogrammi al secondo.
  - **Clip:**

    | Clip | Fotogrammi | Ciclo | Velocità nominale | Com'è |
    |---|---|---|---|---|
    | `Ferma` | 60 | sì | — | respiro, testa che si guarda intorno piano |
    | `Cammina` | 18 | sì | 3,2 m/s | passo di 0,95 m, braccia che oscillano |
    | `Corsa` | 16 | sì | 4,7 m/s | passo di 1,25 m, busto in avanti, gomiti piegati |
    | `Indietro` | 20 | sì | 2,1 m/s | passo corto di 0,70 m |
    | `Sinistra`, `Destra` | 18 | sì | 1,1 m/s | corsetta laterale, il piede in volo passa davanti all'altro |
    | `Salto` | 24 | no | — | piegamento, spinta, gambe raccolte; l'ultimo fotogramma è in volo e si tiene fino all'atterraggio |
    | `ATerra` | 30 | sì | — | prono, sulle braccia, che striscia tirando a turno; il bacino resta vicino all'origine, dove sta la capsula |
    | `Rianima` | 40 | sì | — | in ginocchio (il destro a terra), busto in avanti, due spinte delle mani per ciclo |

    Nel gioco la camminata va a 7 m/s e lo scatto a 11 m/s (`game/player/fps_controller.gd`): la camminata si riprodurrà a circa 2,2 volte e la corsa a circa 2,3. Se a quelle velocità le gambe sembrano troppo veloci, si allunga il passo.
  - **Ogni clip mette le chiavi su tutte le ossa che almeno una clip muove.** Prima ognuna chiavava solo le sue, e le altre tenevano la posa della clip di prima: Rianima ereditava la radice ruotata di ATerra (il personaggio era sdraiato), ATerra il busto del Salto. Lo stesso sarebbe successo in Godot passando da una clip all'altra.
  - **Controlli** (`loop_check.py` della skill sulle azioni cotte):
    - nessuno scatto (*pop*) in nessuna clip;
    - nei cicli di passo restano segnalati degli *hitch* su cosce e stinchi, cioè la velocità dell'osso cambia tra la fine e l'inizio del ciclo. Sono state provate le curve cicliche, il sollevamento del piede a seno al quadrato, una chiave per fotogramma e il ciclo che parte a metà appoggio: restano, perché sono l'accelerazione vera della gamba quando il piede si stacca. Nei fogli la camminata non mostra salti;
    - fogli di verifica in `render/fase9_*.png`.
  - **Non verificato:** le compenetrazioni dei vestiti nelle pose delle clip (controllate solo a occhio nei fogli) e l'aspetto in Godot alle velocità vere.

- (6 novembre 2026) Fase 9 approvata.

- (6 novembre 2026) **Fase 10 fatta (in Godot)**, in attesa di approvazione. Scelte con lo sviluppatore: in prima persona solo il pugno, e il colore del giocatore solo sul nome.
  - **Export** (`fase10_export.py`, impostazioni del preset `godot` della skill `blender-export-pipelines`). Tutto avviene in memoria, senza salvare il `.blend`:
    - ogni oggetto diventa la sua mesh valutata senza l'Armature, quindi maschere, sfaccettatura, spessori e smussi sono applicati, i pesi restano, e la pelle coperta dai vestiti sparisce davvero;
    - le 18 mesh si uniscono in `N1_Personaggio`, legata a `GAME_RIG_N1_Corpo`;
    - i vincoli dello scheletro da gioco verso il rig di controllo si spengono, e le azioni cotte prendono il nome della clip;
    - lo script della skill (`export_asset.run`) non si usa direttamente perché raccoglie anche i figli dello scheletro, cioè gli oggetti originali: si usano le sue impostazioni.
  - **Tavolozza:** i 16 materiali diventano uno solo, `M_N1`.
    - Il colore viene da `T_N1_Tavolozza`, una texture 256 × 256 a 4 × 4 quadrati di 64 px. Ogni faccia ha tutte le UV al centro del quadrato del suo colore: senza differenze di UV dentro la faccia, la texture si legge sempre al livello pieno e i colori vicini non si mescolano.
    - Metallo e ruvidità vengono da `T_N1_MetalloRuvido` (G = ruvidità, B = metallo, come vuole glTF).
    - I valori sono gli stessi della fase 8. In Godot le due texture sono senza compressione (`compress/mode=0`, e `detect_3d/compress_to=0` perché non passino alla compressione video), così i colori restano esatti.
  - **File** in `assets/models/characters/`:

    | File | Cosa | Numeri |
    |---|---|---|
    | `personaggio_n1.glb` | il personaggio visto dagli altri | 1 mesh, 1 materiale, **14.974 triangoli**, 71 ossa, 9 clip, 2,3 MB |
    | `personaggio_n1_pugno.glb` | avambraccio e mano sinistra a pugno, fissi | 968 triangoli, 39 cm, stesso materiale |

    Le chiamate di disegno passano da circa 28 a 1 per giocatore, più l'ombra.
  - **Pugno:** è il braccio sinistro (`N1_Braccio.L`) valutato con le dita chiuse (75°, 95° e 70° per falange, pollice 10°, 35° e 45°) e tagliato all'avambraccio. Il centro della mano è nell'origine, l'avambraccio va verso +Z di Godot (verso la camera) e il dorso è in alto.
  - **In Godot:**
    - `game/characters/personaggio_n1.tscn`: il `.glb` girato di 180° (in glTF guarda +Z, il giocatore guarda -Z) con lo script `player_model.gd` (classe `PlayerModel`);
    - `PlayerModel` sceglie la clip dallo stato del `FpsController` padre: Ferma, Cammina, Corsa (da 8,5 m/s), Indietro, Sinistra/Destra secondo la direzione; Salto dopo 0,12 s in aria, partendo dallo stacco (0,25 s); ATerra a terra (ferma se non si striscia) e da morti; Rianima mentre si rianima;
    - la velocità di riproduzione è la velocità vera divisa per quella nominale della clip, tra 0,5 e 2,5. La velocità la ricava dalla posizione, quindi vale anche per i giocatori remoti, di cui si conosce solo quella;
    - chi rianima lo sanno chi controlla il giocatore e l'host; gli altri lo deducono da un compagno a terra vicino che si sta rialzando;
    - `player.tscn`: la capsula e la visiera sono tolte e c'è il nodo `Body`. Il giocatore locale vede del proprio corpo solo l'ombra, come prima;
    - il pugno (`Camera3D/Melee/Fist/Arm`) sostituisce le due scatole, senza ombra, con l'avambraccio girato di 15° verso l'esterno e 10° verso il basso.
  - **Verifiche:**
    - reimport in Blender (`render/fase10_export.png`): colori dalla texture giusti, clip e pugno a posto;
    - foto in Godot con il cielo del livello di prova (`render/fase10_godot_*.png`): modello girato come il giocatore, clip, ombre, acciaio che riflette il cielo, pugno in prima persona;
    - `tests/test_38.gd` (nuovo): una mesh e un materiale, altezza, nove clip con i cicli giusti, direzione -Z, piedi a terra, solo ombra per sé, clip per fermo, avanti, scatto, indietro, lati, salto, a terra, strisciando e rialzati, pugno;
    - `net_combat` e `net_revive` controllano le clip invece della rotazione della capsula: a terra ATerra, rialzato no, e Rianima per chi rianima, visto da sé e dall'host.
  - **Non fatto:** le braccia sulle armi (una presa per arma, nelle schede delle armi), l'arma in mano vista dagli altri, il busto che segue la mira in alto e in basso.

- (6 novembre 2026) Fase 10 approvata: il Personaggio N.1 è finito e in gioco.

## Problemi aperti

- **Piedi che scivolano** in gioco sui lati e all'indietro: lì si va a 7 m/s, mentre le clip sono animate a 1,1 e 2,1 m/s, e la riproduzione si ferma a 2,5 volte. Si risolve allungando il passo di quelle clip nella fase 9, oppure alzando il limite in `PlayerModel.speed_scale_range`.
- **Gli altri non vedono l'arma** in mano al personaggio, e il busto non segue la mira in alto e in basso (in rete c'è già `sync_pitch`).
- **Gruppi di vertici in più:** `N1_Personaggio` ha 97 gruppi senza ossa (le zone dei vestiti, `N1_Viso` e altri). L'export li ignora; si possono togliere nello script se servisse.
- **Personaggi organici:** il `RECAP.md` li valuta il punto debole di Claude in Blender. Il viso è stilizzato a rilievi e zone di colore: se serve più carattere, un ritocco a mano sulla sorgente si propaga rilanciando le fasi 2–6.
