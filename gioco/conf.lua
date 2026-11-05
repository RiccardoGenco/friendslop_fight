function love.conf(t)
  t.identity = "partygame"
  t.version = "11.5"
  t.window.title = "Friendslop Fight"
  t.window.width = 1280
  t.window.height = 720
  t.window.resizable = true
  t.window.minwidth = 640
  t.window.minheight = 360
  t.window.vsync = 1
  t.modules.physics = false
  t.modules.video = false
  t.modules.touch = false
end
