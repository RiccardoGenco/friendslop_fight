# Genera le mappe di gioco in src/maps/. Uso: python3 tools/genera_mappe.py
# Ogni mappa e' 64 x 36 tile (1024 x 576 pixel). Righe e colonne partono da 0.
# Simboli: # solido  = piattaforma  ^ spuntoni  S spawn  W spawner armi  C cassa
import os

COLS, ROWS = 64, 36

class Mappa:
    def __init__(self, nome):
        self.nome = nome
        self.g = [["."] * COLS for _ in range(ROWS)]
        for c in range(COLS):
            self.g[0][c] = "#"
        for r in range(ROWS):
            self.g[r][0] = "#"
            self.g[r][COLS - 1] = "#"
    def fill(self, r0, c0, r1, c1, ch="#"):
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                self.g[r][c] = ch
    def plat(self, r, c0, c1):
        self.fill(r, c0, r, c1, "=")
    def put(self, r, c, ch):
        assert self.g[r][c] == ".", f"{self.nome}: ({r},{c}) occupato da {self.g[r][c]}"
        self.g[r][c] = ch
    def specchio(self, fn):
        # disegna un elemento e la sua copia simmetrica rispetto al centro
        fn(lambda c: c)
        fn(lambda c: COLS - 1 - c)
    def salva(self, file, descr):
        rows = ["".join(r) for r in self.g]
        assert all(len(r) == COLS for r in rows)
        with open(file, "w", encoding="utf-8") as f:
            f.write(f"-- Mappa generata da tools/genera_mappe.py: {self.nome}\n")
            f.write(f"-- {descr}\n")
            f.write("-- Simboli: # solido  = piattaforma  ^ spuntoni  S spawn  W spawner armi  C cassa\n")
            f.write("return {\n  name = '%s',\n  rows = {\n" % self.nome)
            for r in rows:
                f.write('    "%s",\n' % r)
            f.write("  },\n}\n")

out = os.path.join(os.path.dirname(__file__), "..", "src", "maps")

# ---------------------------------------------------------------- Arena
m = Mappa("Arena")
m.fill(33, 0, 35, COLS - 1)                     # pavimento
m.fill(32, 30, 32, 33, "^")                     # spuntoni al centro, sotto la piattaforma
m.plat(27, 8, 17); m.plat(27, 46, 55)           # piattaforme basse
m.plat(24, 26, 37)                              # piattaforma centrale
m.fill(14, 20, 22, 21); m.fill(14, 42, 22, 43)  # colonne sospese (salto dalla parete)
m.plat(18, 4, 12); m.plat(18, 51, 59)           # piattaforme laterali
m.plat(12, 24, 39)                              # passerella alta
m.plat(9, 6, 14); m.plat(9, 49, 57)             # angoli in alto
for c in (4, 14, 24, 39, 49, 59):
    m.put(32, c, "S")
m.put(26, 10, "S"); m.put(26, 53, "S")
for r, c in ((23, 31), (11, 31), (26, 13), (26, 50), (17, 8), (17, 55), (32, 9), (32, 54)):
    m.put(r, c, "W")
m.put(8, 32, "C")
m.salva(os.path.join(out, "arena.lua"), "Aperta e simmetrica, due colonne sospese per il salto dalla parete.")

# ---------------------------------------------------------------- Fabbrica
m = Mappa("Fabbrica")
m.fill(33, 0, 35, COLS - 1)
m.fill(14, 30, 32, 33)                          # torre centrale: divide la mappa, si scala dalle pareti
m.fill(26, 1, 27, 8); m.fill(26, 55, 27, 62)    # mensole attaccate ai muri
m.plat(22, 12, 24); m.plat(22, 39, 51)
m.fill(32, 18, 32, 20, "^"); m.fill(32, 43, 32, 45, "^")   # vasche di spuntoni
m.fill(1, 15, 10, 16); m.fill(1, 47, 10, 48)    # travi che scendono dal soffitto
m.plat(16, 3, 12); m.plat(16, 51, 60)
m.plat(9, 22, 28); m.plat(9, 35, 41)
for c in (4, 11, 25, 38, 52, 59):
    m.put(32, c, "S")
m.put(25, 4, "S"); m.put(25, 59, "S")
for r, c in ((32, 8), (32, 55), (21, 18), (21, 45), (13, 31), (15, 7), (15, 56), (8, 25), (8, 38)):
    m.put(r, c, "W")
m.put(4, 32, "C")
m.salva(os.path.join(out, "fabbrica.lua"), "Torre centrale da scalare, travi dal soffitto, vasche di spuntoni.")

# ---------------------------------------------------------------- Tetti
m = Mappa("Tetti")
m.fill(26, 1, 35, 12)                           # palazzo A
m.fill(22, 17, 35, 27)                          # palazzo B
m.fill(24, 36, 35, 46)                          # palazzo C
m.fill(20, 51, 35, 62)                          # palazzo D
m.fill(17, 20, 21, 21)                          # comignolo su B
m.fill(15, 55, 19, 56)                          # comignolo su D
m.fill(23, 44, 23, 45, "^")                     # antenna a spuntoni su C
m.plat(25, 30, 33)                              # ponte sospeso nel vuoto
m.plat(14, 5, 13); m.plat(11, 26, 37); m.plat(15, 40, 48)   # cartelloni
for r, c in ((25, 3), (25, 9), (21, 18), (21, 25), (23, 38), (23, 42), (19, 52), (19, 60)):
    m.put(r, c, "S")
for r, c in ((25, 6), (21, 24), (23, 40), (19, 58), (13, 9), (10, 31), (14, 44), (24, 31)):
    m.put(r, c, "W")
m.put(5, 32, "C")
m.salva(os.path.join(out, "tetti.lua"), "Palazzi separati dal vuoto: chi cade muore. Comignoli per il salto dalla parete.")
print("mappe generate")
