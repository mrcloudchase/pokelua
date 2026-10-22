local Data = require('src.data.creatures')
local Creature = require('src.systems.creature')
local Battle = require('src.systems.battle')
local World = require('src.data.world')
local Save = require('src.systems.save')
local Audio = require('src.systems.audio')
local Screens = require('src.render.screens')
local Game = {}; Game.__index=Game
local directions={up={0,-1},down={0,1},left={-1,0},right={1,0}}
local keys={w='up',s='down',a='left',d='right',up='up',down='down',left='left',right='right'}
local function count(t) local n=0;for _ in pairs(t or {}) do n=n+1 end;return n end
local function bounded(v,min,max,default) if type(v)~='number' or v~=v then return default end;return math.max(min,math.min(max,math.floor(v))) end
function Game.new()
  local g=setmetatable({scene='title',time=0,toast=nil,starterIndex=1,menuIndex=1,journalTab=1,journalIndex=1,moveCooldown=0,moveTween=0,battleCooldown=0,hasSave=Save.exists(),screenShake=0},Game)
  Audio.init();return g
end
function Game:notify(text) self.toast={text=text,left=4};end
function Game:badgeCount() return self.state and #self.state.badges or 0 end
function Game:zone() return World.zones[self.state.player.zone] end
function Game:objective()
  local i=self:badgeCount()+1
  if i<=#World.bosses then local b=World.bosses[i];return b.title or b.name, 'Meet '..b.name..' in '..(World.zones[b.zone] and World.zones[b.zone].name or b.zone)..'.' end
  return 'A sky made whole','Discover every companion. Aetherion now roams the Observatory.'
end
function Game:startNew()
  self.state={version=1,player={zone=World.start.zone,x=World.start.x,y=World.start.y,direction='down'},party={},storage={},bag={orbs=12,tonics=6},money=180,badges={},defeated={},seen={},caught={},steps=0,playtime=0,visited={[World.start.zone]=true},ending=false}
  self.scene='starter';self.starterIndex=1;self.lastEncounter=0;self.dialogue=nil;Audio.play('confirm')
end
function Game:chooseStarter(index)
  local id=Data.starters[index]; if not id then return end
  self.state.starter=id;self.state.party={Creature.create(id,5)};self.state.seen[id]=true;self.state.caught[id]=true
  self.scene='world';self.moveCooldown=.25;self:save(true);Audio.play('confirm')
  self:talk('PROFESSOR SELENE',{
    Creature.name(self.state.party[1])..' chose you, too. A bond is always a beginning.',
    'The great Aster Beacon has gone dark. Its four wardens each hold a fragment of the light. Travel the archipelago and earn their trust.',
    'Walk with WASD or the arrow keys. Face someone and press E or Space to talk. The tall grass is full of wild companions.',
    'Weaken a wild creature, then press C in battle to offer a binding orb. Tab opens your field journal. Healers restore your entire party for free.',
    'Find the first warden in Verdant Reach, east of the harbor. The paths will carry you. Take your time; there is a whole world between here and the stars.'
  })
