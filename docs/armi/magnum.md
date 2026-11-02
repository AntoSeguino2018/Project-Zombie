# Magnum — scheda dell'arma

Prima arma **sbroccata**: revolver tech "da ingegneria informatica". Questa scheda raccoglie dati, peculiarità e soprattutto i **difetti da correggere**, divisi tra Blender (modello e animazioni) e Godot (codice e scene). Quando un difetto viene corretto si sposta in "Corretti" con la data; quando se ne trova uno nuovo si aggiunge qui.

Aggiornata al 2 novembre 2026.

---

## 1. Danni e peculiarità

### In breve
- **Rarità:** sbroccata (nome e luce arancioni). `catalog_id` = `magnum`, nome mostrato "Magnum".
- **Colpo che attraversa:** passa attraverso tutti gli zombie in linea. Il danno è **200 al primo**, poi **si dimezza a ogni zombie attraversato** fino a un **minimo di 25**: 200, 100, 50, 25, 25, 25…
- **Sei colpi e basta:** caricatore fisso, mai tratti (nemmeno forzandoli nello spec) e nessun effetto del Caricatore XL.
- **Non rompe i muri distruttibili**, e i muri (anche quelli distruttibili) fermano il colpo.

### Numeri (`game/weapons/magnum.tres`)

| Parametro | Valore |
|---|---|
| Danno | 200 al primo bersaglio, poi × 0,5 a ogni bersaglio, minimo 25 |
| Attraversamento | illimitato (`pierce = 99`, `pierce_falloff = 0.5`, `pierce_min_damage = 25`) |
| Cadenza | 1,5 colpi al secondo, semiautomatica |
| Caricatore | 6, fisso (`fixed_magazine = true`) |
| Ricarica | 3,0 s (ricarica tutti e sei i colpi insieme) |
| Dispersione | 0,2° |
| Gittata | 200 m |
| Rinculo della visuale | 8,5° in alto, fino a 2,5° di lato, recupero 7 |
| Tremolio della visuale | 1,2° a ogni colpo, si spegne in circa 0,3 s (solo visivo) |
| A terra | modello ridotto a metà (`pickup_scale = 0.5`), lungo circa 40 cm |

### Come si comporta in gioco
- **Ordine dei danni:** lo decide sempre l'host, ordinando i bersagli colpiti per distanza da chi spara. Così un client non può mandare l'ordine che gli conviene. Su ogni bersaglio compare un solo numero di danno.
- **Cosa attraversa:** solo ciò che ha una vita (zombie, manichini). I corpi degli zombie appena morti non bloccano più il colpo. Il colpo attraversa anche i compagni senza far loro danno (niente fuoco amico).
- **Con gli oggetti passivi:**
  - **Proiettili al peperoncino:** moltiplica tutti i danni dopo il calcolo a scalare (con +10%: 220, 110, 55, 27,5…).
  - **Grilletto unto ed Espresso:** alzano la cadenza; l'animazione di sparo accelera di conseguenza.
  - **Dita da pianista e Caffè doppio:** accorciano la ricarica; l'animazione si adatta.
  - **Caricatore XL:** nessun effetto.
- **Contro gli zombie:**
  - Il primo colpo uccide un Camminatore (60) o uno Scattista (30) e continua con 100 sul successivo.
  - Il Bestione (400) è corazzato davanti: la corazza riduce anche questo colpo; dietro c'è il punto debole.
  - La corazza agisce dopo il calcolo a scalare, bersaglio per bersaglio.
- **Dove si trova:**
  - Nelle casse è rara: peso 0,5 contro i 10 delle armi comuni, circa il 5% delle aperture. Esce sempre senza tratti.
  - Nel **Poligono di prova** c'è una cassa gratuita ("Cassa Magnum (prova)") che dà sempre la Magnum e si richiude dopo 5 s.
- **Ispezione:** tasto **V** (solo a riposo; sparare la interrompe).

### LED (peculiarità visiva)
- **Tamburo:** un LED per camera, cioè l'anello davanti alla camera e la striscia esterna che la segue nell'ordine di sparo.
  - È acceso finché la camera ha il colpo.
  - Lo sparo spegne la camera in alto e il tamburo gira di 60°.
  - Dal lato che si vede in prima persona le strisce si spengono una alla volta.
