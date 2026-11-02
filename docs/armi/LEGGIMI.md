# Schede delle armi

Una scheda per ogni arma creata, a partire dalla Magnum. Ogni scheda raccoglie dati e peculiarità e **tutti i difetti da correggere**, soprattutto di modello e animazione.

| Arma | Rarità | Modello | Scheda |
|---|---|---|---|
| Magnum | sbroccata | vero (Blender) | [magnum.md](magnum.md) |

Le armi di base (pistola, carabina, fucile a pompa, mitraglietta, lanciagranate) sono ancora fatte di cubetti e non hanno una scheda; la avranno quando arriverà il loro modello vero.

## Come è fatta una scheda

1. **Danni e peculiarità:**
   - riassunto in tre o quattro punti;
   - tabella dei numeri (dal `.tres`);
   - comportamento in gioco: chi decide il danno, cosa attraversa, interazioni con oggetti, boost e tratti, contro quali zombie funziona, dove si trova, tasti;
   - effetti visivi particolari.
2. **Blender:**
   - file e dati del modello (dimensioni, origine, triangoli, clip e durate);
   - **tabella dei tempi chiave** delle animazioni usati dal codice;
   - difetti da correggere, numerati;
   - vincoli da rispettare se si modifica il modello;
   - corretti, con la data.
3. **Godot:**
   - file e parametri della scena (scala, posizione, `Muzzle`);
   - come sono collegate le animazioni (velocità, code, costanti);
   - difetti e miglioramenti, numerati;
   - corretti, con la data;
   - verifiche fatte (test e screenshot).

## Regole
- Quando si trova un difetto si aggiunge subito alla scheda, anche se non si corregge.
- Quando si corregge, si sposta in "Corretti" con la data e una riga sul come.
- Se cambiano i tempi o le misure in Blender, si aggiornano insieme tabella, costanti nel codice e test.
- Arma nuova: nuova scheda con questo schema e una riga nella tabella qui sopra.
