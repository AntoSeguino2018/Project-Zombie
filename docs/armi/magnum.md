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
| Rinculo della visuale | 6° in alto, fino a 1,5° di lato, recupero 7 |

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

**File:** `blender/weapons/magnum.blend` (sorgente, collezione `Magnum`), esportato in `assets/models/weapons/magnum.glb`. Lunghezza circa 42,5 cm (scala volutamente esagerata), origine sull'impugnatura, canna verso -Z. 5.044 triangoli contando cartucce, bossoli, caricatore e lampo. Animazioni a 30 fps: `Riposo` 2,03 s, `Sparo` 0,83 s, `Ricarica` 3,77 s, `Ispezione` 3,23 s.

### Modello
- **Design approvato dallo sviluppatore:** revolver massiccio alla Deep Rock Galactic, argento con impugnatura nera, tema informatico spinto e luci azzurre. Contiene:
  - chip e piste da circuito stampato sull'impugnatura;
  - tamburo ispirato a un disco;
  - alette da dissipatore sulla canna;
  - una ventola sul lato sinistro;
  - sei LED in cima al fusto;
  - la "Z" in binario (`01011010`) sul lato destro.

  Niente texture, solo materiali: `M_Argento`, `M_Interno`, `M_Acciaio_Scuro`, `M_Azzurro_Luce` (luci, emissione 2,2), `M_Nero_Impugnatura`, `M_Ottone`, `M_Lampo`.
- **Nodi:**
  - radice `Magnum`, poi `Fusto`, `Impugnatura`, `Cane`, `Grilletto`, `Ventola`, `Lampo` e `Gru` (perno del tamburo, con `Braccio` e `Tamburo`);
  - sotto `Tamburo`: `Bossolo0`…`Bossolo5` (camera 0 in alto, poi in senso orario guardando dalla canna, cioè l'ordine di sparo), `Cartucce` e `Caricatore`;
  - la radice `Magnum` è animata in tutte le clip: il movimento dell'arma (rinculo, oscillazione, giri dell'ispezione) è nelle animazioni.
- **Stato a riposo:**
  - `Lampo`, `Cartucce` e `Caricatore` sono a scala 0;
  - i bossoli stanno nascosti dentro il tamburo;
  - il tamburo finisce sempre su un multiplo di 60°, quindi tornare a zero non si nota.
- **Verifiche fatte in Blender:** nessuna collisione tra `Tamburo` e `Fusto`, né tra `Cartucce` e `Fusto`, su tutta la sequenza. `Perno` (in `Braccio`) e `Ventola` sono incassati di proposito.

### Tempi chiave (usati dal codice: se cambiano, aggiornare Godot)

| Animazione | Cosa succede | Quando |
|---|---|---|
| Sparo | il tamburo gira di +60° | 0,03 → 0,10 s |
| Ricarica | il braccio (`Gru`) apre il tamburo | 0,40 → 0,73 s |
| Ricarica | i bossoli escono e spariscono | 0,83 → 1,20 s |
| Ricarica | il caricatore con le cartucce compare | 1,57 s |
| Ricarica | il caricatore entra nel tamburo | fino a 2,27 s |
| Ricarica | il caricatore se ne va e sparisce | 2,37 → 2,77 s |
| Ricarica | il tamburo gira | 2,47 → 3,20 s (finisce a -60°) |
| Ricarica | il braccio richiude | 2,80 → 3,20 s |
| Ispezione | il tamburo gira | da 1,87 s |

### Difetti da correggere
1. **Scala 0 → errori all'importazione.**
   - `Lampo`, `Cartucce` e `Caricatore` sono nascosti con scala 0, e a ogni importazione Godot stampa 9 errori "Basis must be normalized in order to be casted to a Quaternion".
   - Sono innocui ma sporcano la console dell'editor.
   - **Correzione:** scala minima (es. 0,001) invece di 0, nei fotogrammi chiave e nello stato a riposo.
2. **Ricarica senza mani:**
   - il caricatore compare dal nulla a 1,57 s (scala da 0 a 1 in un fotogramma) e, quando viene tirato via (2,37 → 2,77 s), si sposta all'indietro e in alto fino a passare **molto vicino alla camera** in prima persona: sembra un disco che vola verso il giocatore;
   - **correzione:** percorso più corto o laterale, uscita verso il basso; oppure, quando ci saranno, le mani.
