-- Copia questo file in assets/sprites.lua e adattalo al tuo sprite sheet.
-- Lo sheet e' una griglia di frame tutti della stessa misura, numerati da 1
-- da sinistra a destra e dall'alto in basso.
return {
  player = {
    image   = "assets/goblin.png",  -- percorso dell'immagine
    frame_w = 16, frame_h = 16,     -- misura di un frame in pixel
    scale   = 1,                    -- ingrandimento (il gioco e' 640x360)
    ox = 8, oy = 16,                -- punto d'appoggio nel frame (di default: centro-basso)
    faces_left = false,             -- true se lo sheet disegna il personaggio verso sinistra
    tint = true,                    -- true: colora lo sprite col colore del giocatore
    fps = 10,
    anims = {                       -- numeri dei frame per ogni animazione
      idle  = { 1, 2 },
      run   = { 3, 4, 5, 6 },
      jump  = { 7 },
      attack = { 8, 9 },
      hurt  = { 10 },
      dash  = { 11 },
      parry = { 12 },
    },
  },
}
