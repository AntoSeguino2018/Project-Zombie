# Personaggio N.1

Primo personaggio giocabile. Bozza a penna: `blender/Peronaggio_N1_bozza.jpeg` (vista frontale, testa di profilo, braccio robotico di lato, mano robotica).

## Riferimenti

In `blender/personaggi/riferimenti/`. La cartella è solo locale ed esclusa da git, perché contiene immagini di terzi e la foto di una persona reale.
- `stile_poligonale.png`: lo **stile** da seguire. Superfici a facce grandi e piatte, forme massicce, materiali leggibili.
- `anatomia.png`: l'**anatomia** del corpo, per quanto stilizzata. Contiene i gruppi muscolari di fronte e da dietro.
- `capelli_mullet.png`: il **taglio**. Sopra corti, ricci e scompigliati che ricadono in avanti; lati sfumati sopra e dietro l'orecchio; dietro mullet mosso fino alla base del collo.
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

## Fasi

Ogni fase si chiude con le immagini di fronte, di lato e di tre quarti, e con l'approvazione prima di passare alla successiva.

0. **Preparazione:** file `blender/personaggi/personaggio_n1.blend`, bozza come immagine di riferimento, guida d'altezza a 1,72 m.
1. **Sagoma:** tutto il corpo con forme semplici, per fissare le proporzioni e controllarle con la capsula del giocatore in Godot.
2. **Braccia robotiche:** spallacci, punte, bulloni e mani.
3. **Busto e gambe:** maglia, cintura, cargo, scarponi.
4. **Testa:** viso con l'ombra al posto degli occhi, collo e collana. I capelli restano i blocchi provvisori.
5. **Capelli e pelliccia, per ultimi:** con un aspetto più realistico del resto del modello, quindi con una tecnica diversa, da decidere in quella fase.
6. **Colori:** materiali piatti.
7. **Scheletro e animazioni:** ferma, camminata, corsa, salto, a terra (downed), rianimazione.
8. **In Godot:** modello visto dagli altri giocatori in co-op, braccia in prima persona sulla camera.

## Blender

**File:** `blender/personaggi/personaggio_n1.blend`.
- Collezione `Riferimenti`: le due bozze (`Bozza_Fronte`, `Bozza_Profilo`) come immagini in scala, visibili solo nelle viste frontale e laterale, più la `CameraVerifica`.
- Collezione `Sagoma`: la sagoma a forme semplici, 51 pezzi.

**Convenzioni:**
- Piedi sull'origine, Z in alto.
- Il personaggio guarda **-Y**, quindi il suo lato sinistro è +X e i pezzi si chiamano `.L`/`.R`.
- In Godot andrà ruotato di 180° oppure gestito all'import.
- **A-pose:** braccia aperte a 45° dalla verticale, non lungo i fianchi come nella bozza. È la posa che facilita scheletro e pesi.

**Scala della bozza:** 1,72 m / 967 px, cioè 1,78 mm per pixel. Riferimenti presi sulla bozza: punta dei capelli al pixel 608, suola al pixel 1575, linea centrale x 340.

**Quote ricavate:**
- occhi 1,60 m, uguali alla camera del gioco (`Head` a 1,6 m, capsula 1,8 m);
- mento 1,47 m;
- spalla 1,37 m;
- cintura 0,935–0,995 m;
- ginocchio 0,48 m;
- risvolti 0,15–0,24 m.

**Strumenti nel file:** il testo `lib_personaggio.py` (editor di testo di Blender) contiene le funzioni di modellazione e la funzione `look` per i render di verifica. Si richiama con `exec(bpy.data.texts["lib_personaggio.py"].as_string())`. Funzioni:
- `cyl`, `box`, `seg_box`, `dome`, `fur_ring`: forme di base;
- `ring_pts`, `loft`, `profile_loft`: sezioni raccordate;
- `sculpt_loft`, `displace`, `smoothstep`: forma scolpita (busto, testa);
- `poly`, `capsule`, `face_shell2`: lamine proiettate sul viso (barba, bocca);
- `strand`, `ribbon`, `keep_out`, `bvh_of`: ciocche di capelli e pelliccia;
- `make`: crea l'oggetto, con specchiatura, smusso e spessore;
- `tris`: conta i triangoli finali.

