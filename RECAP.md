# Recap per chi riprende il progetto

Questo file riassume cosa è stato fatto finora, come è fatto il gioco e come si lavora. Serve a far partire in fretta una nuova sessione (persona o istanza di Claude). Le fonti di verità restano [DESIGN.md](DESIGN.md) (idee e decisioni di gioco) e [ROADMAP.md](ROADMAP.md) (passi fatti e da fare); in caso di dubbio vincono loro.

Aggiornato al commit `4166f5d` (Passo 3.6).

---

## 1. Il gioco in breve

- **Cos'è:** FPS roguelike in prima persona, co-op online da 1 a 4 giocatori, contro orde di zombie colorati e per niente cupi. **Le armi sono le protagoniste.**
- **Stile visivo:** low-poly alla *Deep Rock Galactic*: forme grosse e leggibili, flat shading, luci colorate, colori forti solo su ciò che conta (nemici, armi, oggetti). Oggi è tutto in greybox (cubi e capsule).
- **Identità:** nasce dal gruppo universitario dello sviluppatore (persone, aule studio, coffee break, meme). **Nel gioco non ci sono riferimenti espliciti all'università:** le battute sono il "DNA" nascosto di armi, nemici, nomi. La lobby futura sarà un'aula studio; le macchinette del caffè danno i boost.
- **Mondo:** "il Complesso", stanze gialle alte e corridoi tipo backrooms, ma con tono caciarone, non inquietante.
- **Pilastri:** 1) le armi prima di tutto (comuni → truccate → sbroccate), 2) zombie mai visti, ognuno con un comportamento riconoscibile, 3) caos co-op leggero.
- **Struttura della run (attuale):** una sola mappa grande, ondate con budget di pericolosità crescente, soldi personali, oggetti passivi impilabili, giocatori a terra rianimabili, run persa se cadono tutti.
- **Ancora da decidere (lo sviluppatore vuole prima definire meglio il gameplay):** come si vince la run (ondate fisse, boss, resistenza), cosa succede tra le ondate, natura degli zombie, armi sbroccate (attendono i meme del gruppo). Idea in esplorazione: **mappa immensa con strutture pensate per la distruttibilità** (vedi §8).

## 2. Come si lavora

- **Lingua:** tutto in italiano: risposte, commenti nel codice, messaggi di commit, documenti, testi del gioco.
- **Lo sviluppatore:** lavora quasi da solo, 5–15 ore a settimana. Prova ogni passo con **F5** nell'editor e decide cosa è divertente. Disegna i riferimenti.
- **Claude:** scrive codice e scene, li verifica con **test automatici** (headless e in rete con più istanze) e **screenshot** in finestra, poi spiega cosa provare.
- **Commit e push solo dopo l'approvazione esplicita** dello sviluppatore (di solito "Sì, commit"), mai prima. Messaggio nel formato `Passo X.Y: titolo` + elenco puntato in italiano, con la riga `Co-Authored-By` richiesta dall'ambiente. Si lavora su `main`, remoto GitHub `AntoSeguino2018/Project-Zombie`.
- **Un passo alla volta:** si propone il passo, lo sviluppatore approva, si implementa, si testa, si mostra, si committa. Le idee nuove vanno nella sezione "Idee raccolte" della roadmap.
- **Essere onesti:** dire cosa non si è verificato, cosa non si riesce a riprodurre, e quando un'idea costa troppo.

## 3. Tecnica

- **Motore:** Godot **4.7.2** standard (GDScript), fisica **Jolt**, interpolazione della fisica attiva. Eseguibile usato per i test: `C:\Dev\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`.
- **Cartella:** `C:\Dev\Project-Zombie` (fuori da OneDrive di proposito). Scena iniziale: `game/ui/main_menu.tscn`.
- **Struttura:** per funzionalità sotto `game/` (`player`, `weapons`, `combat`, `enemies`, `waves`, `run`, `items`, `boosts`, `pickups`, `levels`, `net`, `ui`); shader in `shared/shaders`; materiali greybox in `assets/materials`; generatore della mappa in `tools/`.
- **Convenzioni:** 1 unità = 1 m; file `snake_case`, classi e nodi `PascalCase`; indentazione con tab; commenti di documentazione `##` in italiano sopra classi, export e funzioni pubbliche. **Tipi espliciti** quando il valore viene da un Variant (le inferenze da Variant danno errore). Dati di gioco come risorse `.tres` (armi, tratti, ondate, boost, oggetti) invece che numeri nel codice.
- **Layer di fisica:** 1 Mondo, 2 Giocatori, 3 Nemici (valore 4), 4 Detriti (valore 8), 5 Interagibili (valore 16).

