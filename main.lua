local Game = require('src.game')
local UI = require('src.render.ui')
local game, smoke, verify
local function transform()
  local w,h=love.graphics.getDimensions()
  UI.scale=math.min(w/1280,h/800);UI.ox=(w-1280*UI.scale)/2;UI.oy=(h-800*UI.scale)/2
end
function love.load(args)
  love.graphics.setDefaultFilter('nearest','nearest')
  love.math.setRandomSeed(os.time());math.randomseed(os.time())
  local smokeMode=false
  for _,a in ipairs(args or {}) do if a=='--smoke' then smokeMode=true elseif a=='--verify' then verify={time=0,started=false} end end
  if smokeMode or verify then
    love.filesystem.setIdentity(verify and 'pokelua-package-check' or 'pokelua-smoke')
    require('src.systems.save').delete()
    love.errorhandler=function(message) io.stderr:write(tostring(message)..'\n'..debug.traceback()..'\n');os.exit(1) end
  end
  UI.init(); game=Game.new();transform()
  if smokeMode then smoke=require('scripts.smoke').new(game) end
end
function love.update(dt)
  dt=math.min(dt,.1);game:update(dt)
  if smoke then smoke:update(dt) end
  if verify then
    verify.time=verify.time+dt
    if verify.time>1 and not verify.started then
      verify.started=true;game:startNew();game:chooseStarter(3)
      while game.dialogue do game:advanceDialogue() end
      game:startWild(require('src.systems.creature').create('sparkit',3))
      game.battle.rng=function()return 0 end;game.battleCooldown=0
      game:battleAct({kind='catch'});assert(game.battle.outcome=='caught');game:finishBattle()
      assert(#game.state.party==2 and game:save(true))
    elseif verify.time>1.8 then print('PASS packaged game startup, capture, render, and save');love.event.quit(0) end
  end
end
function love.draw()
  love.graphics.clear(UI.c.bg)
  love.graphics.push();love.graphics.translate(UI.ox,UI.oy);love.graphics.scale(UI.scale)
  UI.begin();game:draw();love.graphics.pop()
end
function love.resize() transform() end
function love.keypressed(key)
  if key=='f11' then love.window.setFullscreen(not love.window.getFullscreen(),'desktop');transform();return end
  game:keypressed(key)
end
function love.mousepressed(x,y,b)
  if b==1 then UI.click((x-UI.ox)/UI.scale,(y-UI.oy)/UI.scale) end
end
function love.wheelmoved(_,y) game:wheelmoved(y) end
function love.quit() if game and game.state and game.state.starter then game:save(true) end end
