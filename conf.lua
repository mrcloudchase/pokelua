function love.conf(t)
  t.identity = 'pokelua'
  t.version = '11.4'
  t.console = false
  t.window.title = 'PokéLua · The Aster Archipelago'
  t.window.width = 1280
  t.window.height = 800
  t.window.minwidth = 960
  t.window.minheight = 600
  t.window.resizable = true
  t.window.vsync = 1
  t.window.msaa = 0
  t.modules.physics = false
  t.modules.video = false
end
