-- Esegue i test senza LÖVE: lua tests/run.lua (dalla cartella del progetto, serve Lua 5.1 o LuaJIT)
package.path = "./?.lua;" .. package.path
local run = require("tests.run_tests")
os.exit(run() > 0 and 1 or 0)