- **Striscia in cima al fusto:** 6 LED che contano i colpi rimasti; si spengono da davanti. Con l'ultimo colpo lampeggia.
- **Presa in mano:** i LED si accendono uno dopo l'altro (0,45 s).
- **Ricarica:** spenti quando escono i bossoli, poi si riaccendono uno alla volta mentre entrano le cartucce.
- **Ispezione:** "diagnostica": un LED che gira sul tamburo, uno che va e viene in cima.

---

## 2. Blender (modello e animazioni)

**File:** `blender/weapons/magnum.blend` (sorgente, collezione `Magnum`), esportato in `assets/models/weapons/magnum.glb`. Lunghezza circa 42,5 cm (scala volutamente esagerata), origine sull'impugnatura, canna verso -Z. 6.024 triangoli contando cartucce, bossoli, caricatore e lampo. Animazioni a 30 fps: `Riposo` 2,03 s, `Estrazione` 0,43 s, `Sparo` 0,83 s, `Ricarica` 3,77 s, `Ispezione` 3,23 s.

### Modello
- **Design approvato dallo sviluppatore:** revolver massiccio alla Deep Rock Galactic, argento con impugnatura nera, tema informatico spinto e luci azzurre. Contiene:
  - chip e piste da circuito stampato sull'impugnatura;
  - tamburo ispirato a un disco, con sei fori passanti e le cartucce visibili dentro;
  - alette da dissipatore sulla canna;
  - una ventola sul lato sinistro;
  - sei LED in cima al fusto;
  - la "Z" in binario (`01011010`) sul lato destro.

  Niente texture, solo materiali: `M_Argento`, `M_Interno`, `M_Acciaio_Scuro`, `M_Azzurro_Luce` (luci, emissione 2,2), `M_Nero_Impugnatura`, `M_Ottone`, `M_Lampo`.
- **Nodi:**
  - radice `Magnum`, poi `Fusto`, `Impugnatura`, `Cane`, `Grilletto`, `Ventola`, `Lampo`, `Espulso` (il bossolo che salta via a ogni sparo) e `Gru` (perno del tamburo, con `Braccio` e `Tamburo`);
  - sotto `Tamburo`: `Bossolo0`…`Bossolo5` (camera 0 in alto, poi in senso orario guardando dalla canna, cioè l'ordine di sparo), `Cartucce` e `Caricatore`;
  - la radice `Magnum` è animata in tutte le clip: il movimento dell'arma (rinculo, oscillazione, giri dell'ispezione) è nelle animazioni.
- **Stato a riposo:**
  - `Lampo`, `Espulso`, `Cartucce` e `Caricatore` sono a scala 0,001 (non 0, per non dare errori in Godot);
  - i nodi `Bossolo0`…`Bossolo5` sono le cartucce nelle camere, con la punta azzurra, visibili dai fori;
  - il tamburo finisce sempre su un multiplo di 60°, quindi tornare a zero non si nota.
- **Verifiche fatte in Blender:** nessuna collisione tra `Tamburo` e `Fusto`, né tra `Cartucce` e `Fusto`, su tutta la sequenza. `Perno` (in `Braccio`) e `Ventola` sono incassati di proposito.

### Tempi chiave (usati dal codice: se cambiano, aggiornare Godot)

| Animazione | Cosa succede | Quando |
|---|---|---|
| Estrazione | l'arma sale, il tamburo gira di un giro, il cane si arma | 0,03 → 0,43 s |
| Sparo | cane, lampo e rinculo partono subito | da 0,03 s (picco a 0,17 s) |
| Sparo | il tamburo gira di 60° | 0,03 → 0,10 s |
| Sparo | il bossolo salta via, verso destra, in alto e un po' in avanti | 0,13 → 0,63 s |
| Ricarica | il braccio (`Gru`) apre il tamburo | 0,40 → 0,73 s |
| Ricarica | i bossoli escono e spariscono | 0,83 → 1,20 s |
| Ricarica | il caricatore con le cartucce compare | 1,57 s |
| Ricarica | il caricatore entra nel tamburo | fino a 2,27 s |
| Ricarica | il caricatore se ne va di lato e in basso | 2,37 → 2,77 s |
| Ricarica | il tamburo gira | 2,47 → 3,20 s (finisce a -60°) |
| Ricarica | il braccio richiude | 2,80 → 3,20 s |
| Ispezione | il tamburo gira | da 1,87 s |