### Modello di rete (importante)
- **Listen server:** un giocatore fa da host. **Ognuno muove il proprio giocatore** (risposta immediata); **l'host decide tutto il resto:** vita, danni, nemici, distruzione, casse, oggetti, soldi, ondate.
- `NetSession` sceglie offline/host/join; il livello avvia la connessione. Da soli si usa `OfflineMultiplayerPeer`, quindi il codice dell'host vale anche in single player.
- **Replicatori** (`MultiplayerSpawner` personalizzati): `PlayerSpawner`, `EnemyReplicator`, `PickupReplicator` (armi e oggetti a terra).
- **Chiamate host → tutti** su nodi che appartengono a un giocatore: `@rpc("any_peer")` più il controllo `multiplayer.get_remote_sender_id() == 1`. **Client → host:** richiesta `rpc_id(1, ...)` validata sull'host (distanza, vivo, limiti).
- **Chi entra a partita iniziata** chiede lo stato all'host (`_request_*` da `_ready`), oppure l'host lo manda su `peer_connected` (casse, muri rotti, ondate, run persa).
- `HealthComponent` e `RunInventory` hanno sempre autorità 1 (host), anche se il nodo padre è di un altro giocatore.

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
- **Strutture distruttibili a blocchi** da 0,25 m (`destructible_blocks.gd`), detriti fisici che dopo 10 s diventano macerie permanenti (`rubble_field.gd`); la navigazione si ricalcola in background dopo ogni crollo.

**Fase 2, rete:** menu (da soli / ospita / entra via IP), giocatori, colpi, zombie e muri sincronizzati.

**Fase 3, core loop**
- **3.1 Armi trovabili:**
  - Armi base: pistola (di partenza), carabina, fucile a pompa, mitraglietta, lanciagranate.
  - **Rarità:** comune grigia, truccata azzurra, sbroccata arancione (le sbroccate devono ancora arrivare).
  - **Tratti** che cambiano numeri e nome, e **trucchi** per le armi a colpo istantaneo: rimbalzante, perforante, esplosiva, incendiaria, doppia canna.
  - Ogni arma è descritta da uno "spec" (`["carbine","fast","pierce"]`) che si ricostruisce con `WeaponCatalog.build`.
  - **Casse** (E per aprire, 100 €, si richiudono dopo 60 s). Due armi alla volta; con le mani piene lo scambio lascia l'arma ai piedi del giocatore.
- **3.2 Ondate** (`wave_director.gd`):
  - Budget che sale (6, 10, 14, 20, 26… +60% per ogni giocatore in più), costo per tipo di zombie (`walker_wave.tres` ecc.), pesi variabili a ogni ondata.
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
- **3.6 Il Complesso** (`game/levels/complex.tscn`, generato da `tools/build_complex.py`):
  - Mappa di circa 112 × 76 m in greybox a cielo aperto, con sette zone: Atrio (partenza), Aula studio, Cortile, Corridoio, Archivio, Sala alta con soppalco, Magazzino con piattaforma.
  - 6 casse, 7 macchinette, 15 punti di comparsa.
  - Zombie con anti-incastro (scivolano di lato se non avanzano).
  - Il vecchio livello resta come "Poligono di prova".

## 5. Prossimi passi (da ROADMAP)

- **Prima di tutto:** definire meglio il gameplay con lo sviluppatore (come si vince, cosa succede tra le ondate, ruolo della distruzione, mappa immensa sì/no). Proposta: una sessione di design a domande, con alternative, e decisioni scritte in DESIGN.md prima di altro codice.
- **3.7** fine della run e schermata con le statistiche; **3.8** playtest della run completa.
- **2.5** prova con 4 istanze e con amici su internet; **2.6** Steam (lobby, inviti).
- **Fase 4** personaggi (4 slot abilità più passiva). **Fase 5** grafica vera.

## 6. Insidie già incontrate (non ripeterle)

