# Recap per chi riprende il progetto

Questo file riassume cosa è stato fatto finora, come è fatto il gioco e come si lavora. Serve a far partire in fretta una nuova sessione (persona o istanza di Claude). Le fonti di verità restano [DESIGN.md](DESIGN.md) (idee e decisioni di gioco) e [ROADMAP.md](ROADMAP.md) (passi fatti e da fare); in caso di dubbio vincono loro.

**Aggiornato al 9 novembre 2026.** Fatti, approvati e pushati (ultimo commit `8ff103e` su `main`):
- il **Personaggio N.1**, rifatto da zero in Blender con le skill e messo in gioco (dal 3 al 6 novembre);
- i passi **3.7–3.10**: il campus di Monte Sant'Arcangelo a zone, l'elicottero per vincere, le armi bianche e i proiettili da carro armato (8 novembre).

Prossimo passo: il playtest della run completa (3.11), che fa lo sviluppatore.

Schede di dettaglio:
- [`docs/armi/`](docs/armi/LEGGIMI.md): una per ogni arma con il modello vero;
- [`docs/mappa/campus.md`](docs/mappa/campus.md): la mappa;
- [`docs/personaggi/personaggio_n1.md`](docs/personaggi/personaggio_n1.md): il personaggio.

---

## 1. Il gioco in breve

- **Cos'è:** FPS roguelike in prima persona, co-op online da 1 a 4 giocatori, contro orde di zombie colorati e per niente cupi. **Le armi sono le protagoniste.**
- **Stile visivo:** low-poly alla *Deep Rock Galactic*: forme grosse e leggibili, flat shading, luci colorate, colori forti solo su ciò che conta (nemici, armi, oggetti).
  - **Modelli veri:** il Personaggio N.1 e la Magnum.
  - **Ancora in greybox (cubi e capsule):** il resto, mappa e zombie compresi.
