# Genera le mappe di gioco in src/maps/. Uso: python3 tools/genera_mappe.py
# Ogni mappa e' 64 x 36 tile (1024 x 576 pixel). Righe e colonne partono da 0.
# Simboli: # solido  = piattaforma  ^ spuntoni  S spawn  W spawner armi  C cassa
#          B blocco distruttibile  < > nastro trasportatore  J molla  P Q portali (a coppie)
#          I ghiaccio (scivoloso)  X barile esplosivo  K blocco friabile (crolla se ci sali)
# Terreno distruttibile: al salvataggio ogni # diventa B, tranne la cornice (bordi, soffitto,
# ultima riga) e le zone segnate con m.saldo(...): quasi tutta la mappa si puo' scavare con le armi.
# Piattaforme mobili: m.mover(riga, colonna, lunghezza, spostamento_colonne, spostamento_righe, periodo)
import os

COLS, ROWS = 64, 36

class Mappa:
    def __init__(self, nome):
        self.nome = nome
        self.g = [["."] * COLS for _ in range(ROWS)]
        self.movers = []
        self.saldi = set()
        for c in range(COLS):
            self.g[0][c] = "#"
        for r in range(ROWS):
            self.g[r][0] = "#"
            self.g[r][COLS - 1] = "#"
    def fill(self, r0, c0, r1, c1, ch="#"):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                self.g[r][c] = ch
    def saldo(self, r0, c0, r1, c1):
        # zona che resta indistruttibile
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                self.saldi.add((r, c))
    def plat(self, r, c0, c1):
        self.fill(r, c0, r, c1, "=")
    def put(self, r, c, ch):
        assert self.g[r][c] == ".", f"{self.nome}: ({r},{c}) occupato da {self.g[r][c]}"
        self.g[r][c] = ch
    def mover(self, r, c, length, dc, dr, period, phase=0):
        # in Lua le righe e le colonne partono da 1
        self.movers.append((c + 1, r + 1, length, dc, dr, period, phase))
    def salva(self, file, descr):
        for r in range(ROWS):
            for c in range(COLS):
                cornice = r == 0 or r == ROWS - 1 or c == 0 or c == COLS - 1
                if self.g[r][c] == "#" and not cornice and (r, c) not in self.saldi:
                    self.g[r][c] = "B"
        rows = ["".join(r) for r in self.g]
        assert all(len(r) == COLS for r in rows)
        for ch in "PQ":
            n = sum(r.count(ch) for r in rows)
            assert n in (0, 2), f"{self.nome}: il portale {ch} compare {n} volte"
        with open(file, "w", encoding="utf-8") as f:
            f.write(f"-- Mappa generata da tools/genera_mappe.py: {self.nome}\n")
            f.write(f"-- {descr}\n")
            f.write("-- Simboli: # solido  = piattaforma  ^ spuntoni  S spawn  W armi  C cassa\n")
            f.write("--          B distruttibile  < > nastro  J molla  P Q portali  I ghiaccio  X barile  K friabile\n")
            f.write("return {\n  name = '%s',\n  rows = {\n" % self.nome)
            for r in rows:
                f.write('    "%s",\n' % r)
            f.write("  },\n  movers = {\n")
            for (c, r, l, dc, dr, per, ph) in self.movers:
                f.write("    { c = %d, r = %d, len = %d, dc = %d, dr = %d, period = %d, phase = %s },\n"
                        % (c, r, l, dc, dr, per, ph))
            f.write("  },\n}\n")

out = os.path.join(os.path.dirname(__file__), "..", "src", "maps")

