# Sprite

Senza file in questa cartella il gioco disegna rettangoli colorati.

1. Metti lo sprite sheet (PNG) in `assets/`.
2. Copia `sprites.example.lua` in `sprites.lua` e imposta immagine, misura dei frame e numeri dei frame per ogni animazione.
3. Riavvia il gioco.

Animazioni riconosciute: idle, run, jump, attack, hurt, dash, parry. Quelle mancanti ripiegano su idle.
Controlla la licenza del pacchetto di pixel art prima di distribuire il gioco.

## Eroi da immagine
Se esiste `assets/heroes/<eroe>_<skin>.png` l'eroe usa quell'immagine invece del disegno a griglia.
Con il file `.lua` accanto (`{ fw, fh, ox, frames }`) l'immagine e' un foglio di pose in fila:
fermo, corsa 1, corsa 2, salto, caduta, scatto. Il codice aggiunge respiro, passo, inclinazione e contorno del colore del giocatore.

Per creare un foglio da una generazione con sfondo trasparente (sei pose in una riga):

    python3 tools/foglio_pose.py generazione.png assets/heroes/gatto_1.png 52

52 e' l'altezza in pixel della posa ferma (il gioco la disegna a mezzo pixel: circa 26 pixel del mondo).