**Braccia (collezione `Braccia`):**
- Ogni braccio è figlio di un vuoto `Radice.L`/`.R` posto sulla spalla (±0,20, 0, 1,37) e ruotato di 45° (A-pose).
- I pezzi sono modellati nello "spazio del braccio": spalla nell'origine, braccio verso -Z, esterno +X, davanti -Y. Il destro è lo specchio del sinistro.
- Pezzi: `Spalla`, `Spallaccio`, `Borchie`, `Omero`, `Gomito`, `Avambraccio`, `Polsino`, `Mano`, `Dita`. La pelliccia è accantonata, vedi Stato.
- **Sono pezzi rigidi:** nello scheletro ogni pezzo andrà al 100% su un osso (omero, avambraccio, mano, falangi), senza deformazioni.
- Materiali:
  - `Acciaio` (chiaro) per il corpo del braccio e lo spallaccio;
  - `MetalloScuro` per bulloni, punte, giunti, fascia e polsino.
- Smusso degli spigoli solo oltre i 65°, niente smusso sulle dita.
- Circa 3.900 triangoli per le due braccia.

**Tecnica "scolpita e sfaccettata" (busto e testa):** è quella che dà l'aspetto del riferimento di stile.
1. `sculpt_loft` costruisce una forma di base liscia e fitta (anelli ogni 3–4 mm, 96–128 lati).
2. `displace` sposta ogni vertice in fuori o in dentro con una funzione che somma i muscoli (o i tratti del viso) come rilievi morbidi.
3. Un modificatore **Decimate** simmetrico (`Faccette`) riduce tutto a poche facce grandi.

Per cambiare un muscolo si cambia un numero nella funzione e si rigenera; il Decimate non va applicato finché non si fa lo scheletro.

**Corpo (collezione `Corpo`):** gambe, cintura e scarponi sono costruiti per sezioni raccordate (`ring_pts` + `loft` nella libreria).
- `Busto`: maglia nera attillata, anatomia di `anatomia.png`, circa 1.400 triangoli dopo il Decimate.
  - Davanti: pettorali a piastra con il bordo basso netto che sale verso l'ascella, solco dello sterno, addominali a due colonne, obliqui e dentato sui fianchi, clavicole.
  - Dietro: dorsali larghi a V, scapole, trapezio a rombo dalla nuca a metà schiena, erettori con il solco della colonna.
  - **Collo:** come nella bozza del viso, largo (circa 13 cm, quasi quanto la mandibola) e corto. Parte da sotto le orecchie e si raccorda ai trapezi pieni. Ha due muscoli appena accennati verso lo sterno e l'incavo dello sterno. Un collo sottile e lungo lascia troppo spazio tra mento e petto.
  - **Scollo girocollo** (`neckline` nel codice): basso davanti (1,443 m), alto dietro (1,488 m); sopra è pelle. `Girocollo` è un bordino che segue la superficie reale del busto e copre il bordo seghettato della maglia.
  - Evitare la forma "ad ampolla", cioè fianchi curvi e spalle tonde che si stringono di colpo.
- `Bacino`: parte alta dei cargo, la maglia ci entra dentro. Il fondo è alto (0,80 m): sotto, i cargo larghi si toccano in mezzo.
- `Cintura`: fascia di cuoio, passanti, fibbia d'acciaio con la "C" in rilievo scuro.
- `Gamba.L`/`.R`:
  - cargo larghi con pieghe (raggio modulato a 5 onde che ruotano scendendo);
  - tasca con patta e bottone sul lato esterno della coscia.
- `Risvolto.L`/`.R`: fondo dei cargo raccolto a pieghe verticali dentro lo scarpone.
- `Scarpone.L`/`.R`:
  - tomaia nera, puntale e contrafforte del tallone marroni;
  - suola marrone spessa e quattro lacci;
  - punta ruotata di 8° verso l'esterno.
- Circa 2.800 triangoli per tutto il corpo. Con braccia e testa provvisoria il modello visibile è a circa 6.500.

**Testa (collezione `Testa`):** `Testa` è fatta con la stessa tecnica scolpita e sfaccettata, circa 800 triangoli.
- **Rifatta da zero sulla bozza del viso.** Tutta la testa (con orecchie, barba e capelli) è **1 cm più in basso** di prima (`DZ = -0,010` nel codice), così il collo è più corto. Gli occhi sono a circa 1,59 m, la camera del gioco a 1,60.
- **Misure:** larga 13,8 cm al cranio, il viso si stringe verso il mento; da 1,474 m a 1,683 m. Sezioni squadrate (superellisse p 3).
- **Viso:**
  - arcata sopraccigliare a tettoia, con sotto la **fascia d'ombra degli occhi** (materiale `Ombra`);
  - zigomi, naso lungo e dritto con la punta piccola, bocca;
  - mento largo, angolo della mandibola.
  - **Attenzione alla bozza:** il tratteggio sotto la bocca è la barba e la sua ombra, non il mento.