# ---------------------------------------------------------------- Arena
# Colosseo in rovina: ponte di blocchi sopra la fossa di spuntoni, molle verso le tribune,
# piattaforma mobile al centro, colonne in parte distruttibili, portali incrociati negli angoli.
m = Mappa("Arena")
m.fill(33, 0, 35, COLS - 1)
m.fill(33, 27, 33, 36, "B")                    # ponte sopra la fossa
m.fill(34, 27, 34, 36, "^")                    # spuntoni sotto il ponte
m.plat(28, 10, 18); m.plat(28, 45, 53)         # gradinate basse
m.plat(21, 3, 9); m.plat(21, 54, 60)           # tribune raggiunte con le molle
m.fill(13, 19, 18, 20); m.fill(13, 43, 18, 44) # colonne (salto dalla parete)
m.fill(19, 19, 23, 20, "B"); m.fill(19, 43, 23, 44, "B")   # base delle colonne: si sbriciola
m.plat(17, 24, 30); m.plat(17, 33, 39)         # passerella alta spezzata
m.plat(10, 2, 12); m.plat(10, 51, 61)          # balconate in alto
m.plat(8, 27, 36)                              # palco della cassa
m.mover(25, 21, 5, 17, 0, 420)                 # piattaforma mobile centrale
m.put(32, 6, "J"); m.put(32, 57, "J")
m.put(32, 2, "P"); m.put(9, 61, "P")
m.put(32, 61, "Q"); m.put(9, 2, "Q")
for c in (4, 12, 22, 41, 51, 59):
    m.put(32, c, "S")
m.put(27, 16, "S"); m.put(27, 47, "S")
for r, c in ((32, 9), (32, 54), (27, 11), (27, 52), (20, 5), (20, 58), (16, 27), (16, 36), (9, 8), (9, 55)):
    m.put(r, c, "W")
m.put(7, 31, "C")
m.salva(os.path.join(out, "arena.lua"), "Colosseo: ponte distruttibile sulla fossa, molle, piattaforma mobile, portali negli angoli.")

# ---------------------------------------------------------------- Fabbrica
# Nastri che trascinano verso le vasche di spuntoni, ascensori ai lati, torre su una pila
# di casse distruttibili, molle verso le travi del soffitto.
m = Mappa("Fabbrica")
m.fill(33, 0, 35, COLS - 1)
m.fill(33, 1, 33, 24, ">"); m.fill(33, 39, 33, 62, "<")    # nastri verso il centro
m.fill(32, 26, 32, 29, "^"); m.fill(32, 34, 32, 37, "^")   # vasche di spuntoni
m.fill(15, 30, 24, 33)                                     # torre
m.fill(25, 30, 32, 33, "B")                                # pila di casse sotto la torre
m.plat(28, 9, 18); m.plat(28, 45, 54)
m.plat(22, 12, 24); m.plat(22, 39, 51)
m.plat(16, 8, 16); m.plat(16, 47, 55)
m.plat(9, 19, 27); m.plat(9, 36, 44)                       # travi alte
m.fill(1, 15, 6, 16); m.fill(1, 47, 6, 48)                 # travi dal soffitto
m.fill(10, 2, 11, 6, "B"); m.fill(10, 57, 11, 61, "B")     # casse impilate in alto
m.mover(31, 2, 4, 0, -21, 480)                             # ascensori
m.mover(31, 58, 4, 0, -21, 480, 0.5)
m.put(21, 18, "J"); m.put(21, 45, "J")
for c in (8, 16, 47, 55):
    m.put(32, c, "S")
m.put(27, 12, "S"); m.put(27, 51, "S")
for r, c in ((27, 15), (27, 48), (21, 14), (21, 49), (15, 11), (15, 52), (14, 31), (32, 20), (32, 43), (8, 23), (8, 40)):
    m.put(r, c, "W")
m.put(4, 31, "C")
m.salva(os.path.join(out, "fabbrica.lua"), "Nastri verso gli spuntoni, ascensori, torre su casse distruttibili, molle verso le travi.")

# ---------------------------------------------------------------- Tetti
# Palazzi sul vuoto (chi cade muore), una gondola che attraversa il burrone centrale,
# un montacarichi nel vicolo, molle sui tetti, serbatoio distruttibile, portale tra i due estremi.
m = Mappa("Tetti")
m.fill(24, 0, 35, 12)                          # palazzo A
m.fill(21, 17, 35, 27)                         # palazzo B
m.fill(23, 36, 35, 46)                         # palazzo C
m.fill(19, 51, 35, COLS - 1)                   # palazzo D
m.fill(16, 20, 20, 21)                         # comignolo di B
m.fill(14, 58, 18, 59)                         # comignolo di D
m.fill(19, 39, 22, 42, "B")                    # serbatoio dell'acqua
m.plat(12, 2, 10); m.plat(12, 53, 61)          # cartelloni
m.plat(11, 25, 38)                             # insegna centrale
m.plat(15, 31, 38)                             # passerella sopra il burrone
m.mover(23, 28, 3, 5, 0, 300)                  # gondola nel burrone
m.mover(30, 47, 3, 0, -14, 360)                # montacarichi nel vicolo
m.put(23, 6, "J"); m.put(18, 55, "J")
m.put(23, 2, "P"); m.put(18, 61, "P")
for r, c in ((23, 4), (23, 9), (20, 18), (20, 25), (22, 37), (22, 45), (18, 53), (18, 60)):
    m.put(r, c, "S")