### Difetti da correggere
1. **Ricarica senza mani:** il caricatore ora entra ed esce di lato e in basso, lontano dalla camera, ma in Blender compare ancora da fermo fuori dall'inquadratura. Da verificare in prima persona; con le mani andrà rifatto.
2. **Bossoli:** cadono con un'animazione, non con la fisica. Vale anche per il bossolo espulso a ogni sparo.
3. **`Riposo` non è marcata come ciclo** (il glTF non lo prevede): il ciclo lo imposta il codice. Va bene così, è solo da sapere.
4. **Vincoli per i LED:** lo shader riconosce i LED dalla loro posizione nella mesh. Se si modificano `Tamburo` o la striscia in cima a `Fusto`, vanno mantenute queste misure o aggiornato `led_mask.gdshader`:
   - **tamburo:** camere ogni 60° partendo dall'alto (90°) in senso orario guardando dalla canna; anelli delle camere a raggio < 0,034 m; strisce esterne a raggio > 0,034 m a metà tra due camere; disco centrale a raggio < 0,008 m;
   - **striscia del fusto:** y > 0,088, |x| < 0,008, z da -0,045 (davanti) a 0,0325 (dietro), passo 0,0155;
   - **materiale:** le luci devono restare su `M_Azzurro_Luce` (superficie 2 del tamburo, 3 del fusto).
5. **Insidie dell'export** (vedi RECAP §6): con `NLA_TRACKS` gli oggetti animati possono restare spostati nel `.blend` dopo l'export: portare le strisce NLA al fotogramma 1, esportare, rimetterle a posto e ripristinare le posizioni di riposo prima di salvare. Serve anche `export_optimize_animation_keep_anim_object=True` con `export_optimize_animation_size=False`, altrimenti le tracce costanti di `Riposo` spariscono e non rimette a posto cartucce e bossoli.

### Corretti
- (2 novembre 2026) Nel `.blend` (non nel gioco) Ventola, Tamburo, Gru, Cane e Lampo erano spostati: la loro posizione non è animata da nessuna clip, quindi resta quella salvata, e dopo l'export del bossolo era rimasta sbagliata. Rimessa uguale al `.glb`; anche la rotazione di `Cartucce` riportata a 0.
- (2 novembre 2026) Tamburo che non entrava nell'arma dopo un export (vedi insidia NLA).
- (2 novembre 2026) Tamburo con fori passanti veri e cartucce visibili.
- (2 novembre 2026) Sparo rifatto: colpo immediato, rinculo più forte, cane che scatta e bossolo che salta via.
- (2 novembre 2026) Scala 0 sostituita da 0,001: l'importazione in Godot non dà più errori.
- (2 novembre 2026) Lampo più grande.
- (2 novembre 2026) Caricatore che passava vicino alla camera: ora arriva e se ne va di lato e in basso.
- (2 novembre 2026) Bossoli: la ricarica fa uscire solo le cartucce rimaste, perché i fori sparati sono già vuoti.
- (2 novembre 2026) `Riposo` rimette a posto cartucce, bossoli, caricatore e lampo.
- (2 novembre 2026) Aggiunta la clip `Estrazione`.
- (2 novembre 2026) Bossolo espulso che volava verso la faccia del giocatore.
  - **Prima:** in `Sparo` usciva a sinistra e arrivava 16 cm all'indietro, in (-0,42, 0,02, 0,16) nelle coordinate del modello; in prima persona finiva a circa 20 cm dall'occhio e sembrava una sbarra enorme.
  - **Ora:** traiettoria specchiata attorno al centro dell'arma: parte da +0,018, esce dalla finestra destra del tamburo, sale e ricade a destra arrivando a (0,42, 0,02, -0,086), cioè leggermente in avanti. Anche la rotazione è specchiata; tempi, altezze e scala (1,15) sono invariati.
  - **Come:** modificati i fotogrammi chiave dell'azione `Sparo_Espulso` (in Blender la x è la stessa, la y di Blender è la -z di Godot), poi esportato con la procedura del §4.
  - **Verifica:** confrontando il `.glb` nuovo con il precedente, cambiano solo le tracce di `Espulso`; durate delle clip, tutte le altre tracce e le posizioni dei nodi sono identiche.

---

## 3. Godot (codice e scene)

