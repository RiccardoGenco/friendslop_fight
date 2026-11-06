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

Come si fanno gli eroi (metodo corretto, con pixel netti):
1. Si generano due immagini larghe 1792x896 con sfondo trasparente: la prima con tre pose a terra
   (fermo, corsa 1, corsa 2), la seconda con tre pose in aria (salto, caduta, scatto) usando la prima
   come riferimento, cosi' il personaggio resta identico.
2. `tools/unisci_pose.py <eroe> <variante a> <variante b>` separa le pose, toglie ombre e linee di terra,
   trova la griglia vera dei pixel del modello (`tools/griglia_pixel.py`: tagli dove i colori cambiano,
   colore dominante per cella) e tiene la risoluzione nativa, senza stirare.
3. Le skin si fanno per scambio di palette (`tools/skin_palette.py`): stesse pose, colori nuovi.

## Texture delle mappe (assets/tiles)

- `<tema>.png`: texture ripetibile senza cuciture, 32 pixel d'arte per casella (disegnata a 0,5).
  Generata con Qwen (immagine pixel art), ridotta al vero passo dei pixel, poi resa ripetibile:
  si sposta di meta' lato, si fa riparare a Qwen solo la croce centrale e si rimette a posto.
- `blocco_pietra.png`, `blocco_cassa.png`: blocchi friabili quando il tema non ha texture.
- La roccia madre (cornice della mappa) e' la stessa texture piu' scura: e' l'unica parte che non si rompe.
