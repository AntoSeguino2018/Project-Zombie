# Roadmap: Project Zombie (nome provvisorio)

Obiettivo: FPS roguelike in prima persona sugli zombie, grafica low-poly colorata e stilizzata, più personaggi giocabili, co-op online fino a 4 giocatori. Le armi sono le protagoniste.

**Risorse:** 5–15 ore a settimana, sviluppatore principalmente solo (il team potrebbe crescere).
**Tempi indicativi:** fino alla vertical slice servono circa **270–450 ore**. Con una media di 10 ore a settimana sono **6–12 mesi**. Le stime di ogni fase sono in ore, così valgono anche nelle settimane più piene o più vuote.

---

## Decisioni di base

| Tema | Scelta consigliata | Perché |
|---|---|---|
| Motore | **Godot 4** (GDScript) | Gratuito e open source. Scene, script e risorse sono **file di testo**, quindi posso leggerli e modificarli direttamente (con Unity e Unreal gran parte del lavoro passa dall'editor o da file binari). Importa glTF da Blender senza problemi. Ha il multiplayer di alto livello già integrato. |
| Rete | **Listen server** (un giocatore fa da host), server autoritativo per nemici, oggetti e loot | È il modello standard per il co-op a 4. Niente server dedicati da pagare. |
| Matchmaking | Prima IP/LAN, poi **Steam** (lobby + relay tramite GodotSteam) | Con Steam gli amici si invitano senza aprire porte del router. |
| Piattaforma | PC (Windows), distribuzione su Steam | Console solo molto più avanti, se mai. |
| Stile grafico | Low-poly alla **Deep Rock Galactic**: flat shading, texture a palette (atlante di colori), luci colorate, nebbia | Identità **originale**: personaggi, mondo e meccaniche nostre. Dettagli in [DESIGN.md](DESIGN.md). |
| Versioning | **Git + GitHub** (repo privato) | Backup e storico di ogni modifica. |

> Il progetto vive in `C:\Dev\Project-Zombie`, fuori da OneDrive (la sincronizzazione blocca o corrompe i file di Godot e Git). Il backup sarà GitHub.

**Regola d'oro:** il multiplayer si costruisce **dall'inizio**. Aggiungerlo a un gioco nato single-player vuol dire riscriverlo quasi tutto.

---

## Fasi

### Fase 0: Pre-produzione (~10–15 ore)
- [ ] Mini documento di design: **bozza in [DESIGN.md](DESIGN.md)**, da completare con le risposte alle domande aperte
- [ ] Core loop in una frase (es. *"entri nel livello → uccidi → raccogli valuta → apri casse/oggetti → completi l'obiettivo → livello successivo, più difficile"*)
- [ ] Prima bozza di 2 personaggi (concept: silhouette, arma, ruolo)
- [ ] Palette colori e moodboard di riferimento (i tuoi disegni)
- [x] Cartella di progetto, repo Git locale, struttura Godot
- [ ] Installare Godot 4 e Blender + MCP
- [ ] Repo GitHub privato per il backup

### Fase 1: Prototipo FPS in greybox (~30–50 ore)
Tutto con cubi e capsule, zero grafica definitiva.
- [x] 1.1 Controller FPS base: movimento, salto, sprint, mouse look, gravità + livello di prova in greybox
- [x] 1.2 Sensazione del movimento: al playtest il movimento funziona bene così; ritocchi (coyote time, FOV nello sprint…) solo se serviranno
- [x] 1.3 Prima arma: sparo hitscan, cadenza, dispersione, rinculo, mirino, scia e impatti, arma in prima persona
- [x] 1.4 Salute e danno: componente vita unico, manichini bersaglio, numeri di danno, hitmarker
- [x] 1.5 Primo nemico: navigazione calcolata all'avvio del livello, inseguimento, attacco in mischia schivabile, spawner provvisori; morte e rinascita del giocatore, barra della vita, bordo rosso quando si subisce danno
- [x] 1.5b Altri due zombie (Scattista veloce con tuffo, Bestione tank con corazza, punto debole e carica), pugno con il tasto F e passiva "Mano pesante", spinte e stordimento (vedi [DESIGN.md](DESIGN.md))
- [x] 1.6 Proiettili fisici (volo con gravità, controllo anti-attraversamento, esplosioni con danno ad area e spinta), armi hitscan o a proiettili dallo stesso sistema, cambio arma (1/2, rotella) e Lanciagranate prototipo
- [x] 1.7 HUD minimo: munizioni e ricarica, arma in mano, uccisioni e tempo di sopravvivenza, direzione del danno, comandi all'avvio, riepilogo alla morte con record
- [x] 1.8 Strutture distruttibili a blocchi (muri, colonne, coperture): si rompono con granate, pugni, zombie scaraventati e carica del Bestione, blocchi da 0,25 m, i pezzi senza appoggio crollano e restano a terra come macerie permanenti, la navigazione si ricalcola
- [x] 1.9 Playtest con i cubi
- **Verifica superata.** Esito del playtest:
  - Ci si annoia presto solo perché manca la parte roguelike (run, progressione, obiettivi): è la Fase 3.
  - Morti tutte giustificate: nemici leggibili e attacchi schivabili funzionano.
  - Movimento: funziona bene.
  - Zombie: funzionano; più avanti roster più ampio, animazioni e dettagli.
  - Armi: da ribilanciare più avanti.
  - Distruzione: per ora cambia il modo di giocare solo nella fuga; da ampliare.

### Idee raccolte (da collocare nelle fasi giuste)
- Arrampicata: aggrapparsi ai bordi e scavalcare (mantle), forse arrampicarsi su superfici apposite
- Ribilanciamento delle armi (insieme al sistema oggetti della Fase 3)
- Più tipi di zombie, animazioni e dettagli (Fasi 5 e 6)
- Distruzione come meccanica più centrale: armi da demolizione, obiettivi da abbattere, zombie che sfondano, materiali con resistenze diverse

### Fase 2: Fondamenta di rete (~50–80 ore)
Modello: ognuno muove il proprio giocatore (risposta immediata), l'host decide tutto il resto (nemici, danni, distruzione, oggetti).
- [x] 2.1 Menu (solo / ospita / entra via IP), un giocatore per partecipante (fino a 4), movimento sincronizzato con interpolazione, colori, visiera e nomi *(in rete gli zombie sono spenti fino al 2.3)*
- [x] 2.2 Combattimento in rete: chi spara vede subito i suoi colpi, l'host applica i danni e rimanda numeri e hitmarker; scie, impatti, granate ed esplosioni visti da tutti; vita, morte (corpo a terra), caduta fuori dal livello e rinascita decise dall'host *(muri rotti solo sull'host fino al 2.4)*
- [x] 2.3 Zombie creati e simulati solo dall'host e replicati ai client: posizione, direzione e posa del corpo (attacchi, volo, stordimento, caduta da morti), danni e spinte ai giocatori, uccisioni contate per chi le fa; chi entra dopo vede gli zombie già in campo
- [x] 2.4 Proiettili ed esplosioni (passo 2.2) e strutture distruttibili sincronizzati: l'host calcola danni e crolli e manda quali blocchi sono saltati, i detriti sono di ognuno; chi entra dopo riceve i muri già rotti
  - Da rivedere più avanti: la banda usata dagli zombie (posizione 30 volte al secondo) va misurata con molti zombie e su internet (passo 2.5)
- [ ] 2.5 Test con 4 istanze sul tuo PC, poi con amici su internet
- [ ] 2.6 Integrazione Steam (lobby, inviti, relay) *(può slittare dopo la Fase 3)*

### Fase 3: Core loop roguelike (~60–100 ore)
Scelte: una sola mappa molto grande, run a **ondate** con budget di pericolosità crescente, soldi personali (vedi [DESIGN.md](DESIGN.md)).
- [x] 3.1 **Armi trovabili:** pistola di partenza, fucile a pompa e mitraglietta oltre a carabina e lanciagranate; tratti casuali che cambiano numeri e nome (rapida, pesante, precisa, caricatore esteso, ricarica lampo); trucchi che rendono l'arma *truccata* (rimbalzante, perforante, esplosiva, incendiaria, doppia canna); casse che si aprono con E e si richiudono piene dopo 60 s (l'arma non presa sparisce); due armi in mano e scambio con quella in mano, che resta a terra ai propri piedi (e sparisce dopo 2 minuti); tutto deciso dall'host *(le sbroccate arriveranno con le idee del gruppo)*
- [x] 3.2 **Ondate:** budget di pericolosità che sale e accelera (6, 10, 14, 20, 26… con un giocatore; +60% per ogni giocatore in più), costo per tipo (Camminatore 1, Scattista 2 dall'ondata 2, Bestione 5 dall'ondata 3), pesi che cambiano a caso a ogni ondata, zombie che escono uno alla volta da punti fuori vista e ad almeno 14 m, massimo di vivi insieme, pausa di 12 s tra un'ondata e l'altra; HUD con ondata, zombie rimasti e conto alla rovescia, scritte di inizio e fine; tutto deciso dall'host, anche per chi entra dopo. Sostituisce gli spawner provvisori
  - Da regolare giocando: budget, pause, velocità di comparsa; le ondate continuano finché non si prende l'elicottero (passo 3.8)
- [x] 3.3 **A terra e rianimazione:** finita la vita si resta a terra per 30 s (si striscia, non si spara, gli zombie ti lasciano stare, il nome si vede attraverso i muri); un compagno ti rialza tenendo premuto E per 3 s vicino a te (riparti con il 40% della vita, e intanto non ti dissangui); se nessuno arriva in tempo, o se cadi fuori dal livello, muori. A fine ondata chi è a terra si rialza e chi è morto rinasce accanto a un compagno. Se nessuno è più in piedi la run è persa: riepilogo (ondata, uccisioni, record) e dopo 8 s si riparte da capo (ondata 1, solo pistola, casse chiuse); tutto deciso dall'host, anche per chi entra dopo
  - Da regolare giocando: tempi di dissanguamento e rianimazione, vita al rialzo; da soli andare a terra fa perdere subito la run
  - I muri rotti restano rotti alla ripartenza (si sistemerà ricaricando la mappa)
- [x] 3.4 **Soldi e macchinette:** soldi personali in € (taglia a chi uccide: Camminatore 10, Scattista 15, Bestione 60; premio a tutti a fine ondata, 25 + 5 × ondata; 20 a chi rianima un compagno), che si azzerano a ogni nuova run; tre macchinette del caffè vicino alla partenza (Espresso 40 €: cadenza +30% per 60 s; Caffè doppio 40 €: ricarica +40% per 60 s; Merendina 30 €: +50 di vita), con il 5% di probabilità che si mangino i soldi e l'8% di una dose doppia; ricomprare un boost ne allunga la durata; casse a 100 €; HUD con soldi, guadagni, boost attivi e avvisi; tutto deciso dall'host, anche per chi entra dopo
  - Da regolare giocando: prezzi, taglie e premi (in una partita di prova si arriva a ~90 € dopo l'ondata 1 e ~600 € all'ondata 5)
- [x] 3.5 **Oggetti passivi impilabili**, definiti come dati (PassiveItem: statistica, aumento per copia, nome, colore, probabilità). Dieci oggetti: Proiettili al peperoncino (+10% danno), Grilletto unto (+10% cadenza), Dita da pianista (+15% ricarica), Caricatore XL (+20% colpi), Scarpe da ginnastica (+6% velocità), Felpa imbottita (+20 vita massima), Salvadanaio (+25% soldi dalle uccisioni), Cerotto (+3 vita a uccisione), Guanto da forno (+30% pugni), Defibrillatore tascabile (+30% velocità di rianimazione). Ogni copia somma di nuovo l'effetto; si combinano con i boost. Si trovano: uno a testa a ogni ondata superata, e lasciati a terra dagli zombie (Bestione sempre, Scattista 4%, Camminatore 2%), che può prendere chiunque. HUD con l'elenco e l'effetto totale; si perdono alla ripartenza; tutto deciso dall'host, anche per chi entra dopo
  - Da regolare giocando: valori, probabilità, quanti oggetti si trovano; più avanti oggetti rari e leggendari con effetti speciali (Fase 6)
  - Oggetti lasciati a terra spariscono dopo 2 minuti. Con F3 si vedono le statistiche delle prestazioni (FPS, fisica, disegno, zombie, detriti, cose a terra)
  - Corretto il crollo degli FPS nelle ondate alte: gli effetti degli oggetti rileggevano i file dal disco a ogni tick (6 tipi di oggetti = 7 FPS); ora si tengono in memoria. Segni dei colpi limitati a 40, senza ombre per gli effetti piccoli
- [x] 3.6 **Mappa grande in greybox: il Complesso** (circa 112 × 76 m, a cielo aperto per ora): Atrio (partenza, tre macchinette), Aula studio gialla (file di tavoli, lavagna), Cortile (aiuole, muri distruttibili), Corridoio che collega tutto, Archivio (scaffali e corridoi stretti), Sala alta (soppalco a 3 m con due rampe), Magazzino (pile di casse, piattaforma a 2 m). 6 casse, 7 macchinette, 15 punti di comparsa sparsi, 5 strutture distruttibili, nomi delle zone sulle porte. Il menu fa giocare nel Complesso; il vecchio livello resta come "Poligono di prova" (da soli). La mappa si genera da uno script (pianta scritta in coordinate), così si ritocca in fretta
  - Da regolare giocando: dimensioni, porte, coperture, dove stanno casse e macchinette; più avanti soffitti e luci al neon (Fase 5)
  - Zombie: navigazione più larga nel Complesso (percorsi a 0,75 m dai muri) e anti-incastro (se non avanzano per mezzo secondo scivolano di lato): prima uno zombie poteva restare fermo per sempre sullo spigolo di una porta e l'ondata non finiva più. Prova automatica: 10 ondate di fila senza zombie bloccati
- [x] **Prima arma sbroccata: la Magnum** (modello vero fatto in Blender, `assets/models/weapons/magnum.glb`): 200 di danno, il colpo attraversa tutti gli zombie dimezzando il danno a ognuno fino a un minimo di 25 (200, 100, 50, 25, 25…), 6 colpi fissi (niente tratti né Caricatore XL), non rompe i muri distruttibili; LED azzurri sul tamburo uno per colpo (seguono il giro del tamburo) e striscia in cima che conta i colpi; animazioni del modello collegate a presa in mano (accensione dei LED), sparo, ricarica e ispezione (tasto V); rara nelle casse (circa 5%), sempre disponibile in una cassa gratuita del Poligono di prova
- [x] 3.7 **Il campus di Monte Sant'Arcangelo** (8 novembre 2026), mappa grande in greybox ispirata a Monte Sant'Angelo con i nomi storpiati (circa 230 × 180 m, scheda in [docs/mappa/campus.md](docs/mappa/campus.md)):
  - si parte nell'aula studio sotterranea (lavagna bianca su tutta la parete sinistra guardando l'uscita) e si sale con le scale ai Centri comuni;
  - 11 zone (viale con passerella, mensa, aulario con 8 aule, biblioteca con soppalco, torre di 12 m con il tetto, parcheggio con la stazione, laboratori segreti sotto il parcheggio) che si aprono comprando 12 porte, da 250 a 1.500 €, come in Black Ops 2;
  - le zone sono anche i chunk: gli zombie escono solo vicino ai giocatori, quelli rimasti lontani tornano in coda, e in rete ognuno riceve solo gli zombie vicini al suo giocatore;
  - il menu fa giocare nel campus; il Complesso resta per i test.
  - Da regolare giocando: prezzi, dimensioni, punti di comparsa, tempi per attraversarla