for r, c in ((23, 11), (11, 6), (20, 23), (22, 44), (18, 57), (10, 28), (10, 35), (11, 57), (14, 36)):
    m.put(r, c, "W")
m.put(5, 31, "C")
m.salva(os.path.join(out, "tetti.lua"), "Palazzi sul vuoto, gondola e montacarichi, molle sui tetti, serbatoio distruttibile.")

# ---------------------------------------------------------------- Miniera
# Pozzi con ascensori ai lati, una montagna con un tunnel di roccia da far saltare,
# pareti di roccia distruttibili, ponteggi di legno, portali incrociati.
m = Mappa("Miniera")
m.fill(33, 0, 35, COLS - 1)
m.fill(32, 15, 32, 17, "^"); m.fill(32, 46, 32, 48, "^")   # stalagmiti
m.fill(26, 24, 32, 39)                                     # montagna
m.fill(29, 24, 31, 39, "B")                                # tunnel ostruito
m.fill(22, 28, 25, 35)                                     # cima
m.fill(15, 20, 21, 20, "B"); m.fill(15, 43, 21, 43, "B")   # pareti di roccia
m.plat(28, 6, 13); m.plat(28, 50, 57)
m.plat(23, 9, 18); m.plat(23, 45, 54)
m.plat(18, 5, 12); m.plat(18, 51, 58)
m.plat(14, 18, 26); m.plat(14, 37, 45)
m.plat(9, 26, 37)
for c in (8, 13, 22, 29, 34, 41, 50, 55):                  # stalattiti
    m.fill(1, c, 2 + (c % 3), c)
m.mover(31, 1, 3, 0, -22, 540)
m.mover(31, 60, 3, 0, -22, 540, 0.5)
m.put(21, 30, "J"); m.put(21, 33, "J")
m.put(32, 8, "P"); m.put(13, 40, "P")
m.put(32, 55, "Q"); m.put(13, 23, "Q")
for c in (6, 11, 21, 42, 52, 57):
    m.put(32, c, "S")
m.put(25, 26, "S"); m.put(25, 37, "S")
for r, c in ((27, 10), (27, 53), (22, 14), (22, 49), (17, 8), (17, 55), (8, 28), (8, 35), (13, 21), (13, 42)):
    m.put(r, c, "W")
m.put(4, 31, "C")
m.salva(os.path.join(out, "miniera.lua"), "Ascensori nei pozzi, tunnel da far saltare, pareti di roccia distruttibili, portali incrociati.")
# ---------------------------------------------------------------- Ghiacciaio
# Lago ghiacciato: si scivola su tutto il pavimento, un ponte di ghiaccio friabile sopra il crepaccio,
# colline di neve, stalattiti di ghiaccio, una lastra friabile in alto.
m = Mappa("Ghiacciaio")
m.fill(33, 0, 35, COLS - 1)
m.fill(31, 26, 34, 37, "."); m.fill(34, 26, 34, 37, "^")   # crepaccio con punte di ghiaccio
m.fill(33, 1, 33, 25, "I"); m.fill(33, 38, 33, 62, "I")     # lago ghiacciato
m.fill(30, 25, 30, 38, "K")                                 # ponte friabile
m.fill(27, 8, 32, 14); m.fill(27, 8, 27, 14, "I")           # colline con la cima ghiacciata
m.fill(27, 49, 32, 55); m.fill(27, 49, 27, 55, "I")
m.fill(12, 20, 22, 21); m.fill(12, 42, 22, 43)              # pilastri (salto dalla parete)
m.plat(23, 2, 7); m.plat(23, 56, 61)
m.plat(18, 10, 17); m.plat(18, 46, 53)
m.fill(14, 26, 14, 37, "K")                                 # lastra friabile
m.plat(9, 4, 12); m.plat(9, 51, 59)
m.plat(7, 28, 35)
for c, n in ((10, 2), (17, 3), (30, 2), (33, 2), (46, 3), (53, 2)):   # stalattiti
    m.fill(1, c, n, c)
