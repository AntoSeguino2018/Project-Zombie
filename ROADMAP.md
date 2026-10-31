# Roadmap: Project Zombie (nome provvisorio)

Obiettivo: FPS roguelike in prima persona, grafica low-poly colorata e stilizzata, più personaggi giocabili, co-op online fino a 4 giocatori.

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
| Stile grafico | Low-poly, flat shading, texture a palette (atlante di colori), nebbia colorata, illuminazione morbida | Ispirato al genere ma con identità **originale**: personaggi, mondo e meccaniche nostre. |
| Versioning | **Git + GitHub** (repo privato) | Backup e storico di ogni modifica. |

> Il progetto vive in `C:\Dev\Project-Zombie`, fuori da OneDrive (la sincronizzazione blocca o corrompe i file di Godot e Git). Il backup sarà GitHub.

**Regola d'oro:** il multiplayer si costruisce **dall'inizio**. Aggiungerlo a un gioco nato single-player vuol dire riscriverlo quasi tutto.

---

## Fasi

### Fase 0: Pre-produzione (~10–15 ore)
- [ ] Mini documento di design (1–2 pagine): ambientazione, tono, nome provvisorio
- [ ] Core loop in una frase (es. *"entri nel livello → uccidi → raccogli valuta → apri casse/oggetti → completi l'obiettivo → livello successivo, più difficile"*)
- [ ] Prima bozza di 2 personaggi (concept: silhouette, arma, ruolo)
- [ ] Palette colori e moodboard di riferimento (i tuoi disegni)
- [x] Cartella di progetto, repo Git locale, struttura Godot
- [ ] Installare Godot 4 e Blender + MCP
- [ ] Repo GitHub privato per il backup

### Fase 1: Prototipo FPS in greybox (~30–50 ore)
Tutto con cubi e capsule, zero grafica definitiva.
- [x] 1.1 Controller FPS base: movimento, salto, sprint, mouse look, gravità + livello di prova in greybox
- [ ] 1.2 Sensazione del movimento: accelerazione/attrito, coyote time, jump buffer, FOV nello sprint, head bob *(rimandato a quando ci saranno nemici)*
- [x] 1.3 Prima arma: sparo hitscan, cadenza, dispersione, rinculo, mirino, scia e impatti, arma in prima persona
- [x] 1.4 Salute e danno: componente vita unico, manichini bersaglio, numeri di danno, hitmarker
- [ ] 1.5 Primo nemico (insegue e attacca) con navigazione (NavigationMesh), morte e respawn del giocatore
- [ ] 1.6 Proiettili fisici
- [ ] 1.7 HUD minimo e playtest
- **Verifica:** il gioco è già divertente per 2 minuti con i cubi? Se no, si sistema qui.

### Fase 2: Fondamenta di rete (~50–80 ore)
- [ ] Host / join via IP, fino a 4 giocatori
- [ ] Sincronizzazione giocatori (movimento con interpolazione e previsione locale)
- [ ] Sparo e danno validati dall'host
- [ ] Nemici simulati solo dall'host e replicati ai client
- [ ] Test con 4 istanze sul tuo PC, poi con amici su internet
- [ ] Integrazione Steam (lobby, inviti, relay)

### Fase 3: Core loop roguelike (~60–100 ore)
- [ ] Struttura della run: livello → obiettivo → livello successivo → fine run
- [ ] **Director** degli spawn: crediti che crescono nel tempo, il director "compra" nemici
- [ ] Difficoltà che sale col tempo (incentivo a non perdere tempo)
- [ ] Valuta, casse/terminali, oggetti passivi **impilabili** (stack)
- [ ] Sistema oggetti data-driven (ogni oggetto è una risorsa con i suoi parametri)
- [ ] Giocatore a terra → rianimazione da parte dei compagni
- [ ] Schermata di fine run (statistiche)
- [ ] Generazione livelli: arena fatta a mano + spawn casuali di casse/nemici/obiettivi (più semplice e controllabile del procedurale puro)

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