- [x] 3.8 **Fine della run: l'elicottero** sul tetto della torre (provvisorio, per provare):
  - alla radio dell'esercito, vicino alla botola, chiunque versa soldi nella cassa comune, 500 € alla volta, fino a 5.000 €;
  - chiamato, si resiste 60 secondi (l'HUD conta alla rovescia accanto all'ondata); negli ultimi 8 scende sull'eliporto;
  - atterrato si sale con E (solo chi è in piedi): si resta seduti, non si spara e gli zombie lo ignorano. Dal primo che sale ci sono 20 secondi per gli altri; se salgono tutti quelli in piedi parte subito;
  - ripartito, la run è vinta: riepilogo con chi si è salvato, ondata, uccisioni e tempo, poi dopo 15 secondi si riparte da capo; tutto deciso dall'host, anche per chi entra dopo
  - Da regolare giocando: prezzo, tempi, quanto si versa alla volta
- [x] 3.9 **Armi bianche nel terzo slot** (tasto 3, poi click sinistro; F resta il pugno), definite come dati (`MeleeWeaponData`, `game/weapons/melee/`):
  - **Martello da fabbro** 250 €: 45 di danno ogni 0,45 s, spinge, stacca un pezzo dei muri distruttibili, è un martello (serve al passo 3.10);
  - **Katana** 600 €: 75 ogni 0,4 s a tutti gli zombie davanti (fino a 6, arco largo), quasi senza spinta;
  - **Martellone** 900 €: 130 ogni 1,1 s, scaraventa come la Mano pesante (35 a chi colpisce in volo), sfonda i muri;
  - si comprano al muro (martello nei Centri comuni, katana in biblioteca, martellone nei laboratori) e escono dalle casse del campus nel 12% dei casi; se ne tiene una, quella vecchia resta a terra; si perdono alla ripartenza;
  - il colpo lo calcola l'host (bersagli, danni, spinte, muri), come per il pugno; modelli in prima persona in greybox con l'animazione del colpo (dall'alto per i martelli, di taglio per la katana)
  - Da regolare giocando: numeri, prezzi, dove stanno; gli altri giocatori non vedono ancora l'arma in mano
- [x] 3.10 **Proiettili da carro armato** (`tank_shell_pickup.gd`, `shell_rack.gd`, `FpsController.host_fire_shell`):
  - 5 casse dell'esercito col proiettile (3 nei laboratori, 2 vicino ai camion del parcheggio), gratis; il proiettile ricompare dopo 90 s;
  - in spalla: mani occupate (niente armi da fuoco né arma bianca, il pugno sì), velocità all'85%, lo vedono gli altri sul modello; G lo posa a terra (resta 2 minuti) e si può riprendere; chi va a terra o sale sull'elicottero lo lascia;
  - **la combo:** una martellata (martello o martellone) di un compagno a chi lo porta lo fa partire a razzo dalla spalla, dove guarda chi lo porta: 250 di danno diretto, esplosione di 6 m da 350 che spinge gli zombie e sfonda i muri; chi lo portava riceve un contraccolpo all'indietro. La katana non lo fa partire, e ai compagni non fa danni;
  - tutto deciso dall'host; gli altri vedono una copia del razzo
  - Da regolare giocando: danni, raggio, velocità, quanti proiettili e dove; da soli non si può usare (serve un compagno col martello)
- [ ] 3.11 Playtest della run completa

### Fase 4: Personaggi (~40–60 ore per i primi 2)
- [ ] Sistema classi: 4 slot abilità (primaria, secondaria, utilità, speciale) + passiva
- [ ] Personaggi definiti come dati (statistiche, abilità, modelli)
- [ ] Personaggio 1 e 2 giocabili e bilanciati in greybox
- [ ] Selezione personaggio nella lobby

### Fase 5: Pipeline artistica (~80–150 ore, in parallelo dalla Fase 3)
- [ ] Shader di stile: flat shading, nebbia a gradiente, rim light, outline leggero (opzionale)
- [ ] Workflow: **tuo disegno → modello low-poly in Blender (via MCP) → export glTF → Godot**
- [ ] Convenzioni: scala (1 unità = 1 m), pivot, nomi, numero di poligoni
- [ ] Primi asset: oggetti di scena e ambiente, poi armi, poi nemici, poi personaggi
- [ ] Modelli in prima persona (braccia + arma) **e** in terza persona (gli altri giocatori ti vedono)
- [ ] Animazioni: idle, corsa, salto, sparo, morte

### 🎯 Milestone: Vertical Slice
Una run completa e "vera" da giocare con gli amici:
**1 livello rifinito · 2 personaggi · 4–5 nemici + 1 boss · ~15 oggetti · co-op online a 4 · grafica definitiva su tutto ciò che si vede.**
È il momento giusto per decidere se e come continuare (demo, Steam page, playtest esterni).

### Fase 6: Contenuti (la parte più lunga)
- [ ] 4+ personaggi
- [ ] 4–5 ambientazioni/livelli + livello finale
- [ ] 10–15 tipi di nemici, 3–4 boss
- [ ] 50+ oggetti (comuni, rari, leggendari, oggetti attivi)
- [ ] Eventi e varianti per la rigiocabilità

### Fase 7: Meta-progressione, UI, audio
- [ ] Sblocchi tra una run e l'altra (personaggi, oggetti, skin)
- [ ] Menu, HUD definitivo, impostazioni (grafica, audio, sensibilità, rimappatura tasti)
- [ ] Effetti sonori, musica, mix
- [ ] Salvataggi

### Fase 8: Rifinitura e uscita
- [ ] Ottimizzazione (LOD, pooling di nemici e proiettili, profilazione di rete)
- [ ] Playtest esterni, bilanciamento
- [ ] Pagina Steam, demo, Early Access (opzionale)

---

## Come lavoriamo insieme

**Io (Claude):**
- Scrivo il codice e le scene di Godot, struttura del progetto, sistemi di gioco, rete, shader
- Modello in Blender tramite MCP: bozze greybox, oggetti di scena, ambienti, armi, nemici low-poly partendo dai tuoi disegni
- Tengo aggiornata questa roadmap

**Tu:**
- Disegni di riferimento e decisioni creative (cosa è divertente, cosa no)
- Avvii il gioco e lo provi: io non posso giocarlo in tempo reale, quindi il tuo feedback è il vero test
- Rifinisci a mano in Blender quando serve (soprattutto rigging e animazioni dei personaggi, dove l'MCP rende meno)

**I disegni più utili da mandarmi:**
- Personaggi: **turnaround** (fronte, lato, retro), con colori e proporzioni chiare
- Armi: vista laterale pulita
- Nemici: silhouette + una vista frontale
- Ambienti: schizzi d'atmosfera + una palette di colori per ogni livello
- Più semplici e "leggibili" sono le forme, meglio rendono in low-poly

**Ritmo:** una sessione = un obiettivo concreto e verificabile (es. "il controller FPS salta e spara"). A fine sessione si fa un commit su Git.

**Pronti per un team:** struttura per funzionalità e convenzioni scritte nel [README](README.md). Se entra qualcuno, si aggiungono GitHub Issues/Projects per i compiti e Git LFS per i file pesanti (`.blend`, audio).

---

## Prossimi passi immediati
1. ~~Struttura del progetto in `C:\Dev\Project-Zombie`~~ ✅
2. Installare **Godot 4** (versione standard, non .NET) e aprire il progetto con *Import*
3. Installare **Blender** con il server MCP (serve dalla Fase 5, ma utile già per le bozze)
4. ~~Controller FPS e livello di prova (inizio Fase 1)~~ ✅