### File
- `game/weapons/magnum.tres`: dati.
- `game/weapons/viewmodels/magnum_viewmodel.tscn`: modello in prima persona.
  - Il glb è scalato a 0,8, ruotato di 7° verso il centro, spostato di (-0,04, 0,02, 0,03).
  - `Muzzle` sta in (-0,069, 0,062, -0,208), 1,3 cm davanti al `Lampo`.
- `game/weapons/viewmodels/magnum_viewmodel.gd`: animazioni e LED.
- `game/weapons/viewmodels/led_mask.gdshader`: LED accesi uno per uno.
- In comune con le altre armi:
  - `weapon.gd`: interfaccia per i modelli animati (`on_equip`, `on_fire`, `on_reload(durata)`, `on_inspect`, `has_own_animations`) e danno a scalare in `_host_shot_damage`;
  - `weapon_data.gd`: `fixed_magazine`, `pierce_falloff`, `pierce_min_damage`;
  - `weapon_catalog.gd`: sbroccate senza tratti;
  - `weapon_crate.gd`: `forced_spec` per la cassa del poligono.
- Test: `tests/test_37.gd` (da soli), `tests/net_magnum.gd` (in rete).

### Come sono collegate le animazioni
- **Presa in mano:** `on_equip` fa partire `Estrazione`, poi `Riposo`.
- **Fori del tamburo:** `_show_chambers` mostra `Bossolo0`…`Bossolo5` solo nelle camere con il colpo, con lo stesso calcolo dei LED.
- **Sparo:**
  - velocità = max(1, 0,83 s × cadenza effettiva), quindi finisce sempre prima del colpo successivo (con la cadenza base va a 1,25×);
  - il tamburo "girato" vale fino alla fine della clip; poi `Riposo` lo riporta a 0° e i LED si ricalcolano senza salti.
- **Ricarica:**
  - velocità = 3,77 s ÷ tempo di ricarica (1,26× senza boost);
  - se la ricarica parte durante uno sparo (ultimo colpo), `Ricarica` aspetta la fine dello sparo e poi accelera per finire insieme alla ricarica vera (verificato: scarto 0 ms).
- **Ispezione:** solo da `Riposo` e non durante ricarica o cambio arma.
- **Costanti del codice legate ai tempi di Blender:** `EJECT_TIME = 0.9`, `LOAD_START = 2.3`, `LOAD_END = 3.2` (in secondi della clip a velocità normale).
- **L'arma non aggiunge la sua ricarica "finta"** (abbassarsi e inclinarsi) e il rinculo calcolato via codice è al 30%: il movimento è quello delle animazioni.

### Difetti e cose da migliorare
1. **Ultimo colpo:** sparando l'ultimo colpo, `Ricarica` parte dopo lo sparo e va a circa 1,6×, quindi sembra un po' frettolosa. Se dà fastidio:
   - una ricarica più lunga dopo l'ultimo colpo;
   - oppure accorciare lo sparo quando c'è una ricarica in coda.
2. **Gli altri giocatori non vedono l'arma** (nessuna arma in terza persona per ora): vale per tutte le armi.
3. **Nessun suono** (vale per tutto il gioco).
4. **Nessun colpo a vuoto:** con 0 colpi la ricarica parte da sola, quindi non serve; da rivedere se un giorno la ricarica diventerà manuale.
5. **Misure di LED e tempi scritte nel codice:** se il modello cambia (vedi Blender §8 e la tabella dei tempi), vanno aggiornati shader e costanti. `test_37` controlla i LED e i tempi principali.

### Corretti
- (2 novembre 2026) Modello troppo piccolo e decentrato in prima persona: ingrandito e ruotato.
- (2 novembre 2026) Inclinazione di ricarica e rinculo del codice che si sommavano alle animazioni: tolti o ridotti per i modelli animati.
- (2 novembre 2026) Arma a terra troppo grande (circa 80 cm): nuovo parametro `pickup_scale` in `WeaponData`, 0,5 per la Magnum.
- (2 novembre 2026) Tremolio della visuale a ogni sparo: nuovo parametro `camera_shake_degrees` in `WeaponData` (1,2° per la Magnum), attivato dal segnale `fired` dell'arma in `FpsController`; è solo visivo e non sposta la mira.

