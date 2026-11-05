# Friendslop Fight (prototipo v0.5)

Platform fighter laterale 2D su schermo condiviso, 2-6 giocatori, vince l'ultimo in piedi. Match a 5 vittorie (3 con due giocatori).

## Avvio
Su Windows: doppio clic su `GIOCA.bat` nella cartella `PartyGame` (LÖVE è già incluso).
Altrimenti installa LÖVE 11.5 (love2d.org) e dalla cartella del progetto lancia `love .`

Test della simulazione: `love . test` (oppure `luajit tests/run.lua`).
Prova a secco della grafica con i bot: `luajit tests/smoke_love.lua`.
Ritmo e bilanciamento con partite tra bot: `luajit tests/balance.lua [partite] [giocatori]`.

## Menu principale
All'avvio: Gioca, Personaggi, Obiettivi, Esci. Frecce/WASD o croce/levetta per muoversi, Invio/A per scegliere, Esc/B per tornare.
- **Personaggi**: sei animali guerrieri (gatto ninja, rana samurai, orso pirata, volpe cowboy, coniglio vichingo, procione ladro), tre skin ciascuno. Si comprano con le monete; le skin leggendarie si sbloccano con gli obiettivi. Invio/A su uno sbloccato lo imposta come preferito.
- **Obiettivi**: progressi e ricompense.
- **Monete**: a fine partita, solo per i giocatori umani (partita giocata, eliminazioni, round e partite vinte).
Il profilo si salva nella cartella dati di LÖVE (`profilo.lua`).

## Lobby
Ogni giocatore sceglie l'eroe con sinistra/destra e la skin con su/giu (tastiera 1: A D W S, tastiera 2: frecce). I bot prendono un eroe a caso. Esc torna al menu.
Premi un tasto qualsiasi del controller per entrare, B per uscire, Start o Invio per iniziare. F1/F2 aggiungono la tastiera 1/2, F10 aggiunge un bot, F11 schermo intero. Da soli si parte contro due bot.

## Comandi
| Azione | Controller | Tastiera 1 | Tastiera 2 |
|---|---|---|---|
| Muovi | levetta sinistra / croce | A D | frecce |
| Mira | levetta destra (360°) | mouse | direzione di movimento |
| Salta | A | W / Spazio | su |
| Attacco | X o RT (tieni premuto per le automatiche) | J o click sinistro | Z |
| Scatto | B | K | X |
| Parry | LB / RB / LT | L o click destro | C |
| Raccogli / lancia | Y | U | V |

Con la levetta destra a riposo si mira come prima (8 direzioni con la levetta sinistra, o davanti a sé).
Mirando con la levetta destra il personaggio guarda dove mira, quindi si può indietreggiare sparando. Non c'è mirino: la direzione si legge dall'arma, che ruota verso dove miri.
Tutti i proiettili seguono una traiettoria balistica (cadono con la distanza), quindi per colpire lontano si mira più in alto.

Giù + salto su una piattaforma sottile: scendi. Doppio salto in aria. Contro un muro, tenendo premuto verso la parete, scivoli; salto dal muro ti stacca e ti restituisce il doppio salto.

## Meccaniche
- **Parry (Deflect):** riflette i proiettili e stordisce chi attacca in mischia. Il martello rompe la parata, tranne il **parry perfetto** (i primi 4 frame attivi).
- **Clash:** due attacchi in mischia che si incontrano si respingono; chi reagisce subito ha un contrattacco.
- **Slancio:** i colpi a segno e i parry caricano due livelli (più velocità, poi più danno). Subire colpi lo riduce, e cala da solo se non colpisci. Si azzera a ogni round.
- **Rimbalzi:** i proiettili rimbalzano sui muri un numero limitato di volte (diverso per arma). Dopo un rimbalzo possono colpire anche chi ha sparato.
- **Armi iniziali contese:** a inizio round ci sono meno armi che giocatori, sparse per la mappa.
- **Telecamera:** segue i giocatori vivi e allarga l'inquadratura quando si separano.
- Dopo 45 secondi arriva la lava (morte improvvisa).

## Livelli delle armi
Ogni arma appartiene a un livello; il colore del riquadro a terra e del nome nell'HUD lo indica.
Quando compare un'arma si sceglie prima il livello, poi l'arma. A inizio round escono quasi solo armi Base; nei 40 secondi successivi le probabilità si spostano verso i livelli alti (tutto regolabile in `data.lua`, voce `tiers`).

| Livello | Colore | Inizio round → dopo 40 s | Armi |
|---|---|---|---|
| Base | grigio | 70% → 30% | spada, martello, lancia, frusta, scudo, pistola, fucile a pompa, boomerang |
| Avanzata | azzurro | 25% → 38% | mitraglietta, cecchino, pompa automatico, katana, rampino, pistola a bolle, soffiatore |
| Potente | viola | 5% → 24% | lanciafiamme, lanciagranate, fucile d'assalto, lanciarazzi, mine |
| Mitica | oro | 0% → 8% | spara buchi neri, fucile fantasma, lanciasciame |

