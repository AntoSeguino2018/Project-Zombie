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
- [x] 3.1 **Armi trovabili:** pistola di partenza, fucile a pompa e mitraglietta oltre a carabina e lanciagranate; tratti casuali che cambiano numeri e nome (rapida, pesante, precisa, caricatore esteso, ricarica lampo); trucchi che rendono l'arma *truccata* (rimbalzante, perforante, esplosiva, incendiaria, doppia canna); casse che si aprono con E e si riempiono dopo 30 s; due armi in mano e scambio con quella in mano, che resta a terra; tutto deciso dall'host *(le sbroccate arriveranno con le idee del gruppo)*
- [ ] 3.2 **Ondate:** budget di pericolosità che sale, costo per tipo di zombie, composizione diversa a ogni ondata, spawn fuori vista; sostituisce gli spawner provvisori
- [ ] 3.3 Giocatore a terra → rianimazione da parte dei compagni; run persa se cadono tutti
- [ ] 3.4 Soldi personali dagli zombie, macchinette del caffè (boost), casse a pagamento
- [ ] 3.5 Oggetti passivi **impilabili**, definiti come dati (ogni oggetto è una risorsa con i suoi parametri)
- [ ] 3.6 Mappa grande in greybox, con zone, casse e macchinette
- [ ] 3.7 Fine run e schermata con le statistiche
- [ ] 3.8 Playtest della run completa

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