3. **Bossoli:** cadono con un'animazione, non con la fisica; escono sempre tutti e 6, anche se alcuni colpi non erano stati sparati. Realistico per un revolver con caricatore rapido; da tenere solo se piace.
4. **Fine di `Ricarica` diversa dal riposo:** bossoli a scala 0 e cartucce a scala 1. In gioco non si vede, perché subito dopo parte `Riposo` che rimette tutto a posto; va ricordato se si usa la clip altrove.
5. **Lampo dello sparo poco visibile** in prima persona (a 1280×720 è un puntino in punta alla canna). Da valutare un lampo più grande o più lungo; in alternativa una luce in Godot.
6. **Manca un'animazione di estrazione:** quando la si prende in mano l'arma usa la discesa e risalita generiche del gioco (0,3 s) più l'accensione dei LED. Una clip `Estrazione` corta (0,3–0,5 s) la renderebbe più viva.
7. **`Riposo` non è marcata come ciclo** (il glTF non lo prevede): il ciclo lo imposta il codice. Va bene così, è solo da sapere.
8. **Vincoli per i LED:** lo shader riconosce i LED dalla loro posizione nella mesh. Se si modificano `Tamburo` o la striscia in cima a `Fusto`, vanno mantenute queste misure o aggiornato `led_mask.gdshader`:
   - **tamburo:** camere ogni 60° partendo dall'alto (90°) in senso orario guardando dalla canna; anelli delle camere a raggio < 0,03 m; strisce esterne a raggio > 0,03 m a metà tra due camere; disco centrale a raggio < 0,008 m;
   - **striscia del fusto:** y > 0,088, |x| < 0,008, z da -0,045 (davanti) a 0,0325 (dietro), passo 0,0155;
   - **materiale:** le luci devono restare su `M_Azzurro_Luce` (superficie 2 del tamburo, 3 del fusto).
9. **Insidia dell'export** (vedi RECAP §6): con `NLA_TRACKS` gli oggetti animati possono restare spostati nel `.blend` dopo l'export; ripristinare le posizioni e riportare le strisce NLA al fotogramma 1 prima di esportare.

### Corretti
- (2 novembre 2026) Tamburo che non entrava nell'arma dopo un export (vedi insidia NLA).

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
2. **Arma a terra troppo grande:** la cassa mostra il modello in prima persona ingrandito 2,4 volte (pensato per le armi di cubetti), quindi la Magnum fluttuante è lunga circa 80 cm. Serve una scala per arma.
3. **Gli altri giocatori non vedono l'arma** (nessuna arma in terza persona per ora): vale per tutte le armi.
4. **Nessun suono** (vale per tutto il gioco).
5. **Nessun colpo a vuoto:** con 0 colpi la ricarica parte da sola, quindi non serve; da rivedere se un giorno la ricarica diventerà manuale.
6. **Misure di LED e tempi scritte nel codice:** se il modello cambia (vedi Blender §8 e la tabella dei tempi), vanno aggiornati shader e costanti. `test_37` controlla i LED e i tempi principali.
7. **Errori di importazione:** dipendono da Blender (vedi Blender §1); in Godot non si possono silenziare.

### Corretti
- (2 novembre 2026) Modello troppo piccolo e decentrato in prima persona: ingrandito e ruotato.
- (2 novembre 2026) Inclinazione di ricarica e rinculo del codice che si sommavano alle animazioni: tolti o ridotti per i modelli animati.

### Verifiche fatte
- `test_37`, 37 controlli:
  - danni 200, 100, 50, 25, 25, 25 su sei zombie in fila, e con il Peperoncino 220, 110, 55;
  - Caricatore XL senza effetto e tratti ignorati;
  - muri intatti che fermano il colpo;
  - LED a ogni passo (sparo, ultimo colpo che lampeggia, ricarica, accensione, ispezione);
  - animazioni e ricarica che finiscono insieme;
  - cassa del poligono.
- `net_magnum`: il client spara attraverso tre zombie, l'host applica 200, 100 e 50, il client riceve le tre conferme.
- Primi piani dello shader con combinazioni di LED note: anelli e strisce corrispondono alle camere giuste.
