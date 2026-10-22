-- Deterministic behavioral tests; run with require('tests.combat')().
return function(externalCheck)
  local D=require('src.data.creatures')
  local C=require('src.systems.creature')
  local B=require('src.systems.battle')
  local checks=0
  local function check(value,message)
    checks=checks+1
    if externalCheck then externalCheck(value,message) else assert(value,message) end
  end
  local function fixed(n) return function() return n end end
  local function fighter(id,level,moves)
    local c=C.create(id,level)
    if moves then c.moves=moves end
    return c
  end
  local function battle(ally,enemy,opts)
    opts=opts or {}; opts.rng=opts.rng or fixed(0.5)
    return B.new({ally},{enemy},opts)
  end
  local count=0
  for id,s in pairs(D.species) do
    count=count+1
    check(s.id==id and s.base.hp>0 and s.base.attack>0 and s.base.defense>0 and s.base.speed>0,'Valid base stats for '..id)
    check(s.color[1]>=0 and s.color[1]<=1 and s.color[2]>=0 and s.color[2]<=1 and s.color[3]>=0 and s.color[3]<=1,'Normalized color for '..id)
    check(s.description and #s.description>30,'Field description for '..id)
    for _,entry in ipairs(s.learnset) do check(D.moves[entry[2]],'Defined learned move for '..id) end
    if s.evolution then check(D.species[s.evolution.into],'Defined evolution for '..id) end
    local c=C.create(id,25)
    check(c.hp==C.stats(c).hp and #c.moves>=1 and #c.moves<=4,'Usable generated creature '..id)
    for _,move in ipairs(c.moves) do check(D.moves[move],'Created move exists') end
  end
  check(count==36 and #D.types==10 and #D.starters==3,'Complete 36-creature roster')
  local moveCount=0
  for _,m in pairs(D.moves) do moveCount=moveCount+1; check(m.accuracy>0 and m.accuracy<=1,'Valid accuracy') end
  check(moveCount>=30,'Broad move roster')
  check(B.effectiveness('Ember','Leaf')==2,'Elemental advantage')
  check(B.effectiveness('Ember','Tide')==0.5,'Elemental resistance')
  check(B.effectiveness('Neutral','Tide')==1,'Neutral elemental match')
  check(B.effectiveness('Unknown','Unknown')==1,'Unknown matchup is neutral')
  local c=C.create('spriglet',9)
  c.hp=c.hp-8
  local beforeMax=C.stats(c).hp
  local messages=C.gainXP(c,C.xpNeeded(9))
  check(c.level==10 and c.species=='briarhart','Level threshold evolves starter')
  check(c.hp==C.stats(c).hp-8 and C.stats(c).hp>beforeMax,'Evolution preserves missing energy')
  check(#messages>=2,'Evolution and level changes are reported')
  c.nickname='Fern'; check(C.name(c)=='Fern','Nickname is preserved')
  C.gainXP(c,1000000)
  check(c.level==50 and c.species=='verdantler' and c.xp==0,'Large experience handles multiple evolutions and level cap')
  c.hp=0; C.heal(c); check(c.hp==C.stats(c).hp,'Sanctuary heals completely')
  c=C.create('dripple',4); c.hp=0; C.gainXP(c,1000)
  check(c.hp==0,'Experience does not silently revive an exhausted companion')
  check(C.firstAlive({c,C.create('spriglet',5)})==2,'First living party member')
  check(C.firstAlive({c})==nil,'No living party member')
  check(C.create('dripple',-99).level==1 and C.create('dripple',99).level==50,'Creation enforces level bounds')
  check(not pcall(C.create,'missing',1),'Unknown species fails explicitly')

  local ally=fighter('spriglet',5,{'leaflick'})
  local enemy=fighter('dripple',5,{'nudge'})
  local s=battle(ally,enemy)
  local bag={orbs=3,tonics=2}
  check(not B.act(s,{kind='move',index=0},bag) and s.turn==0,'Invalid move does not spend a turn')
  check(not B.act(s,{kind='item',item='tonic'},bag) and bag.tonics==2 and s.turn==0,'Full energy tonic is rejected without consuming resources')
  check(not B.act(s,{kind='switch',index=1},bag) and s.turn==0,'Cannot switch to active creature')
  check(B.act(s,{kind='move',index=1},bag),'Valid attack succeeds')
  check(s.turn==1 and ally.hp<C.stats(ally).hp and enemy.hp<C.stats(enemy).hp,'Both sides act on a normal turn')
  check(ally.hp>=0 and enemy.hp>=0,'Energy never negative')
  enemy.hp=1
  local playerBefore=ally.hp
  check(B.act(s,{kind='move',index=1},bag) and s.outcome=='win','Defeating final opponent ends battle')
  check(ally.hp>=playerBefore,'Knocked-out opponent cannot retaliate (level healing allowed)')
  local turn=s.turn
  check(not B.act(s,{kind='move',index=1},bag) and s.turn==turn,'Finished battles reject actions')

  ally=fighter('spriglet',15,{'leaflick'})
  local reserve=fighter('dripple',5)
  local e1=fighter('pebbloon',2,{'nudge'}); e1.hp=1
  local e2=fighter('pebbloon',4,{'nudge'})
  s=B.new({ally,reserve},{e1,e2},{wild=false,trainerName='Tester',rng=fixed(0.5)})
  local hp=ally.hp
  B.act(s,{kind='move',index=1},{})
  check(s.enemyActive==2 and not s.outcome,'Trainer advances to next companion')
  check(e2.hp==C.stats(e2).hp and ally.hp>=hp,'Newly sent opponent waits until next turn')
  check(reserve.xp>0 or reserve.level>5,'Living reserves share experience')
  check(not B.act(s,{kind='catch'},{orbs=2}) and s.turn==1,'Trainer companions cannot be caught')
  check(not B.act(s,{kind='run'},{}) and s.turn==1,'Trainer challenges cannot be fled')

  ally=fighter('dripple',5,{'nudge'}); ally.hp=1
  enemy=fighter('sparkit',15,{'spark'})
  reserve=fighter('cindercub',5,{'nudge'})
  s=B.new({ally,reserve},{enemy},{rng=fixed(0.5)})
  B.act(s,{kind='move',index=1},{})
  check(ally.hp==0 and s.active==2 and not s.outcome,'Exhausted active companion automatically swaps')
  check(enemy.hp==C.stats(enemy).hp,'Exhausted attacker does not execute its queued move')
  check(reserve.hp==C.stats(reserve).hp,'Automatic replacement receives no extra attack')
  check(not B.act(s,{kind='switch',index=1},{}) and s.turn==1,'Exhausted companion cannot be sent in')
  reserve.hp=1
  B.act(s,{kind='move',index=1},{})
  check(s.outcome=='lose','Exhausted party loses battle')

  ally=fighter('spriglet',8,{'nudge'}); enemy=fighter('dripple',8,{'nudge'})
  s=battle(ally,enemy,{rng=fixed(0)})
  bag={orbs=1,tonics=1}
  check(B.act(s,{kind='catch'},bag) and s.outcome=='caught','Successful catch ends encounter')
  check(s.caught==enemy and #s.party==1,'Catch exposes creature without inserting into party')
  check(bag.orbs==0 and s.turn==1,'Successful catch consumes one orb and one turn')
  check(ally.xp>0 or ally.level>8,'Bonding grants experience')
  ally=fighter('spriglet',8,{'nudge'}); enemy=fighter('dripple',8,{'nudge'})
  s=battle(ally,enemy,{rng=fixed(0.999)})
  bag={orbs=0}
  check(not B.act(s,{kind='catch'},bag) and s.turn==0,'No-orb catch spends no turn')
  bag.orbs=1
  check(B.act(s,{kind='catch'},bag) and not s.outcome and bag.orbs==0,'Failed catch consumes orb and continues')
  check(ally.hp<C.stats(ally).hp,'Enemy retaliates after failed catch')
  ally.hp=1; bag.tonics=1
  B.act(s,{kind='item',item='tonic'},bag)
  check(bag.tonics==0 and ally.hp>1 and ally.hp<=C.stats(ally).hp,'Tonic restores 35 energy before retaliation')
  check(not B.act(s,{kind='item',item='tonic'},bag),'Empty tonic supply is rejected')
  check(not B.act(s,{kind='item',item='unknown'},bag),'Unknown item is rejected')
  check(not B.act(s,{kind='unknown'},bag),'Unknown command is rejected')

  ally=fighter('spriglet',10,{'shelter'}); enemy=fighter('pebbloon',10,{'nudge'})
  s=battle(ally,enemy)
  B.act(s,{kind='move',index=1},{})
  local guarded=C.stats(ally).hp-ally.hp
  local rawAlly=fighter('spriglet',10,{'nudge'})
  s=battle(rawAlly,fighter('pebbloon',10,{'nudge'}))
  B.act(s,{kind='move',index=1},{})
  check(guarded>0 and guarded<C.stats(rawAlly).hp-rawAlly.hp,'Shelter meaningfully reduces incoming attack')
  ally=fighter('spriglet',10,{'renew'}); ally.hp=5
  s=battle(ally,fighter('pebbloon',1,{'nudge'}))
  B.act(s,{kind='move',index=1},{})
  check(ally.hp>5 and ally.hp<=C.stats(ally).hp,'Renew heals within maximum energy')

  ally=fighter('spriglet',5,{'quickstep'}); ally.hp=1
  enemy=fighter('sparkit',5,{'nudge'}); enemy.hp=1
  s=battle(ally,enemy)
  B.act(s,{kind='move',index=1},{})
  check(s.outcome=='win','Quickstep priority beats a faster opponent')
  ally=fighter('spriglet',5)
  s=B.new({ally,C.create('dripple',5)},{fighter('pebbloon',2,{'nudge'})},{rng=fixed(0.5)})
  check(B.act(s,{kind='switch',index=2},{}) and s.active==2,'Manual switching changes the active companion')
  check(s.party[2].hp<C.stats(s.party[2]).hp and ally.hp==C.stats(ally).hp,'Switch gives opponent one attack against incoming companion')
  s=battle(fighter('spriglet',5),fighter('pebbloon',5),{rng=fixed(0)})
  check(B.act(s,{kind='run'},{}) and s.outcome=='fled','Wild encounters can be fled')
  s=battle(fighter('dripple',1),fighter('sparkit',30,{'nudge'}),{rng=fixed(0.99)})
  B.act(s,{kind='run'},{})
  check(s.turn==1 and s.outcome~='fled','Failed escape advances battle')
  return checks
end
