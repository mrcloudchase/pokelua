-- Regression checks for transactional battle saves and keyboard battle notes.
return function()
  local C=require('src.systems.creature')
  local Save=require('src.systems.save')
  local original={love=love,screens=package.loaded['src.render.screens'],audio=package.loaded['src.systems.audio'],game=package.loaded['src.game']}
  package.loaded['src.render.screens']={speciesOrder={},draw=function() end}
  package.loaded['src.systems.audio']={init=function() end,play=function() end,update=function() end,setMuted=function() end,isMuted=function() return true end}
  package.loaded['src.game']=nil
  love={keyboard={isDown=function() return false end}}
  local file=os.tmpname();os.remove(file);Save.configure({path=file})
  local checks=0
  local function check(value,message) checks=checks+1;assert(value,message) end
  local function run()
    local Game=require('src.game')
    local g=Game.new();g:startNew();g:chooseStarter(1)
    while g.dialogue do g:advanceDialogue() end
    g:save(true)
    local checkpoint=assert(Save.load())
    g:startWild(C.create('budpip',3));g.battle.rng=function() return 0 end;g.battleCooldown=0
    g:battleAct({kind='catch'})
    check(g.battle.outcome=='caught','Test reaches a successful pending catch')
    g:save(true) -- Same path used by F5 and love.quit.
    local persisted=assert(Save.load())
    local committed=#persisted.party+#persisted.storage==#checkpoint.party+#checkpoint.storage+1
    local rolledBack=persisted.bag.orbs==checkpoint.bag.orbs and persisted.party[1].xp==checkpoint.party[1].xp
    check(committed or rolledBack,'Saving a pending catch commits the companion or preserves the entire prebattle checkpoint')
    g:finishBattle()
    persisted=assert(Save.load())
    check(#persisted.party==2 and persisted.caught.budpip,'Finishing the catch persists companion and journal record')
    check(persisted.bag.orbs==checkpoint.bag.orbs-1,'A completed catch spends exactly one orb')
    g:startWild(C.create('budpip',3))
    g.battle.log={'1','2','3','4','5','6','7','8','9'};g.battleLogScroll=0
    g:keypressed('up')
    check(g.battleLogScroll==1,'Up scrolls keyboard battle notes as advertised')
    g:keypressed('down')
    check(g.battleLogScroll==0,'Down scrolls keyboard battle notes toward the newest entries')
    g.battle.outcome='win';g:keypressed('up')
    check(g.battleLogScroll==1,'Completed battle notes remain keyboard accessible before leaving')
    return checks
  end
  local ok,result=pcall(run)
  Save.delete();Save.configure()
  love=original.love;package.loaded['src.render.screens']=original.screens;package.loaded['src.systems.audio']=original.audio;package.loaded['src.game']=original.game
  if not ok then error(result,0) end
  return result
end
