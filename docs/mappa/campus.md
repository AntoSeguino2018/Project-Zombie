# Mappa: il campus di Monte Sant'Arcangelo

Il campus dell'"Università Federico III", ispirato al complesso di Monte Sant'Angelo della Federico II, con i nomi storpiati. È la mappa del gioco dal passo 3.7 (8 novembre 2026), in greybox.

- **Scena:** `game/levels/campus.tscn`, generata da `tools/build_campus.py`.
  - Si rigenera con `python tools/build_campus.py`.
  - Lo script riscrive la scena da zero: le modifiche fatte a mano nell'editor vanno riportate nello script.
- **Codice:** `game/levels/zones/`
  - `MapZone`: una zona;
  - `ZoneManager`: le zone e quali sono aperte;
  - `ZoneDoor`: porta a pagamento.
- **Test:** `tests/test_39.gd` (da solo), `tests/net_campus.gd` (in rete).

## Pianta

Assi: X verso est, Z verso sud (nord = -Z). Misure in metri, terreno a quota 0.

| Zona (nodo) | Dove | Com'è | Si apre |
|---|---|---|---|
| Aula studio (`aula`) | X -10…10, Z 62…90, quota -6 | partenza sottoterra, pareti gialle, tavoli; la lavagna bianca occupa tutta la parete sinistra guardando l'uscita (27 m); due prese d'aria da cui entrano gli zombie; scala verso i Centri comuni | aperta |
| Centri comuni (`centri`) | X -30…30, Z 12…60 | atrio con pilastri, bancone, la scala che scende all'aula | aperta |
| Viale (`viale_ovest`, `viale_est`) | X -115…115, Z -12…12 | il viale che collega tutto, con la passerella sopraelevata a 4 m (X -60…60) e due scale | 250 € |
| Mensa e bar (`mensa`) | X -115…-30, Z 12…60 | tavoli, bancone, le tre macchinette insieme | 300 € |
| Aulario (`aulario`) | X -115…-35, Z -85…-12 | corridoio con otto aule (A1–A8), banchi e lavagne | 400 € |
| Biblioteca (`biblioteca`) | X -35…35, Z -85…-12 | file di scaffali, tavoli, soppalco a 4 m con due scale | 400 € |
| Torre dei dipartimenti (`torre`) | X 35…115, Z -85…-12 | piazzale ed edificio di 40 × 40 m alto 12 m, scale interne | 750 € |
| Tetto (`tetto`) | sopra la torre, quota 12 | eliporto con l'elicottero e la radio dell'esercito vicino alla botola | 1.500 € (porta sul pianerottolo a 6 m) |
| Parcheggio e stazione (`parcheggio`) | X 30…115, Z 12…88 | auto, due camion dell'esercito, la stazione "Monte Sant'Arcangelo" (tornelli chiusi), la rampa dei laboratori | 600 € |
| Laboratori segreti (`laboratori`) | X 50…110, Z 36…80, quota -7 | sotto il parcheggio: il progetto segreto, banconi, casse dell'esercito | 1.000 € (saracinesca in cima alla rampa) |

**Porte** (12), nella lista `doors` di `tools/build_campus.py`:

| Porta | Prezzo | Apre |
|---|---|---|
| Centri → Viale | 250 € | tutto il viale |
| Centri → Mensa, Viale → Mensa | 300 € | mensa |
| Viale → Aulario | 400 € | aulario |
| Viale → Biblioteca | 400 € | biblioteca |
| Aulario ↔ Biblioteca | 400 € | entrambe |
| Viale → Torre | 750 € | torre |
| Biblioteca ↔ Torre | 750 € | entrambe |
| Centri → Parcheggio, Viale → Parcheggio | 600 € | parcheggio |
| Parcheggio → Laboratori | 1.000 € | laboratori |
| Pianerottolo → Tetto | 1.500 € | tetto |

I prezzi sono provvisori. Per riferimento: una cassa costa 100 €, un'ondata superata dà 25 + 5 × numero dell'ondata, e una uccisione da 10 a 60 €.

Altro: 9 casse (una per zona, tranne il tetto), 10 macchinette, 40 punti di comparsa (almeno 2 per zona), 4 muretti distruttibili.

## Porte a pagamento

Una porta (`ZoneDoor`) si compra guardandola e premendo E. La paga chi la apre, come le casse.
- Comprata, si abbassa nel pavimento e smette di bloccare.
- Le zone in `opens` diventano aperte.
- Le porte non comprate restano chiuse anche se la zona è già aperta da un'altra parte.

Chiusa, una porta blocca giocatori, zombie e colpi, ed è un muro anche per la navigazione. Quando si apre, l'host ricalcola la navigazione in background (circa 0,3 s per tutta la mappa), così gli zombie ci passano.

