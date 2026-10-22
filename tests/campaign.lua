-- A reproducible playthrough simulation using real XP, captures, money, items,
-- optional trainers, route-level encounters, and all four wardens. No stat edits.
local function runCampaign(starter,seed,options)
  options=options or {}
  local D=require('src.data.creatures')
  local W=require('src.data.world')
  local C=require('src.systems.creature')
  local B=require('src.systems.battle')
  math.randomseed(seed)
  local party={C.create(starter,5)}
  local bag={orbs=12,tonics=6}
  local money=180
  local report={starter=starter,seed=seed,bosses={},wins=0,losses=0,battles=0,catches=0,turns=0,purchases=0}
  local function heal() for _,c in ipairs(party) do C.heal(c) end end
  local function estimate(attacker,defender,move)
    if move.kind~='damage' then return 0 end
    local a,d=C.stats(attacker),C.stats(defender)
    return ((2*attacker.level/5+2)*move.power*a.attack/d.defense/12+3)
      *B.effectiveness(move.type,D.species[defender.species].type)
      *(move.type==D.species[attacker.species].type and 1.15 or 1)*move.accuracy
  end
  local function bestAttack(c,enemy,nonlethal)
    local best,score=nil,-1
    for i,id in ipairs(c.moves) do
      local move=D.moves[id]
      local value=estimate(c,enemy,move)
      if move.effect=='drain' then value=value*1.2 end
      if nonlethal and value>=enemy.hp*0.82 then value=-1 end
      if move.kind=='damage' and value>score then best,score=i,value end
    end
    return best,score
  end
  local function utility(c,enemy)
    if c.hp<=0 then return -1 end
    local _,damage=bestAttack(c,enemy)
    local _,incoming=bestAttack(enemy,c)
    return damage*math.min(1,c.hp/C.stats(c).hp)/math.max(1,incoming)
  end
  local function buy(key,price,minimum)
    while bag[key]<minimum and money>=price do
      money=money-price;bag[key]=bag[key]+1;report.purchases=report.purchases+1
    end
  end
  local function fight(enemies,opts,capture)
    heal() -- Every zone has a free caretaker; players can rest between challenges.
    local best=1
    for i=2,#party do if utility(party[i],enemies[1])>utility(party[best],enemies[1]) then best=i end end
    party[1],party[best]=party[best],party[1]
    opts=opts or {};opts.rng=math.random
    local s=B.new(party,enemies,opts)
    report.battles=report.battles+1
    local previousEnemy=s.enemyActive
    for turn=1,160 do
      if s.outcome then break end
      local ally,enemy=party[s.active],enemies[s.enemyActive]
      local action
      if capture and (enemy.hp<=C.stats(enemy).hp*0.55 or not bestAttack(ally,enemy,true)) and bag.orbs>0 then
        action={kind='catch'}
      else
        local swap=nil
        if not capture and previousEnemy~=s.enemyActive then
          for i,c in ipairs(party) do
            if i~=s.active and c.hp>0 and utility(c,enemy)>utility(ally,enemy)*1.7 and (not swap or utility(c,enemy)>utility(party[swap],enemy)) then swap=i end
          end
        end
        if swap then action={kind='switch',index=swap}
        else
          local healMove
          for i,id in ipairs(ally.moves) do if D.moves[id].kind=='heal' then healMove=i end end
          local _,incoming=bestAttack(enemy,ally)
          local hp=C.stats(ally).hp
          if not capture and ally.hp<hp*0.35 and healMove and incoming<hp*0.30 then
            action={kind='move',index=healMove}
          elseif not capture and ally.hp<hp*0.35 and bag.tonics>0 and incoming<28 then
            action={kind='item',item='tonic'}
          else
            local move=capture and bestAttack(ally,enemy,true) or bestAttack(ally,enemy)
            if not move and capture and bag.orbs>0 then action={kind='catch'}
            else action={kind='move',index=move or bestAttack(ally,enemy)} end
          end
        end
      end
      previousEnemy=s.enemyActive
      assert(B.act(s,action,bag),'Simulation selected invalid battle action')
    end
    report.turns=report.turns+s.turn
    assert(s.outcome,'Campaign battle exceeded160 turns: '..(opts.trainerName or enemies[1].species))
    if s.outcome=='win' then report.wins=report.wins+1;money=money+(opts.reward or 20)
    elseif s.outcome=='lose' then report.losses=report.losses+1;money=money-math.floor(money*0.1) end
    if s.outcome=='caught' then
      report.catches=report.catches+1
      local c=s.caught; C.heal(c)
      if #party<6 then party[#party+1]=c
      else
        -- Keep the starter, replace a lower-level duplicate type if possible,
        -- otherwise replace the lowest-level non-starter. The journal allows it.
        local replace
        for i,p in ipairs(party) do
          if p~=report.originalStarter and D.species[p.species].type==D.species[c.species].type then replace=i end
        end
        if not replace then
          for i,p in ipairs(party) do
            if p~=report.originalStarter and (not replace or p.level<party[replace].level) then replace=i end
          end
        end
        if replace then party[replace]=c end
      end
    end
    return s.outcome
  end
  report.originalStarter=party[1]
  local targets={
    hearth={{'pebbloon',4},{'glimmerbug',4}},
    fernwood={{'gustwing',6},{'sparkit',6}},
    embercoast={{'reefin',10},{'sootlet',10}},
    glasswater={{'starling',15},{'jellydrop',15}},
    moonwake={{'rimehorn',20},{'umbraclaw',20}},
    observatory={{'astralune',23},{'monolisk',23}}
  }
  for _,zoneId in ipairs(W.zoneOrder) do
    local z=W.zones[zoneId]
    buy('orbs',25,6);buy('tonics',35,4)
    for _,target in ipairs(targets[zoneId]) do
      local valid=false
      for _,e in ipairs(z.encounters) do
        if e.species==target[1] and target[2]>=e.min and target[2]<=e.max then valid=true end
      end
      assert(valid,'Capture target must occur locally at its actual route level')
      fight({C.create(target[1],target[2])},{wild=true},true)
      buy('orbs',25,4)
    end
    -- Two ordinary encounters per route, with no search for high-XP foes.
    for i=1,(options.wilds or 2) do
      local encounter=z.encounters[i]
      fight({C.create(encounter.species,math.floor((encounter.min+encounter.max)/2))},{wild=true})
    end
    for _,n in ipairs(z.npcs) do
      if n.kind=='trainer' and options.trainers~=false then
        local enemies={}
        for _,c in ipairs(n.party) do enemies[#enemies+1]=C.create(c.species,c.level) end
        fight(enemies,{wild=false,trainerName=n.name,reward=n.reward})
      end
    end
    for _,n in ipairs(z.npcs) do
      if n.kind=='boss' then
        local enemies={}
        for _,c in ipairs(n.party) do enemies[#enemies+1]=C.create(c.species,c.level) end
        buy('tonics',35,4)
        local levels={}
        for _,c in ipairs(party) do levels[#levels+1]=c.species..':'..c.level end
        local outcome=fight(enemies,{wild=false,trainerName=n.name,reward=n.reward})
        report.bosses[#report.bosses+1]={id=n.id,outcome=outcome,party=table.concat(levels,',')}
        if outcome~='win' then report.failedAt=n.id;break end
        bag.orbs=bag.orbs+4;bag.tonics=bag.tonics+2
        -- Mirror the half-level milestone reward in Game:finishBattle.
        for _,c in ipairs(party) do C.gainXP(c,C.xpNeeded(c.level)*0.5);C.heal(c) end
      end
    end
    if report.failedAt then break end
  end
  report.originalStarter=nil
  report.orbs=bag.orbs;report.tonics=bag.tonics;report.money=money
  return report
end

return function(externalCheck,options)
  local checks=0
  local reports={}
  local routes=options and {options} or {
    {name='explorer',wilds=2,trainers=true},
    {name='direct',wilds=2,trainers=false}
  }
  for _,route in ipairs(routes) do
    for _,starter in ipairs(require('src.data.creatures').starters) do
      for _,seed in ipairs({101,202,303}) do
        local r=runCampaign(starter,seed,route)
        r.style=route.name or 'custom'
        reports[#reports+1]=r
        local ok=#r.bosses==4 and not r.failedAt
        local message='Campaign '..r.style..' '..starter..' seed'..seed..' clears all wardens with route-level captures and ordinary exploration'
        checks=checks+1
        if externalCheck then externalCheck(ok,message) else assert(ok,message..' failed at '..tostring(r.failedAt)) end
      end
    end
  end
  return checks,reports
end
