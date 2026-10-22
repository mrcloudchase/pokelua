local U=require('src.render.ui')
local Art=require('src.render.art')
local Data=require('src.data.creatures')
local Creature=require('src.systems.creature')
local Battle=require('src.systems.battle')
local World=require('src.data.world')
local Audio=require('src.systems.audio')
local S={speciesOrder={}}
for id in pairs(Data.species) do S.speciesOrder[#S.speciesOrder+1]=id end
table.sort(S.speciesOrder,function(a,b)return Data.species[a].name<Data.species[b].name end)
local zoneOrder={'hearth','fernwood','embercoast','glasswater','moonwake','observatory'}
local function typeColor(t) return Data.typeColors[t] or U.c.muted end
local function heading(eyebrow,title,subtitle)
  U.text(eyebrow,48,28,12,U.c.mint);U.text(title,48,52,32)
  if subtitle then U.text(subtitle,48,101,15,U.c.muted) end
end
local function footer(text) U.text(text,32,768,13,U.c.muted,1216,'center') end
local function hp(c,x,y,w,showNumbers)
  local max=Creature.stats(c).hp;local ratio=c.hp/max
  U.bar(x,y,w,8,ratio,U.hpColor(ratio))
  if showNumbers then U.text(c.hp..' / '..max..' HP',x,y+15,12,U.c.muted,w,'right') end
end
local function statPanel(c,x,y,w)
  U.panel(x,y,w,100)
  U.text(Creature.name(c),x+20,y+14,22);U.text('Lv. '..c.level,x+w-90,y+19,16,U.c.gold)
  U.pill(Data.species[c.species].type,x+20,y+46,typeColor(Data.species[c.species].type),76)
  hp(c,x+110,y+47,w-134,true)
end
function S.title(g)
  Art.background(1280,800,g.time)
  U.rect(0,0,640,800,{.025,.035,.075,.70})
  U.pill('AN ORIGINAL LUA ADVENTURE',80,106,U.c.mint,236)
  U.text('PokéLua',74,162,76)
  U.text('A whole world.\nOne shared sky.',80,270,32,U.c.mint,510)
  U.text('Find your companion. Follow the light.\nExplore the Aster Archipelago in a creature\nadventure written entirely in Lua.',80,371,18,{.76,.81,.88},490)
  if g.hasSave then
    U.button('Continue journey  >',80,496,348,58,function()g:continueGame()end,{selected=g.menuIndex==1,size=18})
    U.button('Begin a new journey',80,566,348,52,function()g:startNew()end,{selected=g.menuIndex==2,color=U.c.muted})
  else
    U.button('Begin your journey  >',80,506,348,62,function()g:startNew()end,{selected=true,size=18})
    U.text('Built entirely in Lua. Made for adventure.',80,586,13,U.c.muted)
  end
  Art.creature('spriglet',842,414,240,{time=g.time})
  Art.creature('cindercub',1088,536,182,{time=g.time+1})
  Art.creature('dripple',735,605,166,{time=g.time+2})
  U.text('THE ASTER ARCHIPELAGO',790,676,12,{.71,.77,.85},400,'center')
  U.text('36 companions   /   6 regions   /   4 wardens',80,714,14,{.74,.81,.84})
  U.text('LÖVE 11  ·  Made of Lua, light & a little curiosity',80,749,12,U.c.muted)
  U.button(Audio.isMuted() and 'Sound off [M]' or 'Sound on [M]',1080,24,174,35,function()Audio.setMuted(not Audio.isMuted())end,{size=13})
end
function S.starter(g)
  Art.background(1280,800,g.time*.25);U.rect(0,0,1280,800,{.025,.035,.075,.82})
  heading('CHAPTER 01  /  A FIRST FRIEND','Every journey begins with a bond.','Three companions. Three ways to meet the world. Choose the one that feels like you.')
  local moods={'A gentle heart. A wild spirit.','A little spark. A lot of courage.','Slow steps. Deep friendships.'}
  for i,id in ipairs(Data.starters) do
    local sp=Data.species[id];local x=60+(i-1)*392;local selected=i==g.starterIndex
    U.panel(x,174,376,476,selected)
    if selected then U.color(U.c.mint);love.graphics.setLineWidth(2);love.graphics.rectangle('line',x+1,175,374,474,12,12);love.graphics.setLineWidth(1) end
    U.text('0'..i,x+24,195,13,selected and U.c.mint or U.c.muted)
    U.pill(sp.type,x+270,192,typeColor(sp.type),82)
    U.color(typeColor(sp.type),.06);love.graphics.circle('fill',x+188,344,112)
    Art.creature(id,x+188,341,190,{time=g.time+i})
    U.text(sp.name,x+24,458,28,nil,328,'center')
    U.text(moods[i],x+24,502,15,U.c.mint,328,'center')
    U.text(sp.description,x+28,542,14,U.c.muted,320,'center')
    U.button(selected and 'Chosen companion' or 'Choose '..sp.name,x+24,603,328,32,function()g.starterIndex=i;Audio.play('confirm')end,{selected=selected,size=13})
  end
  U.button('Travel with '..Data.species[Data.starters[g.starterIndex]].name..'  >',410,684,460,54,function()g:chooseStarter(g.starterIndex)end,{selected=true,size=18})
  footer('Left/Right choose a companion    ·    Enter begin    ·    Every starter can complete the journey')
end
local buildingCache={}
local function buildings(z)
  if buildingCache[z.id] then return buildingCache[z.id] end
  local result,seen={},{}
  for y=1,z.height do for x=1,z.width do
    if World.tile(z,x,y)=='b' and not seen[x..','..y] then
      local q={{x,y}};seen[x..','..y]=true;local head=1;local minX,maxX,minY,maxY=x,x,y,y
      while q[head] do
        local p=q[head];head=head+1;minX=math.min(minX,p[1]);maxX=math.max(maxX,p[1]);minY=math.min(minY,p[2]);maxY=math.max(maxY,p[2])
        for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
          local xx,yy=p[1]+d[1],p[2]+d[2];local k=xx..','..yy
          if not seen[k] and World.tile(z,xx,yy)=='b' then seen[k]=true;q[#q+1]={xx,yy} end
        end
      end
      result[#result+1]={x=minX,y=minY,w=maxX-minX+1,h=maxY-minY+1}
    end
  end end
  buildingCache[z.id]=result;return result
end
function S.world(g)
  local z=g:zone();local p=g.state.player;local x0,y0,vw,vh=20,88,928,640;local tileSize=32
  U.text('POKÉLUA',24,20,20,U.c.mint);U.line(159,18,159,62,U.c.border)
  U.text(z.name,182,15,24);U.text(z.subtitle,183,47,12,U.c.muted)
  for i=1,4 do
    local b=World.bosses[i];local earned=i<=g:badgeCount();local x=1067+(i-1)*49
    U.color(earned and U.c.gold or U.c.border);love.graphics.polygon('fill',x,22,x+10,34,x,46,x-10,34)
    if earned then U.color(U.c.bg);love.graphics.circle('fill',x,34,3) end
  end
  U.text('BEACON SEALS',1020,56,11,U.c.muted,224,'center')
  U.rect(x0-2,y0-2,vw+4,vh+4,U.c.border,10)
  local px=p.x-1;local py=p.y-1
  if g.moveTween>0 and g.prevX and g.prevY then px=px+(g.prevX-p.x)*g.moveTween;py=py+(g.prevY-p.y)*g.moveTween end
  local camX=math.max(0,math.min(z.width*32-vw,px*32+16-vw/2));local camY=math.max(0,math.min(z.height*32-vh,py*32+16-vh/2))
  U.clip(x0,y0,vw,vh)
  U.rect(x0,y0,vw,vh,z.palette.grass)
  for row=math.max(1,math.floor(camY/32)+1),math.min(z.height,math.ceil((camY+vh)/32)) do
    for col=math.max(1,math.floor(camX/32)+1),math.min(z.width,math.ceil((camX+vw)/32)) do
      local tile=World.tile(z,col,row)
      Art.tile(tile=='b' and '.' or tile,x0+(col-1)*32-camX,y0+(row-1)*32-camY,32,z.palette,g.time,col*23+row*13)
    end
  end
  for _,b in ipairs(buildings(z)) do Art.building(x0+(b.x-1)*32-camX,y0+(b.y-1)*32-camY,b.w*32,b.h*32,z.palette,g.time) end
  for _,portal in ipairs(z.portals or {}) do
    local x=x0+(portal.x-.5)*32-camX;local y=y0+(portal.y-.5)*32-camY
    U.color((portal.requires or 0)>g:badgeCount() and U.c.coral or U.c.mint,.25+.12*math.sin(g.time*3));love.graphics.circle('fill',x,y,17)
    local dx,dy=portal.x<4 and -1 or portal.x>z.width-3 and 1 or 0,portal.y<4 and -1 or portal.y>z.height-3 and 1 or 0
    U.color(U.c.text);love.graphics.setLineWidth(2);love.graphics.line(x-dx*7,y-dy*7,x+dx*7,y+dy*7);love.graphics.line(x+dx*7,y+dy*7,x+dx*2-dy*5,y+dy*2+dx*5);love.graphics.line(x+dx*7,y+dy*7,x+dx*2+dy*5,y+dy*2-dx*5);love.graphics.setLineWidth(1)
  end
  local people={}
  for _,npc in ipairs(z.npcs or {}) do people[#people+1]={npc=npc,y=npc.y} end
  people[#people+1]={player=true,y=py+1};table.sort(people,function(a,b)return a.y<b.y end)
  for _,entry in ipairs(people) do
    if entry.player then
      local d=({up={0,1},down={0,-1},left={1,0},right={-1,0}})[p.direction]
      if World.isWalkable(z,p.x+d[1],p.y+d[2]) then Art.creature(g.state.party[1].species,x0+(px+d[1]+.5)*32-camX,y0+(py+d[2]+.5)*32-camY,25,{time=g.time}) end
      Art.player(x0+px*32-camX,y0+py*32-camY,32,p.direction,g.moveTween,g.time)
    else
      local npc=entry.npc;local x=x0+(npc.x-1)*32-camX;local y=y0+(npc.y-1)*32-camY
      Art.npc(npc,x,y,32,g.time)
      if (npc.kind=='boss' or npc.kind=='trainer') and not g.state.defeated[npc.id] then
        U.text('!',x+8,y-19,16,npc.kind=='boss' and U.c.gold or U.c.coral,16,'center')
      elseif npc.kind=='healer' then U.text('+',x+8,y-16,18,U.c.mint,16,'center') end
    end
  end
  for i=1,15 do local x=x0+(i*137+g.time*8)%vw;local y=y0+(i*89+math.sin(g.time+i)*12)%vh;U.color(z.palette.accent,.3);love.graphics.circle('fill',x,y,1.4) end
  if not g.dialogue then
    local near
    for _,npc in ipairs(z.npcs or {}) do if math.abs(p.x-npc.x)+math.abs(p.y-npc.y)<=1 then near=npc;break end end
    if near then U.panel(x0+20,y0+vh-66,450,46);U.text('[E]  '..near.name,x0+38,y0+vh-53,16,U.c.mint) end
  end
  U.unclip()
  U.pill(z.level and ('TRAIL LEVEL '..z.level) or 'ASTER FIELD GUIDE',36,104,U.c.text,150)
  U.panel(970,88,290,640)
  U.text('YOUR JOURNEY',992,108,12,U.c.mint)
  U.text(string.format('%04d',g.state.steps)..' steps',992,135,18)
  U.text(g.state.money..' crowns',992,164,14,U.c.gold)
  local lead=g.state.party[1]
  Art.creature(lead.species,1114,251,116,{time=g.time})
  U.text(Creature.name(lead),992,313,22,nil,246,'center')
  U.text(Data.species[lead.species].type..'  ·  Lv. '..lead.level,992,345,13,U.c.muted,246,'center')
  hp(lead,994,375,242,false)
  U.text('PARTY',992,405,11,U.c.muted)
  for i=1,6 do local x=1006+(i-1)*42;U.color(g.state.party[i] and (g.state.party[i].hp>0 and typeColor(Data.species[g.state.party[i].species].type) or U.c.coral) or U.c.border);love.graphics.circle('fill',x,439,12);if g.state.party[i] then U.text(tostring(i),x-10,431,12,U.c.bg,20,'center') end end
  U.line(992,467,1238,467,U.c.border)
  local title,objective=g:objective();U.text('NEXT CHAPTER',992,486,11,U.c.gold);U.text(title,992,510,18,nil,246);U.text(objective,992,550,14,U.c.muted,246)
  U.button('Field journal  [Tab]',990,625,250,42,function()g:openJournal()end,{color=U.c.mint})
  U.button('Save journey  [F5]',990,676,250,32,function()g:save()end,{size=13})
  U.text('WASD / arrows  move     E / Space  interact     Tab  journal',24,747,13,U.c.muted)
  U.text('Orbs '..g.state.bag.orbs..'   ·   Tonics '..g.state.bag.tonics,688,747,13,U.c.mint,258,'right')
  if g.dialogue then S.dialogue(g) end
end
function S.dialogue(g)
  local d=g.dialogue;local x,y,w=44,534,880
  U.rect(x-3,y-3,w+6,184,{.018,.025,.05,.5},14);U.panel(x,y,w,178,true)
  U.text(d.name:upper(),x+24,y+17,12,U.c.mint)
  U.text(d.lines[d.index],x+24,y+45,18,U.c.text,w-48)
  U.text(d.index..' / '..#d.lines,x+24,y+145,12,U.c.muted)
  U.button(d.index==#d.lines and 'Continue  [E]  >' or 'Next  [E]  >',x+w-218,y+134,196,30,function()g:advanceDialogue()end,{size=13,color=U.c.mint})
end
local function battleLandscape(g)
  local z=g:zone();U.rect(0,0,1280,800,U.c.bg)
  for i=0,20 do local n=i/20;U.rect(0,72+i*18,1280,19,{.08+n*.05,.105+n*.04,.19+n*.04}) end
  for i=1,40 do local x=(i*193)%1280;local y=95+(i*71)%210;U.color(U.c.text,.15+.25*math.abs(math.sin(g.time+i)));love.graphics.circle('fill',x,y,i%3==0 and 2 or 1) end
  U.color(z.palette.accent,.08);love.graphics.circle('fill',1020,214,132)
  U.color(z.palette.grass,.65);love.graphics.ellipse('fill',1030,510,810,170)
  U.color(z.palette.grass,.3);love.graphics.ellipse('fill',180,586,530,150)
  U.color(z.palette.accent,.14);love.graphics.ellipse('fill',887,389,213,45);love.graphics.ellipse('fill',370,530,239,55)
  U.color(z.palette.accent,.4);love.graphics.ellipse('line',887,389,215,46);love.graphics.ellipse('line',370,530,242,55)
end
function S.battle(g)
  local b=g.battle;local ally=b.party[b.active];local enemy=b.enemies[b.enemyActive];battleLandscape(g)
  U.text('POKÉLUA / ENCOUNTER',28,24,12,U.c.mint)
  U.text(b.wild and 'A wild connection' or b.trainerName or 'A traveler’s challenge',28,44,22)
  U.pill(b.wild and 'WILD ENCOUNTER' or (g.battleNPC and g.battleNPC.bossIndex and 'WARDEN CHALLENGE' or 'TRAVELER CHALLENGE'),1018,29,b.wild and U.c.mint or U.c.gold,234)
  statPanel(enemy,740,111,474)
  for i,c in ipairs(b.enemies) do U.color(c.hp>0 and U.c.coral or U.c.border);love.graphics.circle('fill',1194-(i-1)*20,229,5) end
  local bump=(g.battleEffect or 0)>0 and math.sin(g.battleEffect*50)*5 or 0
  Art.creature(enemy.species,892+bump,330,236,{time=g.time,ghost=enemy.hp<=0})
  Art.creature(ally.species,362-bump,428,280,{time=g.time,back=true,ghost=ally.hp<=0})
  if (g.battleEffect or 0)>0 then
    local progress=1-g.battleEffect/.45
    if g.lastBattleAction=='catch' then Art.orb(362+530*progress,410-150*math.sin(progress*math.pi),15,g.time)
    elseif g.lastBattleAction=='item' then
      U.color(U.c.mint,1-progress);love.graphics.setLineWidth(3);love.graphics.circle('line',362,420,35+progress*90);love.graphics.setLineWidth(1)
    else
      U.color(U.c.gold,1-progress)
      for i=1,8 do local a=i*math.pi/4;local r=25+progress*85;love.graphics.line(892+math.cos(a)*r,330+math.sin(a)*r,892+math.cos(a)*(r+18),330+math.sin(a)*(r+18)) end
    end
  end
  statPanel(ally,32,111,370)
  U.text('EXPERIENCE',52,231,11,U.c.muted)
  U.bar(52,252,326,5,ally.xp/Creature.xpNeeded(ally.level),U.c.purple)
  for i,c in ipairs(b.party) do U.color(c.hp>0 and typeColor(Data.species[c.species].type) or U.c.border);love.graphics.circle('fill',58+(i-1)*23,277,6) end
  U.panel(26,563,530,201)
  U.text('BATTLE NOTES',46,581,11,U.c.mint)
  -- Keep the whole turn readable; the newest five messages fit without a scroll trap.
  U.text('Up/Down scroll notes',388,581,11,U.c.muted)
  local last=math.max(1,#b.log-(g.battleLogScroll or 0))
  local first=math.max(1,last-4)
  for i=first,last do U.text(b.log[i],46,610+(i-first)*26,14,U.c.text,488) end
  if b.outcome then
    U.panel(574,563,680,201,true)
    local titles={win='A bond shines brighter.',lose='Every journey has a pause.',caught='A new companion. A new chapter.',fled='A little room to breathe.'}
    U.text(titles[b.outcome] or 'Encounter complete',600,586,24,b.outcome=='lose' and U.c.coral or U.c.mint,628)
    U.text(b.outcome=='caught' and 'Your companion will join the party, or rest at the sanctuary if your party is full.' or b.outcome=='win' and 'Your companions gained experience. Take the next step together.' or b.outcome=='lose' and 'A rescue boat will bring everyone safely home.' or 'The tall grass will be here when you are ready.',600,632,15,U.c.muted,610)
    U.button('Continue your journey  [Enter]  >',600,704,628,42,function()g:finishBattle()end,{selected=true})
  else
    U.panel(574,563,680,201)
    if g.battleMenu=='switch' then
      U.text('CHOOSE A COMPANION  ·  Q TO RETURN',594,580,11,U.c.mint)
      for i,c in ipairs(b.party) do local idx=i;local x=594+((i-1)%3)*215;local y=611+math.floor((i-1)/3)*65
        U.button(i..'  '..Creature.name(c)..'\nLv. '..c.level..'  ·  '..c.hp..' HP',x,y,204,56,function()g:battleAct({kind='switch',index=idx})end,{size=13,disabled=c.hp<=0 or i==b.active})
      end
      if #b.party==1 then U.text('Catch wild companions to grow your party.',594,688,15,U.c.muted) end
    else
      for i=1,4 do local id=ally.moves[i];local m=id and Data.moves[id];local x=594+((i-1)%2)*322;local y=578+math.floor((i-1)/2)*58
        if m then
          local index=i;local ratio=Battle.effectiveness(m.type,Data.species[enemy.species].type)
          local hint=m.kind=='damage' and (ratio>1 and '  Strong' or ratio<1 and '  Resisted' or '') or ''
          U.button(i..'  '..m.name..'   ·   '..m.type..hint,x,y,310,48,function()g:battleAct({kind='move',index=index})end,{size=14,color=typeColor(m.type)})
        else U.button('—',x,y,310,48,function()end,{disabled=true}) end
      end
      U.button('C  Orb · '..g.state.bag.orbs,594,704,149,40,function()g:battleAct({kind='catch'})end,{size=13,disabled=not b.wild})
      U.button('T  Tonic · '..g.state.bag.tonics,753,704,149,40,function()g:battleAct({kind='item',item='tonic'})end,{size=13})
      U.button('Q  Switch',912,704,149,40,function()g.battleMenu='switch'end,{size=13})
      U.button('R  Leave',1071,704,149,40,function()g:battleAct({kind='run'})end,{size=13,disabled=not b.wild})
    end
  end
  U.text('Weaken wild companions before offering an orb. Elemental matches matter.',28,779,12,U.c.muted)
end
local function companionRows(g,list,first,x,y,w,bag)
  for row=1,6 do
    local i=first+row-1;local c=list[i]
    if c then
      local idx=i;local yy=y+(row-1)*75;local sp=Data.species[c.species]
      U.button('',x,yy,w,66,function()g.journalIndex=idx;g.releaseConfirm=nil end,{selected=i==g.journalIndex})
      Art.creature(c.species,x+39,yy+34,49,{time=g.time})
      U.text(Creature.name(c),x+77,yy+10,18);U.text('Lv. '..c.level..'   '..sp.type,x+77,yy+37,12,U.c.muted)
      U.text(c.hp..' / '..Creature.stats(c).hp,x+w-115,yy+13,12,c.hp>0 and U.c.mint or U.c.coral,96,'right')
      hp(c,x+w-110,yy+39,90,false)
    end
  end
end
function S.party(g)
  local s=g.state;local list=g.storageMode and s.storage or s.party;local first=math.max(1,g.journalIndex-5)
  U.text(g.storageMode and ('SANCTUARY  /  '..#s.storage..' COMPANIONS') or ('TRAVELING PARTY  /  '..#s.party..' OF 6'),48,225,12,U.c.mint)
  companionRows(g,list,first,48,254,470)
  local c=list[g.journalIndex];U.panel(540,225,692,482)
  if c then
    local sp=Data.species[c.species];local stats=Creature.stats(c)
    U.text(Creature.name(c),566,244,28);U.pill(sp.type,1086,248,typeColor(sp.type),120)
    U.text('Lv. '..c.level..'   ·   '..(c.hp>0 and 'Ready to explore' or 'Needs a rest'),568,285,14,U.c.muted)
    U.color(typeColor(sp.type),.06);love.graphics.circle('fill',710,432,122)
    Art.creature(c.species,711,427,210,{time=g.time})
    U.text(sp.description,566,576,15,U.c.muted,290)
    local sx=876;U.text('COMPANION STATS',sx,329,11,U.c.mint)
    for i,v in ipairs({{'HP',stats.hp},{'Attack',stats.attack},{'Defense',stats.defense},{'Speed',stats.speed}}) do
      local yy=352+(i-1)*29;U.text(v[1],sx,yy,14,U.c.muted);U.text(v[2],sx+200,yy,14,nil,104,'right')
    end
    U.text('TECHNIQUES',sx,482,11,U.c.mint)
    for i,id in ipairs(c.moves) do local m=Data.moves[id];U.text(m.name,sx,506+(i-1)*30,14,typeColor(m.type));U.text(m.kind=='damage' and tostring(m.power)..' PWR' or m.kind:upper(),sx+208,508+(i-1)*30,11,U.c.muted,96,'right') end
    U.text('EXPERIENCE',568,662,11,U.c.purple);U.bar(676,668,260,5,c.xp/Creature.xpNeeded(c.level),U.c.purple)
    U.text(c.xp..' / '..Creature.xpNeeded(c.level),952,661,12,U.c.muted,254,'right')
  else
    U.text('A quiet place to rest.',580,365,28,nil,610,'center');U.text('When your party is full, new companions will wait for you here.\nSelect a party member before opening the sanctuary to choose\nwho they will exchange places with.',580,423,16,U.c.muted,610,'center')
  end
  U.button(g.storageMode and 'Return to party  [X]' or ('Sanctuary  ·  '..#s.storage..'  [X]'),48,720,470,40,function()g.selectedParty=g.journalIndex;g.storageMode=not g.storageMode;g.journalIndex=1;g.releaseConfirm=nil end,{color=U.c.mint,size=14})
  if c then
    local index=g.journalIndex
    if g.storageMode then
      U.button('Bring along / exchange  [Enter]',540,720,442,40,function()g:journalAction(index)end,{selected=true,size=14})
      U.button(g.releaseConfirm==index and 'Confirm release' or 'Release  [Del]',994,720,238,40,function()g:releaseStorage()end,{color=U.c.coral,size=14})
    else U.button('Make '..Creature.name(c)..' your lead  [Enter]',540,720,692,40,function()g:journalAction(index)end,{selected=true,size=14}) end
  end
end
function S.dex(g)
  local first=math.max(1,math.min(#S.speciesOrder-6,g.journalIndex-3))
  U.text('FIELD GUIDE  /  '..U.count(g.state.caught)..' OF '..#S.speciesOrder..' BONDED',48,225,12,U.c.mint)
  for row=1,7 do
    local index=first+row-1;local id=S.speciesOrder[index];local sp=Data.species[id];local seen=g.state.seen[id];local caught=g.state.caught[id];local y=252+(row-1)*65
    U.button('',48,y,426,57,function()g.journalIndex=index end,{selected=g.journalIndex==index})
    U.text(string.format('%02d',index),64,y+20,13,U.c.muted)
    if seen then Art.creature(id,122,y+29,43,{time=g.time}) end
    U.text(seen and sp.name or 'Unknown companion',157,y+16,18,seen and U.c.text or U.c.muted)
    U.color(caught and U.c.mint or U.c.muted);love.graphics.circle(caught and 'fill' or 'line',444,y+29,5)
  end
  local id=S.speciesOrder[g.journalIndex];local sp=Data.species[id];local seen=g.state.seen[id];local caught=g.state.caught[id]
  U.panel(494,225,738,501)
  U.text(string.format('FIELD NOTE %02d',g.journalIndex),520,247,12,U.c.muted)
  U.text(seen and sp.name or 'A friend you haven’t met.',520,275,28)
  if seen then U.pill(sp.type,1070,250,typeColor(sp.type),136) end
  U.color(seen and typeColor(sp.type) or U.c.purple,.05);love.graphics.circle('fill',715,465,142)
  if seen then Art.creature(id,715,462,247,{time=g.time}) else U.text('?',650,379,76,U.c.purple,130,'center') end
  U.text(caught and 'BONDED' or seen and 'SEEN IN THE WILD' or 'UNDISCOVERED',942,355,11,caught and U.c.mint or U.c.gold)
  U.text(seen and sp.description or 'Somewhere beneath this shared sky, another story is waiting to cross yours.',942,389,16,U.c.muted,256)
  if seen then
    U.text('NATURAL STRENGTHS',942,535,11,U.c.mint)
    for i,stat in ipairs({'hp','attack','defense','speed'}) do U.text(stat:upper(),942,562+(i-1)*30,11,U.c.muted);U.bar(1020,567+(i-1)*30,180,5,sp.base[stat]/75,typeColor(sp.type)) end
  end
  U.text('Every species can be found, befriended, or evolved.\nEvolution is recorded automatically in your field guide.',520,662,14,U.c.muted,380)
  U.text('Up/Down browse    ·    Mouse wheel scrolls the guide',48,742,13,U.c.muted)
end
function S.bag(g)
  U.text('TRAIL SUPPLIES',48,225,12,U.c.mint)
  U.panel(48,252,532,130);Art.orb(96,309,23,g.time)
  U.text('Binding orbs',146,275,22);U.text(g.state.bag.orbs..' in your bag',146,313,14,U.c.mint)
  U.text('Offer one to a weakened wild companion during\nbattle. Lower HP means a stronger chance to bond.',146,340,12,U.c.muted)
  U.panel(48,396,532,112)
  U.text('Trail tonics',72,417,22);U.text(g.state.bag.tonics..' remaining',355,423,14,U.c.mint)
  U.text('Restore 35 HP, including a tired companion.\nSelect a companion below, then press Enter to use one.',72,455,14,U.c.muted)
  for i,c in ipairs(g.state.party) do
    local idx=i;local x=48+((i-1)%2)*271;local y=524+math.floor((i-1)/2)*73
    U.button(Creature.name(c)..'  ·  '..c.hp..' HP',x,y,261,62,function()g.journalIndex=idx;g:useTonic(idx)end,{selected=g.journalIndex==i,size=14})
  end
  U.panel(600,225,632,514);U.text('A FIELD GUIDE TO ELEMENTS',626,248,12,U.c.mint)
  U.text('Look for the advantage.',626,278,28)
  U.text('A strong match deals double damage. A resisted match\ndeals half. Matching your own element adds a bonus.',626,326,15,U.c.muted)
  local strengths={Leaf='Tide, Stone',Ember='Leaf, Frost',Tide='Ember, Stone',Stone='Ember, Spark, Gale',Gale='Leaf',Spark='Tide, Gale',Shade='Astral',Frost='Leaf, Gale',Astral='Shade',Neutral='Steady against all'}
  for i,t in ipairs(Data.types) do
    local yy=391+(i-1)*31;U.pill(t,626,yy,typeColor(t),86);U.text('>  '..strengths[t],734,yy+4,14,U.c.muted)
  end
  U.text('Healers restore your whole party for free. Provisioners sell\norbs and tonics. Defeat travelers to earn more crowns.',626,706,12,U.c.muted)
end
function S.map(g)
  U.text('WAYFARER ROUTES',48,225,12,U.c.mint)
  for i,id in ipairs(zoneOrder) do
    local z=World.zones[id];local idx=i;local visited=g.state.visited[id];local y=254+(i-1)*77
    U.button('',48,y,490,67,function()g.journalIndex=idx end,{selected=g.journalIndex==i})
    U.text(string.format('%02d',i),67,y+24,13,visited and U.c.mint or U.c.muted)
    U.text(z.name,108,y+10,20,visited and U.c.text or U.c.muted)
    U.text(id==g.state.player.zone and 'You are here' or visited and 'Wayfarer route available' or 'Follow the trails to discover',108,y+39,12,id==g.state.player.zone and U.c.mint or U.c.muted)
  end
  U.panel(560,225,672,437)
  for i=1,20 do U.color(U.c.mint,.03);love.graphics.line(580,242+i*20,1212,242+i*20) end
  local pts={{650,566},{752,484},{904,536},{1061,458},{969,344},{1112,290}}
  for i=1,5 do U.color(U.c.border);love.graphics.setLineWidth(3);love.graphics.line(pts[i][1],pts[i][2],pts[i+1][1],pts[i+1][2]);love.graphics.setLineWidth(1) end
  for i,id in ipairs(zoneOrder) do
    local pos=pts[i];local visited=g.state.visited[id];local z=World.zones[id];local selected=g.journalIndex==i
    U.color(visited and z.palette.grass or U.c.raised);love.graphics.ellipse('fill',pos[1],pos[2],selected and 62 or 47,selected and 34 or 27)
    U.color(visited and U.c.mint or U.c.border);love.graphics.ellipse('line',pos[1],pos[2],selected and 63 or 48,selected and 35 or 28)
    U.color(id==g.state.player.zone and U.c.gold or visited and U.c.text or U.c.muted);love.graphics.circle('fill',pos[1],pos[2],5)
    U.text(z.name,pos[1]-82,pos[2]+38,12,visited and U.c.text or U.c.muted,164,'center')
  end
  U.text('THE ASTER ARCHIPELAGO',584,247,12,U.c.mint)
  local z=World.zones[zoneOrder[g.journalIndex]]
  U.text(z.subtitle,580,684,18,U.c.muted,632,'center')
  local visited=g.state.visited[z.id]
  U.button(visited and ('Travel to '..z.name..'  [Enter]') or 'Discover this region to unlock travel',560,720,672,40,function()g:journalAction(g.journalIndex)end,{selected=true,disabled=not visited,size=14})
end
function S.journey(g)
  local minutes=math.floor(g.state.playtime/60)
  U.panel(48,225,494,303)
  U.text('YOUR ASTER STORY',74,248,12,U.c.mint)
  U.text(g.state.ending and 'A sky made whole.' or 'The light is growing.',74,282,28)
  local stats={{'Companions bonded',U.count(g.state.caught)..' / 36'},{'Beacon Seals',g:badgeCount()..' / 4'},{'Time on the trail',math.floor(minutes/60)..'h '..minutes%60 ..'m'},{'Steps together',tostring(g.state.steps)},{'Crowns',tostring(g.state.money)}}
  for i,row in ipairs(stats) do U.text(row[1],74,340+(i-1)*31,14,U.c.muted);U.text(row[2],375,340+(i-1)*31,14,U.c.text,138,'right') end
  U.button('Save journey  [Enter]',48,551,494,52,function()g:journalAction(1)end,{selected=g.journalIndex==1,color=U.c.mint})
  U.button(Audio.isMuted() and 'Sound off  ·  Enable sound [M]' or 'Sound on  ·  Mute sound [M]',48,616,494,45,function()g:journalAction(2)end,{selected=g.journalIndex==2,size=14})
  U.button('Save & return to title',48,674,494,45,function()g:journalAction(3)end,{selected=g.journalIndex==3,size=14})
  for i,b in ipairs(World.bosses) do
    local earned=i<=g:badgeCount();local y=225+(i-1)*125
    U.panel(564,y,668,111,earned)
    U.color(earned and U.c.gold or U.c.border);love.graphics.polygon('fill',614,y+26,636,y+54,614,y+82,592,y+54)
    U.text(b.badge,662,y+17,22,earned and U.c.gold or U.c.muted)
    U.text(b.name..'   /   '..World.zones[b.zone].name,662,y+51,14,U.c.muted)
    U.text(earned and 'LIGHT RESTORED' or 'A TRUST STILL TO EARN',662,y+79,11,earned and U.c.mint or U.c.muted)
  end
  U.text('Saves are stored on this computer, with automatic backup recovery.',48,742,13,U.c.muted)
end
function S.journal(g)
  heading('THE ASTER FIELD JOURNAL','A record of a shared journey.','Companions, discoveries, and the little things you carry along the way.')
  U.button('Back to the trail  [Esc]',996,45,236,43,function()g.scene='world';g.moveCooldown=.2 end,{size=14})
  local tabs={'01   Party','02   Field guide','03   Bag','04   Map','05   Journey'}
  for i,label in ipairs(tabs) do local idx=i;U.button(label,48+(i-1)*238,157,226,45,function()g:setJournalTab(idx)end,{selected=g.journalTab==i,color=g.journalTab==i and U.c.mint or U.c.muted,size=15}) end
  ({S.party,S.dex,S.bag,S.map,S.journey})[g.journalTab](g)
  footer('Left/Right change section    ·    Up/Down select    ·    Enter confirm    ·    Tab / Esc return')
end
function S.shop(g)
  Art.background(1280,800,g.time*.3);U.rect(0,0,1280,800,{.025,.035,.075,.85})
  heading('THE PROVISIONER',g.shopName or 'A few things for the trail.','A little preparation makes room for a little more adventure.')
  U.pill(g.state.money..' CROWNS',1020,60,U.c.gold,212)
  local items={{name='Binding orb',desc='A small vessel for a new friendship.\nWeaken a wild companion, then offer an orb in battle.',price=25,key='orbs'},{name='Trail tonic',desc='A comforting blend of island herbs.\nRestores 35 HP to a companion, in or out of battle.',price=35,key='tonics'}}
  for i,item in ipairs(items) do
    local idx=i;local x=120+(i-1)*544;U.panel(x,218,496,436)
    if i==1 then Art.orb(x+248,327,48,g.time) else U.rect(x+221,280,54,88,{.4,.8,.7},12);U.rect(x+233,265,30,20,U.c.gold,4);U.text('+',x+226,299,40,U.c.bg,44,'center') end
    U.text(item.name,x+28,406,28,nil,440,'center')
    U.text(item.desc,x+30,457,15,U.c.muted,436,'center')
    U.text('In your bag: '..g.state.bag[item.key],x+30,531,14,U.c.mint,436,'center')
    U.button('Buy one  ·  '..item.price..' crowns  ['..i..']',x+28,586,440,44,function()g:buy(idx)end,{selected=g.shopIndex==i,disabled=g.state.money<item.price})
  end
  U.button('Back to the trail  [Esc]',440,701,400,45,function()g.scene='world';g.moveCooldown=.2 end,{size=15})
  footer('1 / 2 buy supplies    ·    You can always rest at a healer for free')
end
function S.ending(g)
  Art.background(1280,800,g.time)
  U.rect(0,0,1280,800,{.025,.035,.075,.66})
  for i=1,20 do U.color(U.c.gold,.4);local x=(i*197+g.time*17)%1280;local y=(i*79-g.time*35)%800;love.graphics.circle('fill',x,y,2) end
  U.text('THE BEACON SINGS AGAIN',0,75,13,U.c.gold,1280,'center')
  U.text('A sky made whole.',0,120,64,U.c.text,1280,'center')
  Art.creature('aetherion',640,379,290,{time=g.time})
  U.text('You followed a little light, and found a world of friends.',210,552,22,U.c.mint,860,'center')
  U.text('Four wardens. Six regions. One journey written in the bonds you made.\nThank you for exploring the Aster Archipelago. The trails are still yours.',210,599,16,{.75,.81,.89},860,'center')
  U.button('Keep exploring  [Enter]  >',420,692,440,52,function()g.scene='world';g:save(true);g:notify('Aetherion now roams the Observatory. Your journey continues.')end,{selected=true,size=18})
  U.text('POKÉLUA  /  AN ORIGINAL ADVENTURE BUILT WITH LUA & LÖVE',0,767,11,U.c.muted,1280,'center')
end
function S.draw(g)
  U.rect(0,0,1280,800,U.c.bg)
  local draw=({title=S.title,starter=S.starter,world=S.world,battle=S.battle,journal=S.journal,shop=S.shop,ending=S.ending})[g.scene]
  if draw then draw(g) end
  if g.toast then
    local w=math.min(1140,U.fonts[14]:getWidth(g.toast.text)+42);local x=(1280-w)/2
    U.rect(x,7,w,42,{.14,.2,.25,.98},9);U.text(g.toast.text,x+18,20,14,U.c.mint,w-36,'center')
  end
end
return S