- `Orecchie`: sagoma a C estrusa e inclinata, con la conca sul materiale `PelleOmbra`.
- **Carnagione mediterranea:** `Pelle` (0,60, 0,36, 0,23).
- **Barba (`Barba`, materiale `Barbetta`):** corta, come nella bozza: baffi collegati agli angoli della bocca a un pizzetto pieno che copre il mento.
  - È una lamina di 1,5–2 mm costruita da `face_shell2` con `poly`, poi ridotta a faccette dal Decimate.
  - **Se cambia la `Testa`, va rigenerata.**
- **Bocca (`Bocca`, materiale `PelleScura`):** una linea scura, stessa tecnica.
**Capelli e pelliccia a blocchi sfaccettati**

Sono solidi, nello stesso stile del resto del modello, e senza texture trasparenti. Le ciocche a texture della prima versione sono state abbandonate; i file in `blender/personaggi/tex/` e i materiali `CapelliCiocche`/`PellicciaCiocche` non sono più usati.

- **Ciuffo (`tuft` nella libreria):** solido a sezione di rombo che segue una guida (`strand`) e si stringe fino a una punta. `taper` regola quanto presto si assottiglia.
- **Cuoio capelluto (materiali sulla `Testa`):**
  - `CapelliBase` sopra e sulla nuca;
  - `Rasato` (ricrescita scura, come il tratteggio della bozza) sui lati;
  - sotto è pelle.
- **`MassaCapelli`:** calotta piena sopra la testa, con bozze irregolari.
  - È costruita per raggi dal centro della testa (`hit_dir`, `phi_for_z`, `cap_mesh` nel codice della sessione), con spessore fino a 1,8 cm.
  - Attaccatura a 1,64 m, più bassa dietro; Decimate a faccette.
- **`Capelli`:** circa 50 ciuffi:
  - la **frangia** che ricade sulla fronte con la punta che si alza;
  - i **ciuffi scompigliati** che escono dalla calotta;
  - due **ciuffi dietro ogni orecchio**, come nella bozza.
- **`MassaMullet`:** 11 ciocche larghe e piatte sulla nuca.
  - Lunghezze diverse e spessori alternati, così si leggono separate.
  - Scendono fino alla base del collo e finiscono a punta all'indietro.