end
function Game:validateState(s)
  if type(s)~='table' or s.version~=1 or type(s.player)~='table' or type(s.party)~='table' or #s.party<1 or #s.party>6 then return nil,'This save has an unsupported format.' end
  if not Data.species[s.starter] then return nil,'The starter record is missing.' end
  if type(s.storage)~='table' or type(s.bag)~='table' then return nil,'Invalid sanctuary or bag record.' end
  local z=World.zones[s.player.zone];if not z then return nil,'Unknown region in save.' end
  for _,list in ipairs({s.party,s.storage or {}}) do
    if #list>500 then return nil,'Too many stored companions.' end
    for _,c in ipairs(list) do
      if type(c)~='table' or not Data.species[c.species] then return nil,'Unknown companion in save.' end
      if type(c.nickname)~='string' then c.nickname=nil else c.nickname=c.nickname:sub(1,32) end
      c.level=bounded(c.level,1,50,5);c.xp=bounded(c.xp,0,999999,0)
      c.hp=bounded(c.hp,0,Creature.stats(c).hp,Creature.stats(c).hp)
      if type(c.moves)~='table' or #c.moves<1 or #c.moves>4 then return nil,'Invalid move record.' end
      for _,move in ipairs(c.moves) do if not Data.moves[move] then return nil,'Unknown move in save.' end end
    end
  end
  s.storage=s.storage or {};s.bag=s.bag or {};s.bag.orbs=bounded(s.bag.orbs,0,9999,0);s.bag.tonics=bounded(s.bag.tonics,0,9999,0)
  s.money=bounded(s.money,0,999999,0);s.steps=bounded(s.steps,0,99999999,0);s.playtime=bounded(s.playtime,0,99999999,0)
  s.badges=type(s.badges)=='table' and s.badges or {}; if #s.badges>4 then return nil,'Invalid beacon seals.' end
  for i,id in ipairs(s.badges) do if not World.bosses[i] or id~=World.bosses[i].id then return nil,'Invalid Beacon Seal order.' end end
  for _,key in ipairs({'defeated','seen','caught','visited'}) do if type(s[key])~='table' then s[key]={} end end
  s.player.x=bounded(s.player.x,1,z.width,z.spawn.x);s.player.y=bounded(s.player.y,1,z.height,z.spawn.y)
  if not World.isWalkable(z,s.player.x,s.player.y) then s.player.x=z.spawn.x;s.player.y=z.spawn.y end
  if not directions[s.player.direction] then s.player.direction='down' end
  s.visited[s.player.zone]=true;return s
end
function Game:continueGame()
  local data,err=Save.load();if data then data,err=self:validateState(data) end
  if not data then self:notify('Could not load: '..tostring(err or 'no save found'));return end
  self.state=data;self.lastEncounter=data.steps;self.dialogue=nil;self.scene='world';self.moveCooldown=.25;self.moveTween=0;Audio.play('confirm');self:notify('Welcome back to Aster.')
end
function Game:save(quiet)
  if not self.state or not self.state.starter then return false end
  if self.scene=='battle' then if not quiet then self:notify('Finish the encounter before saving. Your prebattle checkpoint is safe.') end;return false end
  local ok,err=Save.save(self.state);self.hasSave=Save.exists()
  if not quiet or not ok then self:notify(ok and 'Journey saved.' or ('Save failed: '..tostring(err)));Audio.play(ok and 'confirm' or 'cancel') end
  return ok
end
function Game:talk(name,lines,onClose)
  if type(lines)=='string' then lines={lines} end
  self.dialogue={name=name,lines=lines,index=1,onClose=onClose};Audio.play('confirm')
end
function Game:advanceDialogue()
  local d=self.dialogue;if not d then return end
  d.index=d.index+1;Audio.play('confirm')
  if d.index>#d.lines then local callback=d.onClose;self.dialogue=nil;self.moveCooldown=.2;if callback then callback() end end
end
function Game:heal()
  for _,c in ipairs(self.state.party) do Creature.heal(c) end
  Audio.play('heal');self:save(true)
end
function Game:interact()
  local p=self.state.player;local delta=directions[p.direction];local tx,ty=p.x+delta[1],p.y+delta[2];local found
  for _,npc in ipairs(self:zone().npcs or {}) do if npc.x==tx and npc.y==ty then found=npc;break end end
  if not found then
    for _,npc in ipairs(self:zone().npcs or {}) do if math.abs(p.x-npc.x)+math.abs(p.y-npc.y)<=1 then found=npc;break end end
  end
  if not found then self:notify('Face a person or sign and press E to interact.');return end
  self:interactNPC(found)