- **`load()` di una risorsa non tenuta in memoria la rilegge dal disco.** Gli effetti degli oggetti facevano così a ogni tick: 6 tipi di oggetti = 7 FPS. Le risorse usate spesso vanno tenute in una variabile o in una cache (`RunInventory.resource_for`, `ItemCatalog.all`, `WeaponCatalog.base`).
- **Preload circolari** (catalogo → granata → proiettile → esplosione → arma → catalogo) rompono il caricamento: si usano percorsi e `load()` pigro.
- **Dizionari con nodi come chiave:** se il nodo viene liberato, il dizionario può bloccarsi all'infinito. Usare `get_instance_id()` come chiave.
- **`Performance.TIME_PHYSICS_PROCESS`** a FPS bassi somma più passi di fisica: non è il costo di un passo. Per capire dove va il tempo usare F3 (passi per frame, disegno della scheda video).
- **Zombie e spigoli:** la navigazione va tenuta abbastanza lontana dai muri (0,75 m nel Complesso) e c'è l'anti-incastro in `Enemy._unstick`. Una mappa nuova va provata con molte ondate di fila.
- **Effetti accumulati:** segni dei colpi limitati a 40, effetti piccoli senza ombre, cose a terra che spariscono dopo 2 minuti.
- **`tools/build_complex.py` riscrive `complex.tscn` da zero:** se lo sviluppatore modifica la mappa a mano nell'editor, non rilanciare lo script senza riportare le modifiche.
- **Scambio d'armi:** non lasciare l'arma dove ne compare un'altra (era il bug "le casse danno solo lanciagranate").

## 7. Test

- I test sono in [`tests/`](tests/) (ignorata da Godot con `.gdignore`): script `extends SceneTree` lanciati senza grafica; quelli di rete avviano due istanze (host e client) sulla stessa macchina, `net_zombies` tre.
- **Come lanciarli** (Git Bash, dalla cartella del progetto): `bash tests/run_tests.sh` per tutto, circa 10 minuti; per alcuni soltanto, `TESTS="test_31" NET="" bash tests/run_tests.sh`. Ogni test stampa `RISULTATO: N errori` e una riga `FAIL` per ogni controllo fallito; i log vanno in `tests/logs/` (non versionata). Dettagli in testa a `tests/run_tests.sh`.
- **Cosa coprono:**
  - armi: catalogo e tratti, casse e scambio, pallini, perforazione, rimbalzi, esplosioni e fuoco;
  - ondate e punti di comparsa;
  - a terra, rianimazione e run persa;
  - soldi, macchinette e boost;
  - oggetti e loro effetti;
  - collegamenti del Complesso (ogni zona, cassa e punto di comparsa raggiungibile);
  - versioni in rete di quasi tutto.

  A ogni passo si rilancia tutto e si aggiunge un `test_3x` (e se serve un `net_*`) per il passo nuovo.
- **Script lunghi da lanciare a mano:** `waves_complex.gd` (10 ondate nel Complesso, segnala zombie incastrati) e `bench_items_win.gd` (FPS in finestra con molti oggetti, senza `--headless`).
- **Fallimento saltuario noto:** in `net_combat` ogni tanto fallisce "l'host vede la scia del colpo del client". Le scie degli spari altrui viaggiano come RPC non garantite (`unreliable_ordered`, per non rallentare la rete) e a volte la prima si perde. Rilanciato passa; è un effetto solo visivo.

## 8. Direzione artistica e modelli (stato della discussione)

- Pipeline prevista: disegni dello sviluppatore → modelli low-poly in Blender → glTF (`.glb`) in `assets/models/` → Godot. **Blender non è ancora installato** sul PC.
- Claude può creare modelli scrivendo script Python per Blender (`bpy`) eseguiti senza interfaccia, esportarli e fotografarli per controllarli; non serve l'MCP.
- **Valutazione onesta:**
  - **Bene:** moduli della mappa e oggetti di scena.
  - **Discreto:** armi, meglio con un disegno di lato.
  - **Sufficiente:** zombie a pezzi rigidi, con animazioni fatte nel codice.
  - **Scarso:** personaggi organici, scheletri e animazioni curate.
- Per i personaggi le alternative realistiche sono kit CC0 (Quaternius, Kenney) personalizzati, Mixamo per le animazioni, un artista su commissione, oppure lo sviluppatore che impara le basi di Blender.
- Proposto e non ancora fatto: un "modello di prova" (un'arma, uno zombie, un pezzo di muro) per vedere il livello reale.
- **Mappa immensa e distruzione:** fattibile solo con altre basi:
  - navigazione a tasselli, che si ricalcola solo dove c'è un crollo;
  - materiali con blocchi di dimensioni diverse, distruttibili solo dove serve;
  - caricamento a settori.

  Le idee di gioco emerse: muri di cartongesso da sfondare, pilastri portanti che fanno crollare il soffitto, pavimenti che cedono, zombie che sfondano le pareti, obiettivi da demolire, settori che si aprono, mappa composta da moduli prefabbricati diversi a ogni run.
