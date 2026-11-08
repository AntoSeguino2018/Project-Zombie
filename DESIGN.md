# Documento di design: Project Zombie (bozza)

Documento vivo: si aggiorna man mano che le idee si chiariscono.
Le voci sono di due tipi:
- ✅ **Deciso**: scelto da te
- 💡 **Proposta**: da confermare, cambiare o buttare

---

## In una frase
✅ FPS roguelike in prima persona, co-op da 1 a 4 giocatori, contro orde di zombie **vari, strani e per niente cupi**, dove **le armi sono le protagoniste**.

## Pilastri
Ogni nuova idea si confronta con questi tre punti. Se non ne rafforza nessuno, probabilmente non serve.
1. ✅ **Le armi prima di tutto.** Si va dalla pistola banale ad armi assurde inventate apposta. La progressione della run passa soprattutto dalle armi.
2. ✅ **Zombie mai visti.** Tanti modelli diversi, ognuno con un comportamento riconoscibile e caratteristiche atipiche per uno zombie. Colorati, non horror.
3. 💡 **Caos co-op leggero.** Si gioca con gli amici per ridere: situazioni assurde, combo esagerate, poca serietà.

## Da dove nasce
- ✅ L'ispirazione viene dal vostro gruppo universitario: persone, posti, coffee break, meme.
- ✅ **La storia (8 novembre 2026):** i protagonisti sono studenti di ingegneria che, durante un'apocalisse zombie, restano bloccati all'università. Sopravvivono grazie alle armi, ma soprattutto ai **progetti segreti del campus**, sviluppati in team con l'esercito: è per questo che in giro ci sono armi così assurde, proiettili da carro armato e laboratori nascosti.
- ✅ **L'università si vede, con i nomi storpiati.** I posti sono ispirati al campus di Monte Sant'Angelo della Federico II, ma nel gioco si chiamano **"Monte Sant'Arcangelo"** e **"Università Federico III"**: chi c'è stato li riconosce, e se un giorno il gioco esce non ci sono marchi veri. *(Sostituisce la vecchia regola "nessun riferimento esplicito all'università".)*
- ✅ Le vostre battute restano il "DNA" di armi, nemici, nomi e dettagli.
- 💡 I meme nuovi che nascono ogni mese possono diventare easter egg, nomi di oggetti e varianti di armi. È un modo naturale per aggiornare il gioco nel tempo.

---

## Ambientazione e stile

### Stile grafico
✅ Simile a **Deep Rock Galactic**:
- low-poly, superfici piatte, forme grosse e leggibili
- ambienti illuminati soprattutto da **luci colorate** (neon, led, insegne)
- colori forti solo su ciò che conta: nemici, armi, oggetti

### Il mondo
✅ Base reale: le aule studio gialle, alte, con tavoli e lavagne, "che sembrano le backrooms".

✅ **La mappa è il campus di Monte Sant'Arcangelo** (passo 3.7, scheda in [docs/mappa/campus.md](docs/mappa/campus.md)):
- grande (circa 230 × 180 m), divisa in zone: aula studio sotterranea, Centri comuni, viale con la passerella, mensa, aulario, biblioteca, torre dei dipartimenti con il tetto, parcheggio con la stazione, laboratori segreti sotto il parcheggio;
- **si parte da una stanza sotterranea simile a un'aula studio**, con una lavagna bianca enorme su tutta la parete sinistra guardando l'uscita; si esce salendo le scale;
- **la mappa si sblocca spendendo soldi** in punti precisi (porte), come la modalità zombi di Black Ops 2. I costi sono provvisori: si cambiano in `tools/build_campus.py`;
- **le zone sono anche i "chunk"** per la rete e le ondate: con al massimo 4 giocatori si lavora su al massimo 4 zone alla volta (più quelle accanto).

Il vecchio "Complesso" (passo 3.6) resta nei file per i test, ma non si gioca più.

💡 Proposta precedente (il Complesso), superata dal campus:
- Il mondo è **il Complesso**: un'architettura enorme e un po' assurda di stanze gialle, corridoi, sale alte, scantinati e locali tecnici.
- Il tono non è inquietante:
  - all'inizio è solo "strano" (luci al neon, ronzio, tutto uguale)
  - poi diventa caciarone (zombie ridicoli, esplosioni, colori)
- Più si scende in profondità, più l'ambiente cambia:
  - stanze gialle in superficie
  - poi archivi, magazzini e sale macchine
  - poi zone sempre più strane e colorate