Le armi iniziali sono sempre Base. La cassa centrale contiene solo armi Potenti (75%) o Mitiche (25%).

## Armi
| Arma | Tipo | Cosa la rende diversa |
|---|---|---|
| Pugni | mischia | quasi inutili |
| Spada | mischia | veloce, caricamento visibile |
| Martello | mischia | lento, 55 danni, rompe la parata normale |
| Lancia | mischia | portata lunghissima e stretta, affondo in avanti |
| Frusta | mischia | portata lunga, **tira l'avversario verso di te** |
| Katana | mischia | il fendente è **uno scatto invulnerabile** che colpisce tutto sul percorso |
| Scudo | mischia | **para da solo i colpi frontali** finché non attacchi (8 parate, il martello ne toglie 3); l'attacco è una spinta che stordisce |
| Pistola | distanza | 8 colpi, 2 rimbalzi |
| Fucile a pompa | distanza | 6 pallini, media distanza, rinculo |
| Boomerang | distanza | **torna indietro**, colpisce all'andata e al ritorno, si riprende al volo |
| Mitraglietta | distanza | automatica, 30 colpi |
| Fucile cecchino | distanza | carica lunga, 85 danni, attraversa il primo bersaglio, rimbalzi senza perdere velocità |
| Pompa automatico | distanza | il pompa migliorato: si tiene premuto, gittata maggiore |
| Rampino | distanza | sul muro **ti trascina** fino al punto (il salto lo interrompe); su un avversario **lo tira verso di te** |
| Pistola a bolle | distanza | chiude il bersaglio in una **bolla che sale**: non può agire (premendo tasti si libera prima); un colpo la fa scoppiare con 12 danni extra |
| Soffiatore | distanza | **nessun danno**, spinta enorme: serve a buttare gli altri negli spuntoni, nel vuoto o nella lava |
| Lanciafiamme | distanza | automatico e corto, **dà fuoco** (3 danni ogni 1/3 di secondo per 2,5 s); le fiamme non stordiscono |
| Lanciagranate | distanza | granate che rimbalzano ed esplodono dopo 1,5 s |
| Fucile d'assalto | distanza | automatico, preciso, 15 danni a colpo, lunga gittata |
| Lanciarazzi | distanza | il razzo **accelera** ed esplode all'impatto; sparando ai piedi fai il **salto col razzo** |
| Mine | distanza | si posano dove cadono, **si armano dopo un secondo** ed esplodono sotto chiunque, anche te |
| Spara buchi neri | mitica | apre un **buco nero** per 3 s che risucchia giocatori, proiettili e armi; al centro fa danno, poi collassa |
| Fucile fantasma | mitica | proiettili che **attraversano i muri** e il primo bersaglio |
| Lanciasciame | mitica | 5 **missili guidati** verso l'avversario più vicino |

Le armi scariche si lanciano (Y). Gli scoppi feriscono anche chi li ha causati; i muri pieni riparano.

## Mappe
Tutte 64×36 tile (1024×576 px), generate da `tools/genera_mappe.py`: Arena (aperta, colonne sospese), Fabbrica (torre centrale da scalare, travi, vasche di spuntoni), Tetti (palazzi separati dal vuoto). `src/maps/prova.lua` serve solo ai test.

## Strumenti di taratura (in partita)
F3 hitbox, F4 slow motion, F5 pausa, F6 un frame, F7 ricarica `src/sim/data.lua`, F8 pannello valori (su/giù scegli, sinistra/destra cambia, Maiusc x5), F9 salva i valori in `tuning.txt`. Tutti i numeri di bilanciamento stanno in `src/sim/data.lua`.

## Struttura
- `src/sim/`: simulazione pura (nessuna chiamata a LÖVE), testabile e deterministica.
- `src/maps/`: mappe in ASCII (`#` solido, `=` piattaforma, `^` spuntoni, `S` partenza, `W` arma, `C` cassa).
- `src/render.lua` (con la telecamera), `fx.lua`, `audio.lua`, `sprites.lua`, `input.lua`, `bot.lua`, `debug.lua`.
- `tools/`: script per generare le mappe. `tests/`: test automatici e prove con i bot.
- `assets/`: sprite, vedi `assets/README.md`.

## Novità della v0.3
Quattro livelli di armi (Base, Avanzata, Potente, Mitica) al posto della vecchia rarità, con probabilità che salgono durante il round. Quindici armi nuove: frusta, katana, scudo, boomerang, pompa automatico, rampino, pistola a bolle, soffiatore, lanciafiamme, fucile d'assalto, lanciarazzi, mine, spara buchi neri, fucile fantasma, lanciasciame. Nuovi stati: fuoco, bolla, traino del rampino.

## Novità della v0.2
Tolta la Frenzy; mira con la levetta destra (e col mouse per la tastiera 1), senza mirino; proiettili balistici a lunga gittata che rimbalzano; mappe più grandi con telecamera dinamica; quattro armi nuove (lancia, mitraglietta, cecchino, lanciagranate); spada più leggibile, parry perfetto contro il martello, armi iniziali contese, cassa con armi pesanti.
