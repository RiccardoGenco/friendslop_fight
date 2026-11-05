# Piano di miglioramento (v0.8)

Per ogni caratteristica: com'è adesso, cosa migliorare, cosa si fa. Ordine = ordine di lavoro.

| # | Caratteristica | Com'è adesso | Cosa migliorare | Intervento |
|---|---|---|---|---|
| 1 | Movimento | Arco del salto, muro stile Hollow Knight, schiacciamenti, polvere all'atterraggio | Correndo il personaggio "scivola" senza contatto col terreno; girarsi di colpo non si sente | Sbuffi di polvere ai passi, sgommata quando si inverte la corsa, scintille scivolando sul muro |
| 2 | Corpo a corpo | Il colpo attivo è un rettangolo bianco semitrasparente | Non si legge l'arco dell'arma né la sua forza | Scia a mezzaluna (smear) nel colore dell'arma, più ampia e lunga per le armi pesanti, spinta in avanti con la lancia |
| 3 | Armi a distanza | Proiettili disegnati per tipo, scie per cecchino e fantasma | I proiettili base sono rettangoli corti, poco leggibili a velocità alta | Scia luminosa per i proiettili base, alone additivo, bordo del colore dell'arma |
| 4 | Armi a terra | Riquadro del colore del livello, lampeggio prima di sparire | Da lontano non si capisce cosa vale la pena prendere | Fascio di luce verticale per armi Potenti e Mitiche, piedistallo luminoso, nome dell'arma quando ci si avvicina, scintille sulle mitiche |
| 5 | Mappe | 4 mappe statiche, solo spuntoni e lava finale | L'idea di partenza era una mappa che interagisce coi giocatori | Eventi di mappa ogni 12-18 s, sempre annunciati: massi nell'Arena, barili esplosivi in Fabbrica, fulmini sui Tetti |
| 6 | Morte improvvisa (lava) | Rettangolo arancione con onda | Poco minacciosa, nessun avviso visivo forte | Lava a strati con bolle e bagliore, calore sopra la superficie, bordo rosso a schermo durante l'avviso |
| 7 | HUD | Quadratino colore + pallini vittorie + nome arma | Non si capisce chi è chi né quanta vita ha | Schede per giocatore con faccia dell'eroe, vita, vittorie e arma; teschio per chi è eliminato |
| 8 | Annunci di round | Testo su fascia scura | Statici, niente ritmo | Conto alla rovescia che "salta" con tic sonori, VIA! che esplode, vincitore del round con l'eroe in primo piano |
| 9 | Fine partita | Elenco nomi e punteggi | Poca soddisfazione per chi vince | Podio con gli eroi, statistiche (eliminazioni, morti), monete guadagnate, coriandoli |
| 10 | Pausa | Testo su schermo scuro, Q per la lobby | Niente menu, niente mouse | Menu di pausa: Riprendi, Impostazioni rapide (volumi), Torna alla lobby, Menu principale |
| 11 | Bot | Un livello solo, prevedibili | Da soli ci si annoia presto o si perde sempre | Tre livelli (facile, normale, difficile) scelti nella lobby: mira, riflessi, parry, schivate dei proiettili |
| 12 | Vibrazione | Assente | Il feedback fisico in un picchiaduro conta molto | Vibrazione del controller su colpo subito, morte, esplosione vicina; interruttore nelle impostazioni |
| 13 | Musica in partita | La musica sfuma all'inizio del round | In partita c'è silenzio sotto gli effetti | Brano di combattimento a parte, più veloce durante la morte improvvisa |
| 14 | Progressione | 10 obiettivi, monete, skin | Le novità non hanno obiettivi propri | Nuovi obiettivi: vincere contro bot difficili, restare in vita durante gli eventi di mappa, vincere un round senza subire danni |

## Stato
Tutti i 14 punti sono fatti (v0.8). Ogni punto e' stato chiuso con: modifica, test della simulazione
(87 test, compresi quelli nuovi sugli eventi di mappa), partita automatica di 8 minuti con i bot che
passa anche per menu, impostazioni e pausa, e partite tra bot ai tre livelli.

Da verificare a mano (non provabile senza schermo): leggibilita' di HUD e fendenti alla distanza della
telecamera, volume relativo di musica ed effetti, intensita' della vibrazione.