m.put(32, 4, "J"); m.put(32, 59, "J")
m.put(32, 2, "P"); m.put(8, 61, "P")
for r, c in ((32, 6), (32, 18), (32, 22), (32, 41), (32, 45), (32, 57), (26, 11), (26, 52)):
    m.put(r, c, "S")
for r, c in ((32, 16), (32, 47), (26, 9), (26, 54), (22, 4), (22, 59), (17, 13), (17, 50), (8, 8), (8, 55)):
    m.put(r, c, "W")
m.put(6, 31, "C")
m.salva(os.path.join(out, "ghiacciaio.lua"), "Lago ghiacciato scivoloso, ponte friabile sul crepaccio, colline di neve, stalattiti.")

# ---------------------------------------------------------------- Vulcano
# Lago di lava al centro con un'isola e pietre friabili per attraversarlo, barili esplosivi
# sulle scogliere, un ponte di basalto che crolla.
m = Mappa("Vulcano")
m.fill(33, 0, 35, COLS - 1)
m.fill(33, 20, 34, 43, "."); m.fill(34, 20, 34, 43, "^")   # lava
m.fill(26, 28, 32, 35)                                     # isola
m.fill(30, 22, 30, 24, "K"); m.fill(30, 39, 30, 41, "K")   # pietre friabili sulla lava
m.fill(26, 1, 32, 7); m.fill(26, 56, 32, 62)               # scogliere
m.put(25, 4, "X"); m.put(25, 5, "X"); m.put(25, 58, "X"); m.put(25, 59, "X")
m.fill(10, 14, 20, 15); m.fill(10, 48, 20, 49)             # pilastri
m.fill(22, 26, 22, 37, "K")                                # ponte che crolla
m.plat(21, 2, 9); m.plat(21, 54, 61)
m.plat(16, 20, 27); m.plat(16, 36, 43)
m.plat(11, 27, 36)
m.plat(6, 4, 11); m.plat(6, 52, 59)
m.put(32, 12, "J"); m.put(32, 51, "J")
m.put(32, 14, "P"); m.put(10, 29, "P")
for r, c in ((32, 10), (32, 16), (32, 47), (32, 53), (25, 30), (25, 33), (25, 2), (25, 61)):
    m.put(r, c, "S")
for r, c in ((32, 18), (32, 45), (25, 31), (20, 4), (20, 59), (15, 23), (15, 40), (5, 7), (5, 56)):
    m.put(r, c, "W")
m.put(4, 31, "C")
m.salva(os.path.join(out, "vulcano.lua"), "Lago di lava, isola centrale, pietre friabili, barili esplosivi sulle scogliere.")

# ---------------------------------------------------------------- Tempio
# Piramide a gradoni con una camera segreta da scavare, pavimenti friabili sopra le trappole,
# portali incrociati, molle.
m = Mappa("Tempio")
m.fill(33, 0, 35, COLS - 1)
m.fill(28, 20, 32, 43); m.fill(24, 24, 27, 39); m.fill(20, 28, 23, 35)   # piramide
m.fill(29, 26, 31, 37, ".")                                              # camera segreta
m.fill(33, 10, 33, 15, "K"); m.fill(34, 10, 34, 15, "^")                 # trappole
m.fill(33, 48, 33, 53, "K"); m.fill(34, 48, 34, 53, "^")
m.fill(8, 8, 18, 9); m.fill(8, 54, 18, 55)                               # pilastri
m.plat(26, 2, 8); m.plat(26, 55, 61)
m.plat(21, 12, 19); m.plat(21, 44, 51)
m.plat(15, 20, 27); m.plat(15, 36, 43)
m.plat(10, 28, 35)
m.put(32, 4, "J"); m.put(32, 59, "J")
m.put(32, 2, "P"); m.put(9, 61, "P")
m.put(32, 61, "Q"); m.put(9, 2, "Q")
for r, c in ((32, 6), (32, 18), (32, 45), (32, 57), (19, 29), (19, 34), (23, 25), (23, 38)):
    m.put(r, c, "S")