💡 **Vantaggio tecnico:** un mondo fatto di stanze e corridoi si presta benissimo a livelli **generati unendo moduli** (stanze prefabbricate agganciate tra loro). È molto più semplice e controllabile di un terreno aperto, ed è perfetto per un roguelike.

### Distruttibilità
✅ **Opzione A, blocchi distruttibili** (prototipo al passo 1.8):
- Solo alcuni elementi sono distruttibili: muri interni, colonne, coperture, oggetti di scena. Sono fatti di blocchi piccoli (0,25 m), uniti senza fessure: il muro sembra compatto e i blocchi si distinguono solo dalle sfumature del colore. Pavimento e muri esterni restano indistruttibili.
- **Li rompono:** granate ed esplosioni, pugni (il pugno normale stacca un blocco, Mano pesante un pezzo grosso come un pugno), zombie scaraventati abbastanza forte e il Bestione in carica, che li sfonda e prosegue.
- **Non li rompono:** i colpi delle armi da fuoco normali.
- I blocchi rimasti senza appoggio crollano. I pezzi volano come detriti; dopo aver toccato terra restano **spostabili per 10 secondi** (giocatori e zombie li spingono camminando, le esplosioni li rilanciano), poi diventano macerie immobili che **restano a terra per sempre**. Un singolo crollo lancia al massimo 100 pezzi; il resto si polverizza.
- Gli zombie non vedono attraverso i muri, ma dopo un crollo passano dai buchi nuovi.
- 💡 Più avanti: armi sbroccate pensate per demolire, materiali con resistenze diverse (legno, cemento, metallo).
- Scartata per ora l'opzione "terreno scavabile ovunque" alla Deep Rock: troppo costosa per la rete e la navigazione.

### La lobby
✅ La lobby è la vostra **aula studio**: stanza gialla, alta, tavoli, lavagne.

✅ Idea approvata: la lobby è un luogo da usare:
- **Lavagna** = mappa della run: si sceglie dove andare, magari con la mappa "disegnata col gesso"
- **Tavoli** = rastrelliere: si scelgono personaggio e arma iniziale
- **Macchinetta del caffè** = boost scelto prima della partenza (o sblocchi della meta-progressione)
- Ci si gira liberamente in prima persona con gli amici prima di partire, come nella lobby di Deep Rock

---

## Personaggi
- ✅ **Tutti uguali** in vita, velocità e salto.
- ✅ Ognuno si distingue solo per **un'abilità attiva o una passiva**.
- 💡 Ogni personaggio è un membro del gruppo, in versione stilizzata low-poly. Nomi e abilità sono ispirati alla persona, non dichiarati.
- 💡 Le abilità devono **interagire con le armi** (potenziarle, modificarle, sfruttarle) invece di rubare loro la scena. Così il focus resta sulle armi.

### Personaggio 1: tu
**Descrizione:** ingegnere informatico, disegna, suona, battuta pronta, fama (scherzosa) di "violento". 1,72 m, occhiali, pizzetto alla Tony Stark, fisico atletico.

✅ Abilità: **Mano pesante** (passiva).

Tutti i personaggi hanno un colpo corpo a corpo base (tasto **F**): un pugno che fa 10 danni e spinge un po'. Con Mano pesante diventa una mazzata da 25 (prototipo fatto al passo 1.5b):
- lo zombie viene **scaraventato via**
- se in volo sbatte contro altri zombie, fa a ognuno **20 danni** e li spinge
- se sbatte contro un muro, subisce lui 20 danni
- il Bestione è troppo pesante per volare: viene solo stordito per un attimo
- anche il colpo finale fa volare via il corpo