Alla ripartenza della run le porte si richiudono e restano aperte solo l'aula e i Centri comuni.

## L'elicottero (fine della run)

Dal passo 3.8 la run si vince scappando in elicottero dal tetto della torre. È una soluzione provvisoria, per provare.
- **Codice:** `game/levels/props/helicopter.gd`; il nodo `Elicottero` nel campus sta sull'eliporto (80, 12, -55).
- **Chiamata:** alla radio dell'esercito, vicino alla botola, chiunque versa nella cassa comune, 500 € alla volta (o quelli che ha), fino a 5.000 €.
- **Arrivo:** chiamato, si resiste 60 secondi, con il conto alla rovescia sull'HUD accanto all'ondata. Negli ultimi 8 secondi scende sull'eliporto.
- **Imbarco:** atterrato, si sale con E, ma solo chi è in piedi (chi è a terra va rianimato prima).
  - Chi sale resta seduto, non spara e gli zombie lo ignorano.
  - Dal primo che sale ci sono 20 secondi per gli altri; se salgono tutti quelli in piedi parte subito.
- **Fine:** l'elicottero riparte e la run è vinta per chi è a bordo. Il riepilogo mostra chi si è salvato, l'ondata, le uccisioni e il tempo; dopo 15 secondi si riparte da capo, con l'elicottero da richiamare.

I numeri (prezzo, versamento, tempi) sono variabili esportate dell'elicottero, si cambiano nell'editor o in `helicopter.gd`.

## Zone e chunk

Le zone sono anche i "chunk" con cui si divide il lavoro, perché la mappa è grande. Con al massimo 4 giocatori si lavora al massimo su 4 zone (più quelle accanto).

- **Ondate (sull'host):**
  - gli zombie escono solo dai punti delle zone aperte dove c'è un giocatore vivo o accanto;
  - se non ce ne sono, escono da quelli delle zone aperte;
  - uno zombie rimasto fuori da quelle zone e a più di 50 m da tutti per 6 secondi sparisce e torna in coda, e rinasce vicino ai giocatori; il conto dell'ondata non cambia.
- **Rete:**
  - ogni partecipante riceve solo gli zombie della zona del suo giocatore, delle zone accanto e quelli entro 45 m;
  - gli altri non li ha proprio: compaiono quando si avvicinano e spariscono quando si allontanano;
  - l'host ricalcola a chi arriva ogni zombie due volte al secondo;
  - anche i messaggi sulla vita degli zombie vanno solo a chi li ha.
- **Disegno:** tavoli, sedie, scaffali, auto e gli altri oggetti piccoli non si disegnano oltre 70 m; le scritte delle zone oltre 45 m.

Le zone confinanti sono scritte nello script (`neighbors`). Il viale è diviso in due zone (ovest ed est) perché è lungo 230 m.

## Difetti aperti

- La mappa è a cielo aperto tranne aula, laboratori e torre: niente soffitti e luci al neon (Fase 5).
- Gli zombie che ricompaiono su un client, tornando vicini, partono per un attimo dal punto dove erano nati, poi saltano alla posizione vera.
- Chi riceve uno zombie già ferito o in fiamme lo vede con la vita piena e senza fiamme finché non viene colpito di nuovo.
- Le zone sono scatole: un punto sul confine appartiene alla prima zona dell'elenco.
- Non ancora provata giocando: dimensioni, tempi per attraversarla, prezzi.

## Verifiche

- `test_39`:
  - partenza nell'aula, coi piedi a terra;
  - lavagna sulla parete sinistra;
  - scala percorribile;
  - punti di comparsa in zona e sulla navigazione, almeno 2 per zona;
  - porte: soldi, scritta, collisione, navigazione ricalcolata;
  - a porte aperte ogni punto e l'eliporto si raggiungono dall'aula;
  - comparsa solo vicino ai giocatori e zombie lontani rimessi in coda;
  - ripartenza.
- `net_campus`:
  - il client compra una porta (decide l'host, la vedono aperta tutti e due);
  - uno zombie lontano non arriva al client e i suoi danni non gli vengono mandati;
  - quando si avvicina, compare.
- `test_40` (elicottero):
  - versamenti alla radio, chiamata, discesa, atterraggio;
  - imbarco: seduti, ignorati dagli zombie;
  - partenza, vittoria con riepilogo, ripartenza.
- `net_helicopter`:
  - versano host e client, e la cassa si vede uguale;
  - sale prima il client e l'elicottero aspetta l'host, poi partono;
  - vittoria con tutti e due i nomi.
- Foto in Godot da 10 punti di vista e pianta dall'alto (non versionate).