end
function Game:interactNPC(npc)
  local s=self.state
  if npc.kind=='healer' then self:heal();self:talk(npc.name,{'A little rest works wonders. Your entire party is healthy again.','Come back any time. There is always room by the lantern.'});return end
  if npc.kind=='shop' then self.scene='shop';self.shopName=npc.name;self.shopIndex=1;Audio.play('confirm');return end
  if npc.kind=='trainer' or npc.kind=='boss' then
    if s.defeated[npc.id] then self:talk(npc.name,npc.afterText or {'The way you and your companions work together... that is what Aster needs. Keep going.'});return end
    if npc.bossIndex and self:badgeCount()<npc.bossIndex-1 then self:talk(npc.name,{'The Beacon must be restored in order. Earn the trust of the earlier wardens, then return to me.'});return end
    self:talk(npc.name,npc.text or {'Show me the bond you share with your companions.'},function() self:startTrainer(npc) end);return
  end
  if npc.kind=='professor' and self:badgeCount()>=4 then self:talk(npc.name,{'You brought the light home. I knew you would find something extraordinary, but I never expected a sky full of new stars.','Aetherion has returned to the Observatory grass. There are always new friendships to make.'});return end
  self:talk(npc.name,npc.text or {'The stars are bright tonight.'})
end
function Game:move(direction)
  if self.scene~='world' or self.dialogue or self.moveCooldown>0 then return end
  local p=self.state.player;p.direction=direction;local d=directions[direction];local x,y=p.x+d[1],p.y+d[2];local z=self:zone()
  self.moveCooldown=.145
  if not World.isWalkable(z,x,y) then return end
  for _,npc in ipairs(z.npcs or {}) do if npc.x==x and npc.y==y then return end end
  self.prevX,self.prevY=p.x,p.y;p.x,p.y=x,y;self.moveTween=1;self.state.steps=self.state.steps+1
  for _,portal in ipairs(z.portals or {}) do
    if portal.x==x and portal.y==y then
      if self:badgeCount()<(portal.requires or 0) then
        p.x,p.y=self.prevX,self.prevY;self.moveTween=0
        self:talk('BEACON GATE',{'This path needs '..tostring(portal.requires)..' Beacon Seals. Earn the next warden’s trust to open the way.'});return
      end
      self:travel(portal.to,portal.tx,portal.ty);return
    end
  end
  if World.tile(z,x,y)==',' and self.state.steps-(self.lastEncounter or 0)>5 and math.random()<.115 then self.lastEncounter=self.state.steps;self:startWild() end
end
function Game:travel(zoneId,x,y)
  local z=World.zones[zoneId];local p=self.state.player
  p.zone=zoneId;p.x=x or z.spawn.x;p.y=y or z.spawn.y;self.moveTween=0;self.moveCooldown=.3
  self.state.visited[zoneId]=true;self:notify(z.name..'  ·  '..z.subtitle);self:save(true)
