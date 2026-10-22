-- Real-engine scene integration test. Uses its own save identity.
local Creature=require('src.systems.creature')
local Smoke={};Smoke.__index=Smoke
function Smoke.new(game)
  math.randomseed(42)
  local source=love.filesystem.getSource()
  return setmetatable({g=game,time=0,index=1,path=source..'/dist/screenshots',steps={
    {at=.4,shot='01-title'},
    {at=.7,run=function(g)g:startNew();assert(g.scene=='starter')end},
    {at=1.0,shot='02-starter'},
    {at=1.3,run=function(g)g:chooseStarter(1);while g.dialogue do g:advanceDialogue() end;assert(g.scene=='world')end},
    {at=1.7,shot='03-world'},
    {at=2.0,run=function(g)g:startWild(Creature.create('sparkit',5));assert(g.battle.wild)end},
    {at=2.4,shot='04-battle'},
    {at=2.7,run=function(g)g.battle.rng=function()return 0 end;g.battleCooldown=0;g:battleAct({kind='catch'});assert(g.battle.outcome=='caught')end},
    {at=3.1,shot='05-caught'},
    {at=3.4,run=function(g)g:finishBattle();assert(#g.state.party==2);g:openJournal(1)end},
    {at=3.8,shot='06-party'},
    {at=4.1,run=function(g)g:setJournalTab(2);for i,id in ipairs(require('src.render.screens').speciesOrder)do if id=='sparkit' then g.journalIndex=i end end end},
    {at=4.5,shot='07-field-guide'},
    {at=4.8,run=function(g)g:setJournalTab(3)end},
    {at=5.2,shot='08-bag'},
    {at=5.5,run=function(g)g:setJournalTab(4)end},
    {at=5.9,shot='09-map'},
    {at=6.2,run=function(g)g:setJournalTab(5)end},
    {at=6.6,shot='10-journey'},
    {at=6.9,run=function(g)g.scene='shop';g.shopName='The Harbor Provisioner';g.shopIndex=1 end},
    {at=7.3,shot='11-shop'},
    {at=7.6,run=function(g)g.scene='ending' end},
    {at=8.0,shot='12-ending'},
    {at=8.5,run=function(g)g.scene='world';assert(g:save(true));assert(require('src.systems.save').load());print('PASS LÖVE scene smoke test (12 screenshots, capture, party, save roundtrip)');love.event.quit(0)end}
  }},Smoke)
end
function Smoke:update(dt)
  self.time=self.time+dt
  local step=self.steps[self.index];if not step or self.time<step.at then return end
  if step.run then step.run(self.g) end
  if step.shot then
    local path=self.path..'/'..step.shot..'.png'
    love.graphics.captureScreenshot(function(data)
      local encoded=data:encode('png');local file=assert(io.open(path,'wb'));file:write(encoded:getString());file:close()
    end)
  end
  self.index=self.index+1
end
return Smoke