### Verifiche fatte
- `test_37`, con i controlli per Estrazione, fori vuoti, bossolo espulso, stato dopo la ricarica, tremolio e scala a terra:
  - danni 200, 100, 50, 25, 25, 25 su sei zombie in fila, e con il Peperoncino 220, 110, 55;
  - Caricatore XL senza effetto e tratti ignorati;
  - muri intatti che fermano il colpo;
  - LED a ogni passo (sparo, ultimo colpo che lampeggia, ricarica, accensione, ispezione);
  - animazioni e ricarica che finiscono insieme;
  - cassa del poligono.
- `net_magnum`: il client spara attraverso tre zombie, l'host applica 200, 100 e 50, il client riceve le tre conferme.
- Primi piani dello shader con combinazioni di LED note: anelli e strisce corrispondono alle camere giuste.
- (2 novembre 2026, bossolo corretto) Screenshot in prima persona fotogramma per fotogramma: il bossolo esce a destra con un arco e ricade fuori dall'inquadratura; `test_37` e `net_magnum` verdi.
- (2 novembre 2026, nuovo modello) Importazione senza errori; misure dei LED controllate sulla mesh nuova (anelli dei fori fino a circa 0,033 m dal centro, strisce a 0,037 m: la soglia 0,034 m le separa); batteria completa `bash tests/run_tests.sh` tutta verde; screenshot in prima persona di estrazione, riposo, sparo, bossolo, ricarica, ispezione e arma a terra.

---

## 4. Istruzioni per chi riprende

### Prossimi passi in Godot
1. Provare la Magnum con F5: peso dello sparo, tremolio, fori vuoti, `Estrazione`, ricarica e dimensione del lampo. Se il lampo stona, ridurlo in Blender.
2. Aggiungere il suono dello sparo, quando il gioco avrà l'audio.
3. Correggere gli altri difetti aperti del §3.

### Come modificare modello e animazioni in Blender
1. Aprire `blender/weapons/magnum.blend` con il server MCP avviato.
2. Rispettare i vincoli del §2 su LED, materiali e posizioni. Se cambiano tempi o misure, aggiornare insieme tabella, costanti del codice e test.
3. Esportare così:
   - portare tutte le strisce NLA al fotogramma 1;
   - rimettere le posizioni di riposo;
   - esportare in `assets/models/weapons/magnum.glb` con `use_active_collection=True`, `export_animation_mode='NLA_TRACKS'`, `export_optimize_animation_size=False` e `export_optimize_animation_keep_anim_object=True`;
   - riportare le strisce ai fotogrammi di partenza: `Riposo` 1, `Estrazione` 70, `Sparo` 90, `Ricarica` 125, `Ispezione` 245;
   - ripristinare di nuovo le posizioni di riposo, poi salvare il `.blend`.
   - **Posizioni di riposo, in pratica:** con le strisce al loro posto, `scene.frame_set(1)` fa valutare `Riposo`; le tracce che `Riposo` non anima vanno rimesse a mano. Oggi è il caso di posizione e rotazione di `Espulso`: (0,018, 0,004, 0,042) e rotazione 0 in Blender, scala 0,001.
   - **Posizioni mai animate:** la posizione di `Ventola`, `Tamburo`, `Gru`, `Cane` e `Lampo` e la rotazione di `Cartucce` non sono in nessuna clip, quindi valgono quelle salvate nel `.blend`. In Blender (Z in alto): `Ventola` (-0,0192, 0,165, 0,007), `Tamburo` (0,022, 0, 0,0431), `Gru` (-0,022, 0,004, -0,012), `Cane` (0, -0,084, 0,045), `Lampo` (0, 0,284, 0,052), rotazione di `Cartucce` 0.
   - **Controllo dopo il salvataggio:** confrontare le trasformazioni degli oggetti al fotogramma 1 con i nodi del `.glb` (Y del glTF = Z di Blender, Z del glTF = -Y di Blender). Se qualcosa non torna, il `.blend` è sbagliato, non il gioco.
   - **Valore fisso del bossolo in `Riposo`:** nel `.glb` la posizione di `Espulso` in `Riposo` resta quella di fine sparo. Non si vede perché è a scala 0,001.
   - **Verifica:** dopo l'export conviene confrontare il `.glb` nuovo con una copia del precedente, traccia per traccia (con `GLTFDocument` in uno script di Godot), per essere sicuri che sia cambiato solo quello che si voleva.
4. Controllare nel `.glb` clip, durate e posizioni dei nodi, poi lanciare `--import` e `test_37`.