- **Storia (dall'8 novembre 2026):** studenti di ingegneria restano bloccati all'università durante un'apocalisse zombie. Sopravvivono con le armi e soprattutto con i **progetti segreti del campus fatti con l'esercito**: da qui le armi assurde, i proiettili da carro armato e i laboratori nascosti.
  - Il gioco nasce dal gruppo universitario dello sviluppatore (persone, aule studio, coffee break, meme). Le battute restano il "DNA" di armi, nemici e nomi.
  - **L'università si vede, con i nomi storpiati:** "Monte Sant'Arcangelo", "Università Federico III". Ha sostituito la vecchia regola "nessun riferimento all'università".
- **Mondo:** il campus di Monte Sant'Arcangelo, ispirato al complesso di Monte Sant'Angelo della Federico II. È diviso in zone che si aprono a pagamento, come la modalità zombi di Black Ops 2. Il tono è caciarone, non inquietante.
- **Pilastri:**
  1. le armi prima di tutto (comuni → truccate → sbroccate);
  2. zombie mai visti, ognuno con un comportamento riconoscibile;
  3. caos co-op leggero.
- **Struttura della run (attuale):**
  - una mappa grande che si apre a pagamento;
  - ondate con un budget di pericolosità crescente;
  - soldi personali e oggetti passivi impilabili;
  - giocatori a terra rianimabili;
  - run persa se cadono tutti, **vinta scappando con l'elicottero** dal tetto della torre (provvisorio, per provare).
- **Ancora da decidere:**
  - cosa succede tra le ondate;
  - altri modi di vincere;
  - la natura degli zombie;
  - le armi sbroccate, che attendono i meme del gruppo;
  - il ruolo della distruzione.

## 2. Come si lavora

- **Lingua:** tutto in italiano: risposte, commenti nel codice, messaggi di commit, documenti, testi del gioco.
- **Lo sviluppatore:** lavora quasi da solo, 5–15 ore a settimana. Prova ogni passo con **F5** nell'editor e decide cosa è divertente. Disegna i riferimenti.
- **Claude:** scrive codice e scene e li verifica in tre modi:
  - con **test automatici**, senza grafica e in rete con più istanze;
  - con **foto in finestra**: uno script porta la camera nei punti da mostrare;
  - poi spiega cosa provare.
- **Commit e push solo dopo l'approvazione esplicita** dello sviluppatore (di solito "Sì, commit" e "Sì, push"), mai prima. L'approvazione di un passo non vale come approvazione del commit.
  - Messaggio nel formato `Passo X.Y: titolo` più un elenco puntato in italiano, con la riga `Co-Authored-By` richiesta dall'ambiente.
  - Si lavora su `main`, remoto GitHub `AntoSeguino2018/Project-Zombie`.
  - Due passi che toccano gli stessi file possono andare in un commit solo (`Passi 3.7 e 3.8: ...`).
- **Un passo alla volta:** si propone il passo, lo sviluppatore approva, si implementa, si testa, si mostra, si committa.
  - Per i lavori grandi prima si propone il piano (es. la pianta della mappa) e si fanno le domande che cambiano il lavoro.
  - Le idee nuove vanno nella sezione "Idee raccolte" della roadmap o in DESIGN.md come 💡.
- **Schede:**
  - **Armi:** una per ogni arma con il modello vero, in `docs/armi/` (schema in `docs/armi/LEGGIMI.md`). Le armi di base e le armi bianche sono in cubetti e non l'hanno ancora.
  - **Mappa:** `docs/mappa/campus.md`.
  - **Personaggio:** `docs/personaggi/personaggio_n1.md`.
  - Ogni scheda si tiene aggiornata con i difetti trovati e corretti.
- **Essere onesti:** dire cosa non si è verificato (spesso: "non provato giocando"), cosa non si riesce a riprodurre, e quando un'idea costa troppo.
- **File dello sviluppatore:** non si scartano né si sovrascrivono senza chiedere. Al 9 novembre `blender/personaggi/personaggio_n1.blend` risulta modificato fuori dai commit, non da Claude, ed è da chiarire con lo sviluppatore.

## 3. Tecnica

- **Motore:** Godot **4.7.2** standard (GDScript), fisica **Jolt**, interpolazione della fisica attiva. Eseguibile usato per i test: `C:\Dev\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`.
- **Cartella:** `C:\Dev\Project-Zombie` (fuori da OneDrive di proposito). Scena iniziale: `game/ui/main_menu.tscn`.
- **Struttura:**
  - **Codice e scene di gioco**, per funzionalità sotto `game/`:
    - `player`, `characters` (modello in terza persona), `weapons` (con `melee/` per le armi bianche);
    - `combat`, `enemies`, `waves`, `run`, `items`, `boosts`, `pickups`, `net`, `ui`;
    - `levels`, con `zones/` (zone e porte) e `props/` (elicottero, manichini).
  - **Risorse:** shader in `shared/shaders`; materiali greybox in `assets/materials`; modelli esportati in `assets/models/` (`weapons/`, `characters/`).
  - **Generatori delle mappe** in `tools/`: `build_campus.py` e `build_complex.py`.
  - **Sorgenti Blender** in `blender/`, ignorata da Godot con `.gdignore`.
  - **Schede** in `docs/` (`armi/`, `mappa/`, `personaggi/`).
- **Convenzioni:** 1 unità = 1 m; file `snake_case`, classi e nodi `PascalCase`; indentazione con tab; commenti di documentazione `##` in italiano sopra classi, export e funzioni pubbliche.
  - **Tipi espliciti** quando il valore viene da un Variant: le inferenze da Variant danno errore.
  - Dati di gioco come risorse `.tres` (armi, armi bianche, tratti, ondate, boost, oggetti) invece che numeri nel codice.
- **Layer di fisica:** 1 Mondo, 2 Giocatori, 3 Nemici (valore 4), 4 Detriti (valore 8), 5 Interagibili (valore 16).
- **Tasti:**

  | Tasto | Azione |
  |---|---|
  | WASD, Spazio, Shift | movimento, salto, corsa |
  | Click sinistro | spara, o colpisce con l'arma bianca |
  | R | ricarica |
  | F | pugno |
  | E | usa: casse, porte, armi a terra e al muro, proiettili, radio ed elicottero; tenuto premuto rianima |
  | V | ispeziona l'arma |
  | 1, 2, rotella | armi da fuoco |
  | 3 | arma bianca |
  | G | posa il proiettile da carro armato |
  | F3 | statistiche delle prestazioni |
  | Esc | libera il mouse |

### Modello di rete (importante)
- **Listen server:** un giocatore fa da host. **Ognuno muove il proprio giocatore** (risposta immediata); **l'host decide tutto il resto:** vita, danni, nemici, distruzione, casse, porte, oggetti, soldi, ondate, elicottero, armi bianche e proiettili in spalla.
- `NetSession` sceglie offline, host o join; il livello avvia la connessione. Da soli si usa `OfflineMultiplayerPeer`, quindi il codice dell'host vale anche in single player.
- **Replicatori** (`MultiplayerSpawner` personalizzati):
  - `PlayerSpawner`;
  - `EnemyReplicator`;
  - `PickupReplicator`: armi da fuoco e bianche a terra, oggetti passivi, proiettili da carro armato posati.
- **Chiamate host → tutti** su nodi che appartengono a un giocatore: `@rpc("any_peer")` più il controllo `multiplayer.get_remote_sender_id() == 1`.
- **Client → host:** richiesta `rpc_id(1, ...)` validata sull'host (distanza, vivo, limiti), per esempio `FpsController.interact_with`.
- **Chi entra a partita iniziata** riceve lo stato in due modi:
  - lo chiede all'host (`_request_*` da `_ready`);
  - oppure l'host glielo manda su `peer_connected`: casse, porte, zone aperte, muri rotti, ondate, run persa o vinta, elicottero, casse dei proiettili.
- `HealthComponent` e `RunInventory` hanno sempre autorità 1 (host), anche se il nodo padre è di un altro giocatore.
- **Chunk (dal passo 3.7):** nelle mappe a zone (`ZoneManager`) ogni zombie arriva in rete solo ai giocatori nella sua zona, in quelle accanto o entro 45 m.
  - Funziona con un filtro di visibilità del `MultiplayerSynchronizer` dello zombie, ricalcolato due volte al secondo partecipante per partecipante.
  - Le chiamate sui suoi nodi figli (la vita) passano da `Enemy.net_peers_seeing()`, perché Godot non le filtra da solo.

## 4. Cosa c'è (per passo)

**Fase 1, prototipo FPS**
- Controller FPS (`fps_controller.gd`): movimento, sprint, salto, visuale, rinculo.
- Armi hitscan e a proiettili dallo stesso sistema (`weapon.gd`, `weapon_data.gd`, `projectile.gd`, `explosion.gd`).
- `HealthComponent` unico per tutti, numeri di danno e hitmarker.
- Tre zombie:
  - **Camminatore:** base.
  - **Scattista:** veloce, si lancia in tuffo.
  - **Bestione:** carica in linea retta, corazzato davanti, punto debole dietro.
- **Pugno** (F) con la passiva *Mano pesante*: scaraventa gli zombie.
- **Strutture distruttibili a blocchi** da 0,25 m (`destructible_blocks.gd`). I detriti sono fisici e dopo 10 s diventano macerie permanenti (`rubble_field.gd`); la navigazione si ricalcola in background dopo ogni crollo.

**Fase 2, rete:** menu (da soli / ospita / entra via IP), giocatori, colpi, zombie e muri sincronizzati.

**Fase 3, core loop**
- **3.1 Armi trovabili:**
  - Armi base: pistola (di partenza), carabina, fucile a pompa, mitraglietta, lanciagranate.
  - **Rarità:** comune grigia, truccata azzurra, sbroccata arancione (armi uniche, senza tratti: per ora la Magnum).
  - **Tratti** che cambiano numeri e nome, e **trucchi** per le armi a colpo istantaneo: rimbalzante, perforante, esplosiva, incendiaria, doppia canna.
  - Ogni arma è descritta da uno "spec" (`["carbine","fast","pierce"]`) che si ricostruisce con `WeaponCatalog.build`; le armi bianche a terra sono `["melee", id]`.
  - **Casse** (E per aprire, 100 €, si richiudono dopo 60 s). Due armi da fuoco alla volta; con le mani piene lo scambio lascia l'arma ai piedi del giocatore.
- **3.2 Ondate** (`wave_director.gd`):
  - Budget che sale (6, 10, 14, 20, 26…, +60% per ogni giocatore in più), costo per tipo di zombie (`walker_wave.tres` ecc.), pesi variabili a ogni ondata.
  - Gli zombie escono da punti fuori vista e ad almeno 14 m, con un limite di vivi insieme e una pausa di 12 s tra un'ondata e l'altra.
- **3.3 A terra e rianimazione** (`fps_controller.gd`, `run_manager.gd`):
  - Finita la vita si resta a terra 30 s e si striscia.
  - Un compagno rianima tenendo premuto E per 3 s; ci si rialza con il 40% della vita.
  - A fine ondata chi è a terra si rialza e chi è morto rinasce accanto a un compagno.
  - Se nessuno è in piedi la run è persa: riepilogo e ripartenza da capo.
- **3.4 Soldi e macchinette** (`run_inventory.gd`, `vending_machine.gd`, `boosts/*.tres`):
  - **Taglie:** 10 / 15 / 60 €.
  - **Premi:** fine ondata 25 + 5 × ondata; 20 € a chi rianima.
  - **Macchinette:** Espresso (cadenza), Caffè doppio (ricarica), Merendina (vita); a volte si mangiano i soldi, a volte danno una dose doppia.
- **3.5 Oggetti passivi impilabili** (`items/*.tres`, `item_catalog.gd`):
  - Dieci oggetti, ognuno con una statistica e un aumento per copia; le copie si sommano.
  - Si trovano: uno a testa a fine ondata, e lasciati dagli zombie (Bestione sempre). Si perdono alla ripartenza.
  - **F3** mostra le statistiche delle prestazioni.
- **3.6 Il Complesso** (`game/levels/complex.tscn`, generato da `tools/build_complex.py`), sostituito dal campus al passo 3.7 e rimasto per i test:
  - mappa di circa 112 × 76 m in greybox a cielo aperto, con sette zone;
  - zombie con anti-incastro (scivolano di lato se non avanzano);
  - il vecchio livello resta come "Poligono di prova" (da soli, dal menu).
- **Prima arma sbroccata: la Magnum** (modello vero da Blender):
  - colpo che attraversa gli zombie con danno a scalare (200, 100, 50, poi 25);
  - 6 colpi fissi, niente tratti, non rompe i muri;
  - LED che contano i colpi; animazioni di sparo, ricarica e ispezione (tasto **V**);
  - rara nelle casse, sempre disponibile nella cassa gratuita del Poligono.

  Dettagli e difetti aperti in [`docs/armi/magnum.md`](docs/armi/magnum.md).

**Personaggio N.1 in gioco (3–6 novembre 2026, scheda in [`docs/personaggi/personaggio_n1.md`](docs/personaggi/personaggio_n1.md))**
- **Il modello:** rifatto da zero in Blender con le skill `blender-*`, in 11 fasi, ognuna uno script in `blender/personaggi/script/` (`fase0_preparazione.py` … `fase10_export.py`).
  - **Si rilancia in catena:** se cambia il corpo, si rilanciano in fila le fasi 2 → 10.
  - **Riferimenti:** le foto dello sviluppatore in `blender/personaggi/riferimenti/`, solo in locale ed escluse da git.
- **Come è fatto:**
  - corpo sfaccettato, maglia, cargo, scarponi, braccia robotiche e spallacci;
  - viso dalle foto dello sviluppatore (baffi, pizzetto e sopracciglia con spessore), ciuffo e mullet, anelli di pelliccia sul busto;
  - 14.974 triangoli, un materiale solo con una tavolozza in texture, scheletro da gioco di 71 ossa.
- **Le clip:** 9, fatte da script: Ferma, Cammina, Corsa, Indietro, Sinistra, Destra, Salto, ATerra, Rianima.
- **In Godot:**
  - `game/characters/personaggio_n1.tscn` sul nodo `Body` del giocatore, al posto della capsula;
  - `PlayerModel` (`player_model.gd`) sceglie la clip dal movimento e dallo stato del giocatore e ne scala la velocità, anche per i giocatori remoti;
  - per sé si vede solo l'ombra;
  - il colore del giocatore resta solo sul nome;
  - il pugno in prima persona è il braccio robotico (`assets/models/characters/personaggio_n1_pugno.glb`).
- **Difetti aperti:**
  - piedi che scivolano sui lati e all'indietro (in gioco si va a 7 m/s, le clip sono fatte per 1,1 e 2,1 m/s);
  - gli altri non vedono l'arma in mano;
  - il busto non segue la mira.

**Fase 3, dopo il personaggio (8 novembre 2026)**
- **3.7 Il campus di Monte Sant'Arcangelo** (`game/levels/campus.tscn`, generato da `tools/build_campus.py`, scheda in [`docs/mappa/campus.md`](docs/mappa/campus.md)):
  - **Dimensioni e zone:** circa 230 × 180 m in greybox, **11 zone**:
    - aula studio sotterranea;
    - Centri comuni;
    - viale con la passerella, diviso in ovest ed est;
    - mensa;
    - aulario con 8 aule;
    - biblioteca con soppalco;
    - torre dei dipartimenti, alta 12 m;
    - tetto;
    - parcheggio con la stazione;
    - laboratori segreti sotto il parcheggio.
  - **Partenza:** nell'aula studio sotterranea, con la lavagna bianca su tutta la parete sinistra guardando l'uscita; poi le scale per i Centri comuni.
  - **12 porte a pagamento** (`ZoneDoor`, da 250 a 1.500 €) aprono le zone (`ZoneManager`, `MapZone` in `game/levels/zones/`). Chiuse sono muri anche per la navigazione, che si ricalcola quando si aprono (circa 0,3 s per tutta la mappa). Alla ripartenza si richiudono.
  - **Le zone sono i chunk:**
    - gli zombie escono solo nelle zone aperte dove ci sono i giocatori o accanto;
    - uno zombie rimasto lontano da tutti per 6 s torna in coda e rinasce vicino;
    - in rete ognuno riceve solo gli zombie vicini (vedi §3).
  - **Altro:** 8 casse, 10 macchinette, 40 punti di comparsa, 4 muretti distruttibili; due materiali nuovi (`greybox_white`, `greybox_concrete`).
  - Il menu fa giocare nel campus.
- **3.8 Fine della run con l'elicottero** (`game/levels/props/helicopter.gd`, provvisoria):
  - **Raccolta:** sul tetto della torre, alla radio dell'esercito chiunque versa nella cassa comune, 500 € alla volta, fino a 5.000 €.
  - **Arrivo:** chiamato, si resiste 60 s; l'elicottero scende sull'eliporto e si sale con E. Solo chi è in piedi può salire (`FpsController.host_board`); a bordo si resta seduti e gli zombie lo ignorano. Dal primo che sale ci sono 20 s per gli altri; se salgono tutti quelli in piedi parte subito.
  - **Vittoria:** quando riparte, `RunManager.host_win` chiude la run con il riepilogo (salvati, ondata, uccisioni, tempo) e dopo 15 s si riparte da capo. L'HUD mostra a che punto è l'elicottero accanto all'ondata.
- **3.9 Armi bianche nel terzo slot** (`game/weapons/melee/`, `MeleeAttack`, `WallWeapon`), tasto 3 e poi click sinistro:

  | Arma | Prezzo | Dove si compra | Colpo |
  |---|---|---|---|
  | Martello da fabbro | 250 € | Centri comuni | 45 ogni 0,45 s, spinge, stacca pezzi di muro |
  | Katana | 600 € | biblioteca | 75 ogni 0,4 s, fino a 6 zombie insieme |
  | Martellone | 900 € | laboratori | 130 ogni 1,1 s, scaraventa (35 a chi colpisce in volo), sfonda i muri |

  - Le armi bianche escono anche dalle casse del campus, nel 12% dei casi (`WeaponCrate.melee_chance`).
  - Se ne tiene una: quella vecchia resta a terra. Si perdono alla ripartenza.
  - Il colpo lo calcola l'host come il pugno: le due cose condividono `MeleeAttack._strike` con un `MeleeWeaponData`.
  - I modelli in prima persona sono in greybox, con il colpo animato dall'alto (martelli) o di taglio (katana).
- **3.10 Proiettili da carro armato** (`game/pickups/shell_rack.gd`, `tank_shell_pickup.gd`):
  - **Dove:** 5 casse dell'esercito, 3 nei laboratori e 2 vicino ai camion del parcheggio. Il proiettile è gratis e ricompare dopo 90 s.
  - **In spalla** (`FpsController.carrying_shell`): mani occupate (il pugno sì), velocità all'85%, gli altri lo vedono sul modello. G lo posa a terra, dove resta 2 minuti. Chi va a terra o sale sull'elicottero lo lascia.
  - **La combo:** una martellata (martello o martellone) di un compagno a chi porta il proiettile lo fa partire a razzo dalla spalla, dove guarda chi lo porta (`MeleeAttack._hit_shell_carriers` → `FpsController.host_fire_shell`).
    - Il razzo (`game/weapons/tank_shell.tres`) fa 250 di danno diretto, più un'esplosione di 6 m da 350 che spinge e sfonda.
    - Chi lo portava riceve un contraccolpo all'indietro.
    - La katana non lo fa partire, e ai compagni non fa danni.
  - Da soli non si può usare.

## 5. Prossimi passi (da ROADMAP)

- **3.11** playtest della run completa, giocando: lo fa lo sviluppatore. Da regolare:
  - prezzi delle porte;
  - tempi per attraversare la mappa;
  - prezzo e tempi dell'elicottero;
  - forza di armi bianche e razzo (che si prova solo in due).
- **Da decidere con lo sviluppatore:** cosa succede tra le ondate, il ruolo della distruzione, altri modi di vincere.
- **2.5** prova con 4 istanze e con amici su internet; **2.6** Steam (lobby, inviti).
- **Fase 4** personaggi: 4 slot abilità più la passiva, e gli altri membri del gruppo.
- **Fase 5** grafica vera: modelli di mappa e zombie, soffitti, luci al neon.
- **Idee in attesa:**
  - un proiettile posato a terra che parte col martello, utile anche da soli;
  - le armi in mano viste dagli altri;
  - il busto che segue la mira.

## 6. Insidie già incontrate (non ripeterle)

**Prestazioni e risorse**
- **`load()` di una risorsa non tenuta in memoria la rilegge dal disco.** Gli effetti degli oggetti facevano così a ogni tick: 6 tipi di oggetti = 7 FPS. Le risorse usate spesso vanno tenute in una variabile o in una cache (`RunInventory.resource_for`, `ItemCatalog.all`, `WeaponCatalog.base`, `MeleeCatalog.data`).
- **Preload circolari** (catalogo → granata → proiettile → esplosione → arma → catalogo) rompono il caricamento: si usano percorsi e `load()` pigro.
- **Dizionari con nodi come chiave:** se il nodo viene liberato, il dizionario può bloccarsi all'infinito. Usare `get_instance_id()` come chiave. Lo stesso vale per le funzioni anonime nei test: una che tiene un nodo poi liberato dà "Lambda capture was freed".
- **`Performance.TIME_PHYSICS_PROCESS`** a FPS bassi somma più passi di fisica: non è il costo di un passo. Per capire dove va il tempo usare F3 (passi per frame, disegno della scheda video).
- **Effetti accumulati:** segni dei colpi limitati a 40, effetti piccoli senza ombre, cose a terra che spariscono dopo 2 minuti.

**Mappe e navigazione**
- **Zombie e spigoli:** la navigazione va tenuta abbastanza lontana dai muri (0,75 m) e c'è l'anti-incastro in `Enemy._unstick`. Una mappa nuova va provata con molte ondate di fila.
- **Gli oggetti davanti alle aperture chiudono la navigazione:** nel campus le lavagne delle aule sud stavano davanti alle porte e due aule erano irraggiungibili. Per questo `test_39` controlla che ogni punto di comparsa si raggiunga a porte aperte.
- **Mappe generate da script:** `tools/build_campus.py` e `tools/build_complex.py` riscrivono la scena da zero. Se lo sviluppatore la modifica a mano nell'editor, non rilanciare lo script senza riportare le modifiche.
- **Forme CSG sovrapposte sullo stesso piano** sfarfallano (z-fighting), e i muri che arrivano a filo di un pavimento lasciano delle righe: niente due solette con la faccia alla stessa quota.
- **La navigazione deve leggere la geometria sulla CPU:** per le porte si usa `add_mesh_array` con le facce calcolate (`BoxMesh.get_mesh_arrays()`), non `add_mesh`, che rilegge la scheda video.

**Rete**
- **`MultiplayerSynchronizer.is_visible_to` non esiste in GDScript**, e `update_visibility()` senza argomento chiama i filtri solo con il peer 0. Si chiama `update_visibility(peer)` per ogni partecipante, e il filtro si ricorda la risposta (`Enemy._seen_by`).
- **Le chiamate su nodi figli di un nodo con visibilità limitata vanno a tutti:** Godot filtra solo il nodo tracciato. Chi non ha il nodo riceverebbe errori, quindi la vita degli zombie passa da `HealthComponent._rpc_to_all` → `net_peers_seeing()`.
- **I nodi creati da codice e usati in rete devono avere un nome fisso:** radio e cabina dell'elicottero avevano nomi automatici diversi su host e client, e le richieste del client non trovavano il nodo.
- **Array tipizzati come parametri delle RPC** non si convertono bene: si riceve `Array` e si converte a mano.
- **Scambio d'armi:** non lasciare l'arma dove ne compare un'altra (era il bug "le casse danno solo lanciagranate").

**Godot in generale**
- **`find_children` trova solo i nodi "posseduti"** (che vengono da una scena). Per i nodi creati da codice serve `owned = false`, altrimenti, per esempio, il proiettile in spalla non diventava "solo ombra" per il giocatore locale.
- **Le foto vanno fatte con l'ambiente del livello:** senza un cielo da riflettere i metalli escono quasi neri.

**Blender**
- **Export glTF con `NLA_TRACKS`:** dopo l'esportazione gli oggetti animati possono restare spostati nel file Blender (`location` e `scale` cambiate). Se si salva o si riesporta senza ripristinarli, l'errore finisce anche nel `.blend` e nel `.glb` successivo (era il bug "il tamburo non entra nell'arma").
  - Dopo ogni export vanno ripristinate le posizioni e ricontrollate prima di salvare.
  - Le strisce NLA vanno portate tutte al fotogramma 1 prima dell'export e rimesse a posto dopo, altrimenti le clip conservano il ritardo della sequenza.
- **Personaggio:**
  - le clip devono mettere le chiavi su tutte le ossa usate da almeno una clip, altrimenti ereditano la posa della clip di prima;
  - lo scheletro da gioco ha vincoli verso il rig di controllo, da spegnere all'export;
  - gli altri dettagli sono nella scheda del personaggio.

## 7. Test

- I test sono in [`tests/`](tests/) (ignorata da Godot con `.gdignore`): script `extends SceneTree` lanciati senza grafica. Quelli di rete avviano due istanze (host e client) sulla stessa macchina, `net_zombies` tre.
- **Come lanciarli** (Git Bash, dalla cartella del progetto):
  - `bash tests/run_tests.sh` per tutto: 20 test da soli e 14 in rete, 48 risultati, circa 12 minuti;
  - per alcuni soltanto: `TESTS="test_41" NET="" bash tests/run_tests.sh`.
  - Ogni test stampa `RISULTATO: N errori` e una riga `FAIL` per ogni controllo fallito; i log vanno in `tests/logs/` (non versionata). Dettagli in testa a `tests/run_tests.sh`.
- **Cosa coprono:**
  - armi: catalogo e tratti, casse e scambio, pallini, perforazione, rimbalzi, esplosioni e fuoco;
  - ondate e punti di comparsa;
  - a terra, rianimazione e run persa;
  - soldi, macchinette e boost;
  - oggetti e loro effetti;
  - collegamenti del Complesso;
  - Magnum (`test_37`, `net_magnum`);
  - Personaggio N.1 in gioco: clip, direzione, solo ombra, pugno (`test_38`; le clip anche in `net_combat` e `net_revive`);
  - campus: zone, porte, navigazione, comparsa vicino ai giocatori, zombie rimessi in coda, chunk in rete (`test_39`, `net_campus`);
  - elicottero: raccolta, arrivo, imbarco, vittoria (`test_40`, `net_helicopter`);
  - armi bianche: acquisto, terzo slot, colpi, casse (`test_41`, `net_melee`);
  - proiettili da carro armato: casse, in spalla, posa, razzo a martellate (`test_42`, `net_shell`);
  - versioni in rete di quasi tutto.

  A ogni passo si rilancia tutto e si aggiunge un `test_xx` (e se serve un `net_*`) per il passo nuovo. Da soli il secondo giocatore non c'è: per la martellata `test_42` usa un attaccante finto, e la prova vera è in `net_shell`.
- **Script lunghi da lanciare a mano:**
  - `waves_complex.gd`: 10 ondate nel Complesso, segnala zombie incastrati;
  - `bench_items_win.gd`: FPS in finestra con molti oggetti, senza `--headless`.
- **Scie e pacchetti non garantiti:** le scie degli spari altrui viaggiano come RPC `unreliable`, e ENet può scartarne qualcuna, soprattutto appena connessi e con il PC sotto carico. È accettabile, perché è solo visivo, ma un test non deve contare su una singola scia: `net_combat` fa sparare tre colpi in più e chiede di vederne almeno uno.
- **`test_32` è fallito una volta** nella batteria completa (scritta "Ondata 2 tra 12" dell'HUD dopo l'ondata superata); rilanciato da solo è passato due volte. Probabilmente dipende dai tempi, ma non è dimostrato.

## 8. Direzione artistica e modelli

- **Pipeline:** disegni o foto dello sviluppatore → modelli low-poly in Blender → glTF (`.glb`) in `assets/models/` → Godot. **Blender 5.2.3 LTS è installato** (versione Steam) con l'add-on MCP ufficiale di Blender Lab.
- **Come lavora Claude in Blender:**
  - **Senza finestra (il modo preferito):** `.claude/skills/blender-core/scripts/run_in_blender.py --blend FILE script.py`, che trova da solo il Blender di Steam.
  - **Dal vivo:** l'MCP, con Blender aperto e il server avviato (Preferences > Add-ons > MCP, Auto Start attivo, porta 9876). Le schermate della vista 3D possono essere vecchie se la finestra è in secondo piano. Prima di ricaricare un file aperto con modifiche non salvate si chiede allo sviluppatore.
- **Skill `blender-*`** in `.claude/skills/` (dal 3 novembre 2026): procedure e script per scultura, retopologia, scheletro, vestiti, capelli, materiali, ottimizzazione, controllo qualità, animazione ed export. Origine e correzioni locali sono in `.claude/skills/BLENDER_SKILLS_ORIGINE.md`.
- **Valutazione, aggiornata:**
  - **Bene:** moduli della mappa e oggetti di scena; con le skill anche un personaggio intero, a fasi controllate e con il via dello sviluppatore a ogni fase.
  - **Discreto:** armi, meglio con un disegno di lato.
  - **Sufficiente:** zombie a pezzi rigidi, con animazioni fatte nel codice.
  - **Il punto debole restano i volti e le animazioni curate:** il viso del Personaggio N.1 è stilizzato a rilievi e zone di colore, e le clip sono fatte da script.
- **Modelli veri fatti:** la Magnum e il Personaggio N.1. Restano da fare gli zombie, i pezzi della mappa e le armi di base.
- **Mappa grande e distruzione:**
  - il campus è grande e diviso in chunk per rete e ondate, ma la navigazione è ancora una sola per tutta la mappa: costa circa 0,3 s e si ricalcola tutta in background;
  - se servisse: navigazione a tasselli, materiali con blocchi diversi, caricamento a settori.
  - Le idee di gioco emerse: muri di cartongesso da sfondare, pilastri portanti che fanno crollare il soffitto, pavimenti che cedono, zombie che sfondano le pareti, obiettivi da demolire.

### Magnum (primo modello vero) e schede delle armi

- **Ogni arma con il modello vero ha una scheda** in [`docs/armi/`](docs/armi/LEGGIMI.md): danni e peculiarità, sezione Blender (tempi delle animazioni, difetti, vincoli) e sezione Godot (scena, collegamento delle animazioni, difetti, verifiche). Quando si trova un difetto lo si aggiunge lì; quando lo si corregge lo si sposta in "Corretti" con la data.
- **Magnum:** scheda completa in [`docs/armi/magnum.md`](docs/armi/magnum.md), che vale più di questo riassunto se i numeri non coincidono.
  - **Modello:** `assets/models/weapons/magnum.glb` (sorgente `blender/weapons/magnum.blend`), con animazioni `Riposo`, `Sparo`, `Ricarica`, `Ispezione`, `Estrazione`.
  - **Colpo:** attraversa gli zombie con danno 200, 100, 50, minimo 25; 6 colpi fissi; niente tratti; non rompe i muri.
  - **LED:** sul tamburo (uno per colpo) e in cima al fusto, con lo shader `led_mask.gdshader`.
  - **Animazioni:** collegate dall'interfaccia generica dei modelli animati in `Weapon` (`on_equip`, `on_fire`, `on_reload`, `on_inspect`).
  - **Dal 2 novembre:** tamburo con i fori veri, sparo più pesante con il bossolo espulso a destra, tremolio della visuale (`camera_shake_degrees`), scala dell'arma a terra (`pickup_scale`).
  - **Copia del modello precedente:** `blender/weapons/magnum_prima_dei_fori.blend`.