end
function Game:rollEncounter()
  local entries={};local total=0
  for _,e in ipairs(self:zone().encounters or {}) do
    if not e.requiresEnding or self.state.ending then entries[#entries+1]=e;total=total+(e.weight or 1) end
  end
  if #entries==0 then return nil end
  local roll=math.random()*total;local chosen=entries[#entries]
  for _,e in ipairs(entries) do roll=roll-(e.weight or 1);if roll<=0 then chosen=e;break end end
  return Creature.create(chosen.species,math.random(chosen.min,chosen.max))
end
function Game:startWild(enemy)
  enemy=enemy or self:rollEncounter();if not enemy then return end
  if not Creature.firstAlive(self.state.party) then self:rescue();return end
  self:save(true);self.battleLogScroll=0
  self.battle=Battle.new(self.state.party,{enemy},{wild=true,rng=math.random})
  self.battleNPC=nil;self.scene='battle';self.battleCooldown=.35;self.battleEffect=0;self.battleMenu='moves';self.state.seen[enemy.species]=true;Audio.play('confirm')
end
function Game:startTrainer(npc)
  if not Creature.firstAlive(self.state.party) then self:rescue();return end
  local enemies={};for _,entry in ipairs(npc.party or {}) do enemies[#enemies+1]=Creature.create(entry.species,entry.level);self.state.seen[entry.species]=true end
  self:save(true);self.battleLogScroll=0
  self.battle=Battle.new(self.state.party,enemies,{wild=false,rng=math.random,trainerName=npc.name,reward=npc.reward or 100,bossId=npc.id})
  self.battleNPC=npc;self.scene='battle';self.battleCooldown=.35;self.battleEffect=0;self.battleMenu='moves'
end
function Game:battleAct(action)
  if self.scene~='battle' or self.battle.outcome or self.battleCooldown>0 then return end
  if action.kind=='catch' and #self.state.party>=6 and #self.state.storage>=500 then self:notify('The sanctuary is full. Release a stored companion from your journal first.');return end
  local ok=Battle.act(self.battle,action,self.state.bag)
  self.battleLogScroll=0
  if ok then
    self.battleCooldown=.45;self.battleEffect=.45;self.lastBattleAction=action.kind;self.battleMenu='moves';Audio.play(action.kind=='catch' and 'catch' or action.kind=='item' and 'heal' or 'hit')
    for _,c in ipairs(self.battle.enemies) do self.state.seen[c.species]=true end
    for _,c in ipairs(self.state.party) do self.state.caught[c.species]=true;self.state.seen[c.species]=true end
    if self.battle.outcome=='win' then Audio.play('win') end
  else Audio.play('cancel') end
end
function Game:addCompanion(c)
  self.state.caught[c.species]=true;self.state.seen[c.species]=true
  if #self.state.party<6 then self.state.party[#self.state.party+1]=c;return 'joined your party' end
  self.state.storage[#self.state.storage+1]=c;return 'is resting at the sanctuary'
end
function Game:finishBattle()
  local b=self.battle;if not b or not b.outcome then return end
  local s=self.state;local npc=self.battleNPC;self.scene='world';self.moveCooldown=.4;self.battle=nil;self.battleNPC=nil
  if b.outcome=='lose' then self:rescue();return end
  if b.outcome=='caught' and b.caught then
    local destination=self:addCompanion(b.caught);self:notify(Creature.name(b.caught)..' '..destination..'.');Audio.play('catch')
  elseif b.outcome=='win' then
    local reward=npc and (npc.reward or 100) or math.random(12,30);s.money=s.money+reward
    if npc then s.defeated[npc.id]=true end
    if npc and npc.bossIndex then
      local boss=World.bosses[npc.bossIndex];s.badges[npc.bossIndex]=boss.id or npc.id;s.bag.orbs=s.bag.orbs+4;s.bag.tonics=s.bag.tonics+2
      for _,c in ipairs(s.party) do Creature.gainXP(c,Creature.xpNeeded(c.level)*.5);Creature.heal(c);s.caught[c.species]=true;s.seen[c.species]=true end
      local lines={boss.badge..' earned. The Beacon carries your light a little farther.','Your party is fully restored. You received '..reward..' crowns, 4 binding orbs, and 2 tonics.'}
      if npc.bossIndex==4 then
        s.ending=true;self:save(true)
        self:talk(npc.name,{'Listen. The Beacon is singing again.','We thought the light belonged to the wardens. It was always the bond between us, waiting for someone to bring it together.','Aster will remember this journey. And somewhere above us, Aetherion is finally free to roam.'},function() self.scene='ending';Audio.play('win') end)
      else self:talk(npc.name,lines) end
    else self:notify('Victory! Earned '..reward..' crowns.') end
  end
  self:save(true)
end
function Game:rescue()
  local lost=math.floor(self.state.money*.1);self.state.money=self.state.money-lost
  for _,c in ipairs(self.state.party) do Creature.heal(c) end
  self:travel(World.start.zone,World.start.x,World.start.y)
  self:talk('HARBOR RESCUE',{'Your companions carried you safely back to Hearth Harbor. Everyone is healthy again.','The journey continues. '..lost..' crowns covered the rescue boat. Try a different type, catch a new companion, or use a tonic in battle.'})
  self:save(true)
end
function Game:openJournal(tab)
  if self.scene~='world' or self.dialogue then return end
  self.scene='journal';self.journalTab=tab or 1;self.journalIndex=1;self.storageMode=false;Audio.play('confirm')
end
function Game:setJournalTab(tab) self.journalTab=tab;self.journalIndex=1;self.storageMode=false;Audio.play('confirm') end
function Game:journalAction(index)
  local s=self.state
  if self.journalTab==1 then
    if self.storageMode then
      local c=s.storage[index];if not c then return end
      if #s.party<6 then table.remove(s.storage,index);s.party[#s.party+1]=c;self:notify(Creature.name(c)..' joined the party.')
      else s.storage[index],s.party[self.selectedParty or 1]=s.party[self.selectedParty or 1],c;self:notify('Companions exchanged with the sanctuary.') end
      self.storageMode=false;self.journalIndex=1;self:save(true)
    else
      local c=s.party[index];if not c then return end
      if c.hp<=0 then self:notify('Visit a healer before making this companion your lead.');return end
      s.party[1],s.party[index]=s.party[index],s.party[1];self.journalIndex=1;self:notify(Creature.name(s.party[1])..' is now your lead companion.');Audio.play('confirm')
    end
  elseif self.journalTab==3 then self:useTonic(index)
  elseif self.journalTab==4 then
    local ids={'hearth','fernwood','embercoast','glasswater','moonwake','observatory'};local id=ids[index]
    if id and s.visited[id] then self.scene='world';self:travel(id);Audio.play('confirm') else self:notify('Visit this region on foot to unlock the wayfarer route.') end
  elseif self.journalTab==5 then
    if index==1 then self:save() elseif index==2 then Audio.setMuted(not Audio.isMuted()) else self:save(true);self.scene='title';self.hasSave=Save.exists() end
  end
end
function Game:useTonic(index)
  local c=self.state.party[index];if not c then return end
  if self.state.bag.tonics<=0 then self:notify('No tonics left. Visit a provisioner.');return end
  local max=Creature.stats(c).hp;if c.hp>=max then self:notify('Already at full health.');return end
  self.state.bag.tonics=self.state.bag.tonics-1;c.hp=math.min(max,c.hp+35);Audio.play('heal');self:notify(Creature.name(c)..' recovered 35 HP.');self:save(true)
end
function Game:releaseStorage()
  local index=self.journalIndex;local c=self.state.storage[index];if not self.storageMode or not c then return end
  if self.releaseConfirm~=index then self.releaseConfirm=index;self:notify('Press Release again to return '..Creature.name(c)..' to the wild.');return end
  table.remove(self.state.storage,index);self.releaseConfirm=nil;self.journalIndex=math.max(1,math.min(index,#self.state.storage));self:notify(Creature.name(c)..' returned to the wild.');self:save(true)
end
function Game:buy(index)
  local items={{key='orbs',price=25,name='Binding orb'},{key='tonics',price=35,name='Trail tonic'}};local item=items[index];if not item then return end
  if self.state.money<item.price then self:notify('You need '..item.price..' crowns. Trainers and wild battles earn crowns.');Audio.play('cancel');return end
  self.state.money=self.state.money-item.price;self.state.bag[item.key]=self.state.bag[item.key]+1;self:notify(item.name..' added to your bag.');Audio.play('confirm');self:save(true)
end
function Game:update(dt)
  self.time=self.time+dt;self.moveCooldown=math.max(0,self.moveCooldown-dt);self.moveTween=math.max(0,self.moveTween-dt/.145)
  self.battleCooldown=math.max(0,self.battleCooldown-dt);self.battleEffect=math.max(0,(self.battleEffect or 0)-dt)
  if self.toast then self.toast.left=self.toast.left-dt;if self.toast.left<=0 then self.toast=nil end end
  if self.state and self.scene~='title' and self.scene~='starter' then self.state.playtime=self.state.playtime+dt end
  Audio.update(dt,self.scene=='battle' and 'battle' or self.scene=='ending' and 'ending' or self.scene=='title' and 'title' or 'overworld')
  if self.scene=='world' and not self.dialogue and self.moveCooldown<=0 then
    for _,pair in ipairs({{'up','w'},{'down','s'},{'left','a'},{'right','d'}}) do if love.keyboard.isDown(pair[1],pair[2]) then self:move(pair[1]);break end end
  end
end
function Game:keypressed(key)
  if key=='m' then Audio.setMuted(not Audio.isMuted());self:notify(Audio.isMuted() and 'Sound muted.' or 'Sound on.');return end
  if key=='f5' then self:save();return end
  if self.dialogue then if key=='return' or key=='space' or key=='e' then self:advanceDialogue() end;return end
  if self.scene=='title' then
    if key=='up' or key=='w' or key=='down' or key=='s' then self.menuIndex=self.menuIndex==1 and 2 or 1
    elseif key=='return' or key=='space' then if self.hasSave and self.menuIndex==1 then self:continueGame() else self:startNew() end end
  elseif self.scene=='starter' then
    if key=='left' or key=='a' then self.starterIndex=(self.starterIndex-2)%3+1
    elseif key=='right' or key=='d' then self.starterIndex=self.starterIndex%3+1
    elseif key=='return' or key=='space' or key=='e' then self:chooseStarter(self.starterIndex) end
  elseif self.scene=='world' then
    if keys[key] then self:move(keys[key]) elseif key=='e' or key=='space' or key=='return' then self:interact()
    elseif key=='tab' or key=='escape' then self:openJournal() end
  elseif self.scene=='battle' then
    local b=self.battle
    if key=='up' or key=='w' then self:wheelmoved(1);return elseif key=='down' or key=='s' then self:wheelmoved(-1);return end
    if b.outcome then if key=='return' or key=='space' or key=='e' then self:finishBattle() end;return end
    if tonumber(key) and tonumber(key)>=1 and tonumber(key)<=4 then
      if self.battleMenu=='switch' then self:battleAct({kind='switch',index=tonumber(key)}) else self:battleAct({kind='move',index=tonumber(key)}) end
    elseif self.battleMenu=='switch' and (key=='5' or key=='6') then self:battleAct({kind='switch',index=tonumber(key)})
    elseif key=='c' then self:battleAct({kind='catch'}) elseif key=='t' then self:battleAct({kind='item',item='tonic'})
    elseif key=='r' then self:battleAct({kind='run'}) elseif key=='q' then self.battleMenu=self.battleMenu=='switch' and 'moves' or 'switch'
    elseif key=='escape' then self.battleMenu='moves' elseif key=='return' or key=='space' then self:battleAct({kind='move',index=1}) end
  elseif self.scene=='journal' then
    if key=='tab' or key=='escape' then if self.storageMode then self.storageMode=false;self.journalIndex=1 else self.scene='world';self.moveCooldown=.2 end
    elseif key=='left' or key=='a' then self:setJournalTab((self.journalTab-2)%5+1)
    elseif key=='right' or key=='d' then self:setJournalTab(self.journalTab%5+1)
    elseif key=='up' or key=='w' then self.releaseConfirm=nil;self.journalIndex=math.max(1,self.journalIndex-1)
    elseif key=='down' or key=='s' then self.releaseConfirm=nil;self.journalIndex=math.min(self:journalLength(),self.journalIndex+1)
    elseif key=='return' or key=='space' or key=='e' then self:journalAction(self.journalIndex)
    elseif key=='delete' and self.storageMode then self:releaseStorage()
    elseif key=='x' and self.journalTab==1 then self.selectedParty=self.journalIndex;self.storageMode=not self.storageMode;self.journalIndex=1 end
  elseif self.scene=='shop' then
    if key=='escape' or key=='tab' then self.scene='world';self.moveCooldown=.2
    elseif key=='1' then self:buy(1) elseif key=='2' then self:buy(2)
    elseif key=='up' or key=='down' or key=='w' or key=='s' then self.shopIndex=3-self.shopIndex
    elseif key=='return' or key=='space' then self:buy(self.shopIndex) end
  elseif self.scene=='ending' then if key=='return' or key=='space' or key=='e' then self.scene='world';self:notify('The whole archipelago is open. Your journey continues.');self:save(true) end end
end
function Game:journalLength()
  if self.journalTab==1 then return math.max(1,self.storageMode and #self.state.storage or #self.state.party)
  elseif self.journalTab==2 then return #Screens.speciesOrder elseif self.journalTab==3 then return #self.state.party elseif self.journalTab==4 then return 6 else return 3 end
end
function Game:wheelmoved(y)
  if self.scene=='journal' then self.journalIndex=math.max(1,math.min(self:journalLength(),self.journalIndex-y))
  elseif self.scene=='battle' then self.battleLogScroll=math.max(0,math.min(math.max(0,#self.battle.log-5),(self.battleLogScroll or 0)+y)) end
end
function Game:draw() Screens.draw(self) end
return Game