- **`Pelliccia` (collezione `Corpo`, un solo oggetto, materiale `PellicciaPiena`):**
  - due anelli a bozze centrati sull'attacco delle braccia (±0,195, 0, 1,365 m), con l'asse lungo il braccio, quindi passano sotto l'ascella; circa 56 ciuffi a punta per anello;
  - il **cappuccio abbassato**: una lastra che segue la schiena dal collo (1,48 m) alle scapole, con il bordo basso a U fino a 1,22 m al centro;
  - il cappuccio è più spesso attorno al collo (l'apertura) e ha un rotolo grosso sul bordo, con una frangia di ciuffi;
  - circa 4.300 triangoli in tutto.
  - **Nello scheletro** gli anelli andranno pesati tra busto e parte alta del braccio.
- **Rigenerazione:** seed fissi. Se cambiano testa o busto, capelli, barba, pelliccia e collana vanno rigenerati.

**Collana (collezione `Corpo`):**
- `Collana`: catenina a sezione triangolare. Gira alla base del collo, sulla pelle, appena sopra lo scollo, e scende sullo sterno. È appoggiata alla superficie del `Busto` con un ray-cast radiale e tenuta fuori dal `Girocollo`.
- `Targhetta`: rettangolo d'acciaio con l'anellino, dritto sullo sterno a circa 1,35 m, inclinato di 12° come il petto.
- **Se si cambia la forma del busto, la collana va rigenerata.**

**Verifica:** render ortogonale con la stessa scala della bozza, sovrapposto al disegno con numpy. Il codice è nella cronologia della sessione e si rifà in pochi minuti.

## Stato

- (3 novembre 2026) **Fasi 0 e 1 fatte**, sagoma in attesa di approvazione.
- Correzioni già fatte dopo il primo confronto:
  - cargo allargati: circa 25 cm di gamba al ginocchio, come nella bozza;
  - anelli di pelliccia ingranditi e portati sopra le spalle.

- (3 novembre 2026) **Fase 2 fatta (braccia robotiche)**, in attesa di approvazione.
  - **Interpretazione della bozza:** l'anello di pelliccia è un colletto attorno all'attaccatura del braccio, con lo spallaccio che spunta dal centro, come nella vista laterale. Non è un anello attorno al braccio.
  - Corretti dopo i primi render: pollice staccato dal palmo; triangoli scesi da 6.400 a 3.900.
- (3 novembre 2026) **Braccia approvate.** La pelliccia è tolta per scelta: si rifà nella fase 5 insieme ai capelli.
  - I due colletti a ciuffi (`Pelliccia.L`/`.R`, ancora figli delle radici delle braccia) sono nella collezione `Accantonati`, esclusa dalla scena. Restano solo come riferimento di posizione.

- (3 novembre 2026) **Fase 3 fatta (busto e gambe)**, in attesa di approvazione. Corretti dopo i render:
  - busto piatto di lato: ora ha il petto in avanti;
  - cavallo dei cargo troppo basso, faceva un rigonfiamento a "V";
  - gambale dello scarpone che bucava le pieghe del risvolto;
  - bordo del tallone frastagliato.
- (3 novembre 2026) Busto rifatto su richiesta: più spessore sulla schiena, trapezi più alti, meno forma "ad ampolla".
- (3 novembre 2026) Seconda revisione: trapezi ridimensionati (erano esagerati), clavicole delineate, collo vero integrato nel busto, girocollo.

- (3 novembre 2026) **Fase 4 fatta (testa e collana)**, in attesa di approvazione. Decisioni:
  - baffi e pizzetto si fanno realistici nella fase 5, insieme a capelli e pelliccia;
  - carnagione mediterranea.

  Corretti dopo i render:
  - mento a punta, ora squadrato;
  - ombra degli occhi che sembrava una benda;
  - collana che bucava la maglia.

  Il modello visibile è a circa 7.900 triangoli.
- (3 novembre 2026) Revisione della testa su richiesta. Il mento era esagerato perché avevo letto come mento il tratteggio della barba: ora è più piccolo e alto, e la mandibola risale verso l'orecchio. Baffi e pizzetto sono modellati sul viso al posto dei blocchi. Modello visibile a circa 9.200 triangoli.

- (3 novembre 2026) **Fase 5 fatta (capelli, barba e pelliccia)**, in attesa di approvazione. Decisioni:
  - pelliccia marrone scuro;
  - ciocche anche su baffi e pizzetto.

  Corretti dopo i render:
  - cresta da punk a spuntoni, ora pettinata all'indietro;
  - mullet troppo lungo, scendeva fino alle spalle;
  - attacco del mullet a parrucca;
  - ali laterali;
  - colori troppo chiari.

  **Modello visibile: circa 14.900 triangoli, al limite del budget.**

- (3 novembre 2026) **Revisione con i riferimenti** (stile, anatomia, taglio), in attesa di approvazione:
  - busto rifatto con l'anatomia del riferimento e la tecnica sfaccettata;
  - collo sottile e anatomico, scollo girocollo, collana e targhetta appoggiate;
  - testa più piccola (13,4 cm) e squadrata, viso sfaccettato;
  - barba solo accennata;
  - capelli come la foto;
  - pelliccia spostata sul busto attorno all'attacco delle braccia, molto più folta.

  Corretti dopo i render:
  - ciocche che scivolavano sul viso e sulle orecchie;
  - mullet a "tenda";
  - orecchie a disco scuro;
  - ciocche di pelliccia stirate lungo il braccio;
  - collo nascosto dal colletto alto;
  - targhetta di taglio.

  **Modello visibile: circa 16.500 triangoli.** Braccia 3.560, corpo con pelliccia 7.840, testa con capelli 5.160.

- (3 novembre 2026) **Revisione sulla bozza del viso**, in attesa di approvazione:
  - collo largo e corto e testa abbassata di 1 cm, per non lasciare troppo spazio tra mento e petto;
  - viso rifatto da zero sulla bozza;
  - barba corta collegata;
  - capelli e pelliccia rifatti a blocchi sfaccettati;
  - pelliccia ad anelli sotto le ascelle, con il cappuccio abbassato sulla schiena.

  Corretti dopo i render:
  - viso a "mattone", ora si stringe verso il mento;
  - attaccatura a punta sulla fronte;
  - lati rasati che arrivavano agli occhi;
  - ciuffi troppo sottili, che sembravano spuntoni;
  - mullet a lastra;
  - anelli di pelliccia troppo sottili.

  **Modello visibile: circa 15.700 triangoli.** Braccia 3.560, corpo con pelliccia 8.710, testa con capelli 3.460.

## Problemi aperti

- **Budget dei triangoli:** circa 15.700, poco sopra l'indicativo di 15.000. La pelliccia da sola vale circa 4.300; se serve, si tolgono un terzo dei ciuffi (circa 1.000 triangoli).
- **Gambe e braccia non toccate dalle revisioni:**
  - le gambe sono coperte dai cargo larghi;
  - le braccia sono robotiche.

  Se si vuole lo stesso aspetto sfaccettato anche su cargo e scarponi, si può applicare la stessa tecnica.
- **Scollo:** ai lati del collo resta qualche piccola fessura di pelle tra maglia e `Girocollo`, visibile solo da vicino.
- **Raccordo mandibola-collo:** il collo entra nella testa; se di lato si nota, si unisce la mesh della testa al busto prima dello scheletro.