Idee scartate per ora (potranno servire ad altri personaggi): Overclock (l'arma spara più veloce, poi si surriscalda), Prototipo (torretta con una copia della tua arma), Assolo (onda sonora che respinge).

**Modello 3D:** statura media, corporatura atletica, occhiali e pizzetto ben visibili anche in low-poly, mani e braccia un po' grandi (tipico dello stile Deep Rock). Un tuo autoritratto o un turnaround sarebbe il riferimento ideale.

---

## Armi (il cuore del gioco)
✅ Struttura approvata per il momento:
- **Rarità a tre gradini:**
  1. **Comuni:** armi realistiche (pistola, carabina, fucile a pompa, mitraglietta)
  2. **Truccate:** armi normali con una modifica assurda (colpi che rimbalzano, caricatori a nastro, canne multiple)
  3. **Sbroccate:** armi inventate da zero, con meccaniche uniche
- **Nella run:** si parte con un'arma comune e se ne trovano altre nel Complesso. Si portano **due armi** e si cambia al volo.
- **Modifiche casuali:** ogni arma trovata può avere 1 o 2 tratti estratti a caso (es. "incendiaria", "perforante", "a raffica"). Così due armi uguali non sono mai identiche.
- **Oggetti della run:** potenziano le armi e si accumulano, creando combo sempre più esagerate.
- **Tra una run e l'altra:** si sbloccano nuove armi sbroccate che entrano tra quelle trovabili.

✅ **Prima sbroccata: la Magnum**, revolver tech "da ingegneria informatica" (chip e piste sull'impugnatura, ventola, LED azzurri, la Z in binario). Il colpo attraversa tutti gli zombie: 200 al primo, poi dimezza a ognuno fino a 25. Sei colpi e basta (niente estensioni), non rompe i muri. I LED sul tamburo mostrano i colpi rimasti.

💡 **Spunti di armi sbroccate**, solo per dare il tono (le migliori nasceranno dai vostri meme):
- **Moka a pressione:** spruzza un getto bollente che si allarga, una specie di lanciafiamme
- **Sparagraffe rotante:** una mitragliatrice di graffette che "inchioda" i nemici al muro
- **Chitarra sonica:** un fucile a pompa a onde sonore, che a ritmo fa più danno
- **Penna tracciante:** disegna una linea a mezz'aria che diventa un muro o una trappola

---

### Armi bianche e proiettili da carro armato
✅ Decisi l'8 novembre 2026 (passi 3.9 e 3.10):
- **Armi bianche** in un **terzo slot** dedicato (tasto 3), oltre alle due armi da fuoco: **martello piccolo** da fabbro, **martellone** a due mani (molto basilare) e **katana**. Si comprano **appese al muro** in punti fissi della mappa, e ogni tanto escono anche dalle casse.
- **Proiettili da carro armato** sparsi per la mappa, vicino ai mezzi dell'esercito e nei laboratori. Si portano **in spalla**.
- **La combo:** se un giocatore ha un proiettile in spalla e un compagno lo colpisce con il martello (piccolo o grande), il proiettile parte a razzo come un colpo di bazooka, **nella direzione in cui guarda chi lo porta**. Chi porta mira, chi martella fa da grilletto.

## Boost: le macchinette
✅ Le macchinette del caffè danno i boost (nascono dai coffee break).

✅ Prime tre fatte (passo 3.4): **Espresso** (cadenza), **Caffè doppio** (ricarica), **Merendina** (cura). Si pagano in € con i soldi personali; a volte si mangiano i soldi, a volte danno una dose doppia.

💡 Proposta:
- Sparse nei livelli, si usano con la valuta raccolta.
- Ogni bevanda o snack dà un effetto a tempo o permanente per la run. Esempi:
  - espresso: cadenza di fuoco
  - doppio: ricarica
  - snack: cura
- Dettagli comici: a volte la macchinetta "si mangia i soldi", oppure ti dà due prodotti.
- Possono esistere macchinette speciali più rare, con effetti più forti o con un rischio.

---

## Zombie
- ✅ **Tanti modelli**, non cupi.
- ✅ Lenti, veloci, enormi, con caratteristiche atipiche.
- ❓ **La loro natura è ancora da decidere.**

💡 Tre strade possibili per l'origine:
1. **Ceppi colorati:** un contagio con più varianti, ognuna con un colore e un comportamento. Ha un grande vantaggio di gioco: riconosci il tipo dal colore, anche da lontano e nel caos.
2. **Sovraccarichi:** persone "esagerate" da qualcosa (troppa caffeina? troppo di tutto?). Ogni zombie porta all'estremo un difetto o un'abitudine. È la strada dove i vostri inside joke entrano meglio.
3. **Nati dal Complesso:** creature generate dal posto stesso, metà persone e metà oggetti (sedie, lampade, armadietti).

✅ **Per ora si parte con 3 tipi:** uno base e due speciali, un tank e uno veloce. Prototipi in greybox fatti al passo 1.5b; ogni numero si regolerà giocando.

| Nome provvisorio | Vita | Velocità | Comportamento |
|---|---|---|---|
| **Camminatore** (base, già fatto) | 60 (5 colpi di carabina) | 4,5 m/s | Insegue in gruppo. Colpo in mischia da 15, con mezzo secondo di preparazione. |
| **Scattista** (veloce) | 30 (3 colpi) | 8,5 m/s: più veloce di te che cammini, più lento di te in sprint | Si avvicina a zig-zag. A 5 m si ferma un attimo (preparazione 0,3 s) e si lancia in **tuffo** (10 danni). Se manca il bersaglio resta a terra stordito per quasi un secondo: è il momento per farlo fuori. Più basso e magro degli altri. |
| **Bestione** (tank) | 400 | 2,8 m/s | Alto circa 2,6 m. Colpo a terra da 35, con quasi un secondo di preparazione. Se ti vede tra 6 e 15 m **carica** in linea retta: si prepara per 0,8 s, poi corre fortissimo per 15 m (30 danni e ti scaraventa via). Se finisce contro un muro resta stordito. **Corazzato davanti** (pochi danni), il **punto debole è dietro**, ben visibile e luminoso. |

💡 Bestiario futuro, da aggiungere dopo i primi tre. Ogni zombie ha un ruolo preciso nel combattimento:

| Nome provvisorio | Ruolo | Cosa lo rende diverso |
|---|---|---|
| **Camminatore** | base, in gruppo | Il nostro primo nemico: lento ma sempre in tanti |
| **Scattista** | veloce, fragile | Corre a zig-zag e si lancia in tuffo; poca vita |
| **Bestione** | enorme, lento | Carica in linea retta; davanti è corazzato, il punto debole è dietro |
| **Gonfio** | controllo dell'area | Si gonfia e scoppia lasciando una pozza che rallenta |
| **Sputacchiatore** | a distanza | Lancia proiettili ad arco (richiede i proiettili fisici, passo 1.6) |
| **Rimbalzante** | dall'alto | Salta su muri e soffitti (le stanze sono alte!) |
| **Sdoppiante** | resistenza | Quando muore si divide in due zombie più piccoli, e quelli in quattro |
| **Urlatore** | supporto | Potenzia o richiama gli zombie vicini: va eliminato per primo |
| **Boss** | uno per livello | Ognuno con regole proprie (da progettare) |

---

## Struttura della run
✅ Per ora:
- **Una sola mappa, molto grande:** il campus, che si apre a pagamento zona per zona.
- ✅ **Come si vince (provvisorio, per provare):** sul tetto della torre c'è un elicottero che costa moltissimo (5.000 €, tutti possono versare); arriva dopo un po' e porta a casa chi sale (passo 3.8).
- **La run è fatta di ondate di zombie.** A ogni ondata non cresce il numero di zombie, ma un **budget di pericolosità**:
  - ogni tipo di zombie ha un costo che misura quanto è pericoloso (es. Camminatore 1, Bestione 5);
  - l'ondata "spende" il budget scegliendo i tipi ogni volta in modo diverso: con 6 punti possono arrivare un Bestione e un Camminatore, oppure sei Camminatori;
  - il budget sale a ogni ondata (es. 6 nella prima, 20 in una successiva).
- **Soldi personali:** ognuno ha i suoi e decide come spenderli (macchinette, casse).

💡 Ancora da decidere:
- Cosa succede tra un'ondata e l'altra (pausa per spendere, macchinette, riparazioni).
- Altri modi di vincere, oltre all'elicottero provvisorio.
- ✅ Chi finisce la vita resta **a terra** e i compagni possono rianimarlo; chi non viene rianimato muore e rinasce a fine ondata. Se nessuno resta in piedi la run è persa (per ora si riparte subito; più avanti si tornerà alla lobby con qualche sblocco).
- Più avanti: più mappe, o zone del Complesso collegate.

---

## Domande aperte
- [ ] Natura degli zombie: quale delle tre strade, o un'altra?
- [x] Abilità del tuo personaggio: **Mano pesante**
- [ ] Gli altri membri del gruppo: descrizioni (come hai fatto tu)
- [ ] Meme e tormentoni del gruppo: elenco grezzo
- [ ] Le prime 3-4 armi sbroccate "vere", nate dalle vostre battute
- [ ] Nome del gioco (Project Zombie è provvisorio)
- [ ] Disegni: autoritratto/turnaround, uno schizzo dell'aula studio, primi zombie

> Nota: se un giorno il gioco verrà pubblicato, persone reali esterne al gruppo (es. professori) vanno solo parodiate in modo irriconoscibile: nomi e facce inventati.
