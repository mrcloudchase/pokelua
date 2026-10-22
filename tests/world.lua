-- Pure-Lua campaign invariants. Called by tests/run.lua or directly as a module.
return function(check)
  local W=require('src.data.world')
  local D=require('src.data.creatures')
  local function assertCheck(value,message)
    if check then check(value,message) else assert(value,message) end
  end
  local function reachable(z)
    local blocked={}
    for _,n in ipairs(z.npcs) do blocked[n.x..','..n.y]=true end
    local q, seen={{z.spawn.x,z.spawn.y}}, {}
    local head=1
    seen[z.spawn.x..','..z.spawn.y]=true
    while q[head] do
      local c=q[head]; head=head+1
      for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local x,y=c[1]+d[1],c[2]+d[2]
        local k=x..','..y
        if not seen[k] and not blocked[k] and W.isWalkable(z,x,y) then
          seen[k]=true; q[#q+1]={x,y}
        end
      end
    end
    return seen
  end
  local bosses={}
  for id,z in pairs(W.zones) do
    assertCheck(#z.tiles==z.height,id..' row count')
    for _,row in ipairs(z.tiles) do assertCheck(#row==z.width,id..' row width') end
    assertCheck(W.isWalkable(z,z.spawn.x,z.spawn.y),id..' spawn walkable')
    local seen=reachable(z)
    for _,p in ipairs(z.portals) do
      assertCheck(seen[p.x..','..p.y],id..' portal reachable '..p.to)
      local target=W.zones[p.to]
      assertCheck(target and W.isWalkable(target,p.tx,p.ty),id..' destination valid '..p.to)
      assertCheck(not (p.tx==p.x and p.ty==p.y and id==p.to),id..' no self portal')
    end
    for _,n in ipairs(z.npcs) do
      assertCheck(W.isWalkable(z,n.x,n.y),id..' NPC on walkable terrain '..n.id)
      local adjacent=false
      for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        if seen[(n.x+d[1])..','..(n.y+d[2])] then adjacent=true end
      end
      assertCheck(adjacent,id..' NPC approachable '..n.id)
      if n.kind=='boss' then bosses[n.bossIndex]=n.id end
      for _,c in ipairs(n.party or {}) do assertCheck(D.species[c.species]~=nil,id..' trainer species '..c.species) end
    end
    local grass=false
    for y,row in ipairs(z.tiles) do
      for x=1,z.width do
        if row:sub(x,x)==',' and seen[x..','..y] then grass=true end
      end
    end
    assertCheck(grass,id..' encounter grass reachable')
    for _,e in ipairs(z.encounters) do assertCheck(D.species[e.species]~=nil,id..' encounter species '..e.species) end
  end
  for i,b in ipairs(W.bosses) do assertCheck(bosses[i]==b.id,'warden order '..i) end
  -- Follow the gated zone graph with only sigils earned so far. This catches
  -- campaign softlocks even when individual maps remain internally connected.
  local function accessible(sigils)
    local reached={[W.start.zone]=true}
    local changed=true
    while changed do
      changed=false
      for id in pairs(reached) do
        for _,p in ipairs(W.zones[id].portals) do
          if p.requires<=sigils and not reached[p.to] then reached[p.to]=true; changed=true end
        end
      end
    end
    return reached
  end
  for i,b in ipairs(W.bosses) do
    assertCheck(accessible(i-1)[b.zone], 'warden accessible before earning its own sigil '..i)
  end
  assertCheck(not accessible(0).embercoast, 'Grove Sigil gates the coast')
  assertCheck(not accessible(1).glasswater, 'Cinder Sigil gates the basin')
  assertCheck(not accessible(2).observatory, 'Tide Sigil gates the Observatory')
  for id in pairs(W.zones) do assertCheck(accessible(4)[id], 'postgame zone accessible '..id) end
  -- Every journal entry can be found in the wild or reached by evolution.
  local obtainable={}
  for _,z in pairs(W.zones) do for _,e in ipairs(z.encounters) do obtainable[e.species]=true end end
  for _=1,4 do
    for id in pairs(obtainable) do
      local evolution=D.species[id].evolution
      if evolution then obtainable[evolution.into]=true end
    end
  end
  local rosterCount=0
  for id in pairs(D.species) do
    rosterCount=rosterCount+1
    assertCheck(obtainable[id], 'journal entry obtainable '..id)
  end
  assertCheck(rosterCount>=36, 'at least36 obtainable journal entries')
  assertCheck(not W.isWalkable('hearth',0,0),'out of bounds blocked')
end