for r, c in ((32, 8), (32, 55), (25, 4), (25, 59), (20, 15), (20, 48), (14, 23), (14, 40), (9, 31), (31, 31)):
    m.put(r, c, "W")
m.put(5, 31, "C")
m.salva(os.path.join(out, "tempio.lua"), "Piramide con camera segreta da scavare, pavimenti friabili sulle trappole, portali.")

# ---------------------------------------------------------------- Galeone
# Nave pirata sul mare (chi cade in acqua muore): alberi da scalare e da abbattere, barili di
# polvere da sparo sul ponte, stiva da scavare, due scogli ai lati.
m = Mappa("Galeone")
m.fill(24, 8, 31, 55); m.fill(32, 10, 32, 53); m.fill(33, 13, 33, 50)   # scafo
m.fill(26, 14, 29, 48, ".")                                            # stiva
m.fill(17, 44, 23, 55)                                                 # cabina del capitano
m.fill(20, 8, 23, 16)                                                  # castello di prua
m.fill(6, 24, 23, 24); m.fill(9, 36, 23, 36)                           # alberi
m.plat(9, 19, 23); m.plat(9, 25, 29); m.plat(12, 31, 35); m.plat(12, 37, 41); m.plat(5, 21, 27)
m.fill(30, 0, 34, 4); m.fill(30, 59, 34, 63)                           # scogli
for c in (20, 21, 40):
    m.put(23, c, "X")                                                  # polvere da sparo
m.put(23, 31, "J")
m.mover(14, 2, 4, 0, 8, 300)                                           # gru
m.put(29, 2, "P"); m.put(29, 61, "P")
for r, c in ((19, 10), (19, 14), (23, 18), (23, 28), (23, 34), (23, 42), (16, 46), (16, 52), (29, 3), (29, 60)):
    m.put(r, c, "S")
for r, c in ((23, 26), (23, 38), (8, 22), (11, 33), (4, 24), (16, 49), (19, 12), (29, 30), (29, 20)):
    m.put(r, c, "W")
m.put(3, 31, "C")
m.salva(os.path.join(out, "galeone.lua"), "Nave pirata sul mare: alberi da abbattere, barili di polvere da sparo, stiva da scavare.")

# ---------------------------------------------------------------- Laboratorio
# Reattore pieno di barili al centro, nastri verso le vasche, griglie friabili, portali incrociati.
m = Mappa("Laboratorio")
m.fill(33, 0, 35, COLS - 1)
m.fill(33, 1, 33, 20, ">"); m.fill(33, 43, 33, 62, "<")
m.fill(32, 22, 32, 25, "^"); m.fill(32, 38, 32, 41, "^")
m.fill(22, 28, 32, 35); m.fill(27, 30, 29, 33, "X")          # reattore
m.fill(10, 12, 20, 13); m.fill(10, 50, 20, 51)
m.plat(27, 4, 10); m.plat(27, 53, 59)
m.plat(21, 16, 24); m.plat(21, 39, 47)
m.fill(15, 26, 15, 37, "K")                                 # griglia friabile
m.plat(9, 4, 10); m.plat(9, 53, 59)
m.plat(6, 28, 35)
m.put(32, 27, "J"); m.put(32, 36, "J")
m.put(32, 2, "P"); m.put(8, 61, "P")
m.put(32, 61, "Q"); m.put(8, 2, "Q")
for r, c in ((32, 6), (32, 15), (32, 48), (32, 57), (26, 7), (26, 56), (21, 30), (21, 33)):
    m.put(r, c, "S")
for r, c in ((32, 10), (32, 53), (26, 5), (26, 58), (20, 20), (20, 43), (14, 30), (14, 33), (8, 7), (8, 56)):
    m.put(r, c, "W")
m.put(5, 31, "C")
m.salva(os.path.join(out, "laboratorio.lua"), "Reattore pieno di barili esplosivi, nastri verso le vasche, griglia friabile, portali.")
print("mappe generate")
