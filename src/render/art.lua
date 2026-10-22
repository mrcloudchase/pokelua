-- All artwork is drawn at runtime. No image files or third-party assets.
local data = require('src.data.creatures')
local A = {}
local G
local opacity = 1
local ink = {0.12, 0.105, 0.20}
local cream = {1.0, 0.94, 0.77}
local function color(c, a) G.setColor(c[1], c[2], c[3], (a or c[4] or 1)*opacity) end
local function mix(c, d, n) return {c[1]+(d[1]-c[1])*n,c[2]+(d[2]-c[2])*n,c[3]+(d[3]-c[3])*n} end
local function rect(c,x,y,w,h,r) color(c); G.rectangle('fill',x,y,w,h,r or 0,r or 0) end
local function oval(c,x,y,rx,ry) color(c); G.ellipse('fill',x,y,rx,ry) end
local function disk(c,x,y,r) color(c); G.circle('fill',x,y,r) end
local function poly(c,p) color(c); G.polygon('fill',p) end
local function stroke(c,p,w) color(c); G.setLineWidth(w or 2); G.line(p) end
local function outlinedOval(c,x,y,rx,ry) oval(ink,x,y,rx+1.6,ry+1.6); oval(c,x,y,rx,ry) end
local function outlinedPoly(c,p) poly(ink,p); color(c); G.push(); local cx,cy=0,0; for i=1,#p,2 do cx=cx+p[i]; cy=cy+p[i+1] end; cx=cx/(#p/2); cy=cy/(#p/2); G.translate(cx,cy); G.scale(.90,.90); G.translate(-cx,-cy); G.polygon('fill',p); G.pop() end
local function hash(s) local n=0; for i=1,#s do n=(n*31+s:byte(i))%997 end; return n end
local function diamond(c,x,y,r) poly(c,{x,y-r,x+r*.65,y,x,y+r,x-r*.65,y}) end
local function eye(x,y,back,scale)
  if back then return end
  scale=scale or 1
  oval(ink,x,y,2.5*scale,4*scale)
  disk(cream,x-.7*scale,y-1.3*scale,1.1*scale)
end
local function leaf(c,x,y,ang,s)
  G.push(); G.translate(x,y); G.rotate(ang or 0); G.scale(s or 1)
  outlinedPoly(c,{0,0,-7,-8,-4,-19,2,-25,8,-15,7,-6})
  stroke(mix(c,cream,.45),{0,-2,1,-17},1.1); G.pop()
end
local function flame(c,x,y,s,t)
  G.push(); G.translate(x,y); G.scale(s or 1)
  local f=math.sin((t or 0)*7+x)*2
  poly(ink,{-9,5,-13,-6,-5,-18,0,-31+f,7,-18,12,-7,9,5})
  poly(c,{-7,3,-10,-5,-3,-16,0,-26+f,5,-15,9,-6,7,3})
  poly({1,.82,.40},{-4,3,-5,-5,1,-14,5,-4,4,3}); G.pop()
end

function A.creature(id,x,y,size,options)
  G=love.graphics; options=options or {}
  local s=data.species[id]
  if not s then return end
  local t=options.time or 0
  local seed=hash(id)
  local base=s.color or {.43,.77,.64}
  local dark=mix(base,ink,.32)
  local light=mix(base,cream,.38)
  local shine=mix(base,cream,.64)
  local back=options.back
  local shape=s.shape or 'blob'
  local previousOpacity=opacity
  opacity=options.ghost and .35 or 1
  G.push('all'); G.translate(x,y); G.scale(size/108,size/108)
  oval({.04,.035,.09,.20},0,39,34,7)
  G.translate(0,math.sin(t*2.4+seed)*1.4)

  if shape=='fox' or shape=='cat' then
    if id=='pyrolion' then
      for i=0,9 do
        local a=(i*36-90)*math.pi/180
        flame(dark,math.cos(a)*22,math.sin(a)*22-8,.53,t+i*.2)
      end
    end
    outlinedPoly(dark,{12,19,29,15,44,-5,47,7,41,25,24,32,10,28})
    poly(light,{34,13,44,0,45,8,40,19,32,24})
    outlinedOval(base,-1,14,22,21)
    outlinedOval(dark,-12,32,9,6); outlinedOval(base,13,32,9,6)
    outlinedPoly(base,{-28,-8,-29,-38,-11,-25,4,-27,26,-40,27,-10})
    if id=='emberlynx' then
      flame(light,-26,-32,.31,t); flame(light,24,-33,.31,t+.7)
    elseif id=='voltail' then
      poly(ink,{33,7,44,-13,38,-12,46,-27,30,-13,35,-12,27,6})
      poly(light,{34,4,41,-11,36,-10,42,-21,33,-12,37,-11,30,4})
    end
    poly(dark,{-25,-16,-25,-31,-14,-22}); poly(dark,{14,-23,23,-33,24,-17})
    outlinedOval(base,0,-9,29,23)
    poly(light,{-23,-2,-13,6,0,0,12,6,23,-2,19,10,0,17,-19,10})
    if not back then
      eye(-12,-10); eye(12,-10)
      poly(ink,{-3,1,3,1,0,4}); stroke(ink,{-5,7,0,9,5,7},1.3)
      if shape=='cat' then stroke(ink,{-19,1,-30,-2},1.2); stroke(ink,{19,1,30,-2},1.2) end
    end
    if s.type=='Ember' then flame({1,.44,.24},35,11,.47,t)
    elseif s.type=='Leaf' then leaf(light,-2,-27,-.4,.75)
    elseif s.type=='Spark' then poly({1,.88,.41},{3,-27,-5,-13,2,-13,-3,-2,11,-17,3,-17})
    elseif s.type=='Frost' then diamond(cream,0,-25,7)
    elseif s.type=='Shade' then poly(shine,{-2,-25,-9,-13,0,-17,8,-12,5,-24}) end
    if id=='umbraclaw' then
      stroke(light,{-21,-20,-13,-16},2); stroke(light,{21,-20,13,-16},2); diamond(shine,0,17,6)
    elseif id=='sootlet' then
      for i=1,3 do disk({.99,.77,.39},-16+i*9,-23-i%2*3,1.5) end
    end
  elseif shape=='plant' or shape=='deer' then
    if shape=='deer' then
      if id~='spriglet' and id~='lunacalf' then
        stroke(ink,{-15,-20,-27,-36,-23,-43,-26,-35,-34,-37},4)
        stroke(ink,{15,-20,27,-36,23,-43,26,-35,34,-37},4)
        stroke(light,{-15,-20,-27,-36,-23,-43},2)
        stroke(light,{15,-20,27,-36,23,-43},2)
        if id=='verdantler' then
          leaf(light,-28,-33,-.9,.51); leaf(base,28,-32,.7,.51)
          leaf(light,-23,-40,-.25,.36); leaf(base,23,-40,.25,.36)
        elseif id=='rimehorn' then
          diamond(cream,-27,-39,6); diamond(cream,27,-39,6)
        end
      elseif id=='lunacalf' then
        outlinedPoly(cream,{-19,-23,-25,-35,-18,-33,-11,-23})
        outlinedPoly(cream,{4,-24,10,-35,12,-28,10,-20})
      end
      outlinedOval(dark,11,12,23,18)
      outlinedPoly(base,{-13,17,-15,38,-7,38,-3,18,9,18,13,38,20,38,19,12})
      outlinedOval(base,-9,-8,19,24)
      outlinedPoly(base,{-23,-18,-38,-27,-32,-13,-21,-7})
      outlinedPoly(base,{4,-21,15,-33,17,-19,8,-11})
      oval(light,-9,2,12,10); eye(-16,-10,back,0.8); eye(-2,-10,back,.8)
      if not back then oval(ink,-9,2,3,2) end
      if s.type=='Frost' then diamond(cream,-9,-25,5)
      elseif id=='lunacalf' then
        color(cream); G.arc('fill','closed',-8,-25,5,0,math.pi)
      else leaf(light,0,-27,.4,id=='spriglet' and .60 or .75) end
      for i=1,4 do disk(shine,8+(i%2)*10,4+math.floor(i/2)*7,2) end
    else
      leaf(dark,-15,24,-1.1,1.1); leaf(base,14,24,1.1,1.1)
      outlinedOval(base,0,10,25,27)
      oval(light,-8,13,13,18)
      outlinedOval(dark,-14,33,8,6); outlinedOval(dark,14,33,8,6)
      leaf(dark,-7,-14,-.85,1.2); leaf(light,8,-17,.6,1.2); leaf(base,0,-16,0,1.3)
      eye(-10,5,back); eye(10,5,back)
      if not back then stroke(ink,{-4,15,0,18,4,15},1.6) end
      if seed%3==0 then
        for i=1,5 do local a=i*math.pi*.4; oval({1,.65,.61},math.cos(a)*10,-22+math.sin(a)*8,7,6) end
        disk({1,.86,.44},0,-22,6)
      end
    end
  elseif shape=='bird' then
    outlinedPoly(dark,{-13,20,-32,34,-12,30,-4,19})
    outlinedPoly(base,{-20,3,-44,-9,-38,10,-24,23,-12,18})
    outlinedPoly(base,{18,0,43,-14,39,8,25,20,13,17})
    outlinedOval(base,0,5,22,27)
    oval(light,0,14,14,17)
    outlinedPoly(base,{-13,-18,-6,-39,1,-29,11,-42,18,-24,17,-12})
    outlinedOval(base,0,-12,23,19)
    outlinedPoly({1,.76,.35},{-6,-6,0,3,7,-6,0,-10})
    eye(-10,-14,back,.8); eye(10,-14,back,.8)
    stroke({1,.70,.32},{-7,29,-8,38,-14,38},3); stroke({1,.70,.32},{8,29,9,38,15,38},3)
    if s.type=='Gale' then stroke(shine,{-35,0,-27,8},2); stroke(shine,{34,-2,27,8},2) end
    if s.type=='Astral' then diamond(cream,0,-25,6) end
    if id=='thornowl' then
      if not back then
        color(light); G.setLineWidth(2.5); G.circle('line',-10,-14,8); G.circle('line',10,-14,8)
      end
      poly(dark,{-36,4,-31,-2,-27,9}); poly(dark,{36,4,31,-2,27,9})
    elseif id=='astralune' then
      color(cream); G.setLineWidth(2); G.arc('line','open',0,-7,36,math.pi*.12,math.pi*.88)
      for i=1,3 do diamond(shine,-39+i*6,-4+i*4,2); diamond(shine,39-i*6,-4+i*4,2) end
    elseif id=='tempestrel' then
      outlinedPoly(shine,{-15,-23,-20,-39,-8,-29,1,-43,8,-27,16,-35,18,-21})
    end
  elseif shape=='bug' then
    outlinedOval(dark,-17,7,18,25); outlinedOval(base,17,7,18,25)
    for i=0,2 do oval(light,-22+i*4,-3+i*11,6,6); oval(shine,22-i*4,-3+i*11,6,6) end
    outlinedOval(base,0,12,12,25)
    for i=0,2 do stroke(dark,{-8,11+i*7,8,11+i*7},3) end
    stroke(ink,{-7,-14,-16,-31,-22,-33},3); stroke(ink,{7,-14,16,-31,22,-33},3)
    disk(light,-22,-33,4); disk(light,22,-33,4)
    outlinedOval(base,0,-8,17,16)
    eye(-7,-9,back); eye(7,-9,back)
    if not back then stroke(ink,{-3,0,0,2,3,0},1.3) end
    if id=='lumifly' then
      disk({1,.91,.52},0,27,7)
      for i=1,4 do diamond(shine,math.cos(i*2)*35,math.sin(i*2+t)*21,1.7) end
    elseif id=='mossmoth' then
      stroke(shine,{-24,-5,-19,8,-24,21},1.5); stroke(shine,{24,-5,19,8,24,21},1.5)
    end
  elseif shape=='turtle' then
    outlinedOval(dark,-25,24,11,7); outlinedOval(base,25,24,11,7)
    outlinedOval(dark,-17,33,10,6); outlinedOval(base,17,33,10,6)
    outlinedOval(dark,0,9,30,27)
    outlinedOval(base,0,6,25,22)
    poly(light,{-11,-8,9,-10,20,4,12,20,-9,23,-21,7})
    stroke(dark,{-11,-8,-4,3,9,2,9,-10},2)
    stroke(dark,{-4,3,-9,23},2); stroke(dark,{9,2,20,4},2)
    if id~='dripple' then
      for i=0,2 do diamond(shine,-18+i*18,7+(i%2)*8,id=='abysshell' and 7 or 4) end
    end
    outlinedOval(base,0,-13,19,18)
    oval(shine,0,-5,13,6); eye(-8,-16,back,.85); eye(8,-16,back,.85)
    if s.type=='Stone' then poly(light,{-13,-25,-7,-39,1,-29,11,-35,15,-24}) end
  elseif shape=='dragon' then
    outlinedPoly(dark,{-15,1,-42,-21,-43,9,-29,4,-33,21,-14,17})
    outlinedPoly(dark,{15,1,42,-21,43,9,29,4,33,21,14,17})
    poly(light,{-20,5,-37,-13,-35,3,-28,0,-29,14})
    poly(light,{20,5,37,-13,35,3,28,0,29,14})
    outlinedPoly(base,{12,19,30,19,39,8,40,23,27,32,9,31})
    outlinedOval(base,0,10,21,27)
    oval(light,0,17,12,18)
    for i=0,3 do stroke(dark,{-8,7+i*6,8,7+i*6},1) end
    outlinedOval(dark,-14,32,10,7); outlinedOval(base,14,32,10,7)
    outlinedPoly(shine,{-19,-22,-17,-43,-7,-28,8,-28,20,-41,20,-18})
    outlinedOval(base,0,-13,24,21)
    oval(light,0,-3,17,8); eye(-10,-17,back); eye(10,-17,back)
    if not back then poly(cream,{-12,-5,-9,1,-6,-4}); poly(cream,{6,-4,9,1,12,-5}) end
    diamond(shine,0,-29,6)
    if id=='aetherion' then
      color(cream,.66); G.setLineWidth(1.3); G.ellipse('line',0,-22,34,8)
      for i=0,3 do diamond(cream,-30+i*20,-23-math.sin(i)*5,2.2) end
      stroke(shine,{-28,0,-22,9,-25,15},1.3); stroke(shine,{28,0,22,9,25,15},1.3)
    elseif id=='lavadon' then flame(light,34,19,.33,t) end
  elseif shape=='bat' then
    outlinedPoly(base,{-8,-3,-39,-28,-44,-3,-33,-9,-33,12,-22,8,-15,22,-3,12})
    outlinedPoly(base,{8,-3,39,-28,44,-3,33,-9,33,12,22,8,15,22,3,12})
    stroke(light,{-9,5,-35,-20,-31,2},1.7); stroke(light,{9,5,35,-20,31,2},1.7)
    outlinedOval(dark,0,14,13,19)
    outlinedPoly(base,{-18,-8,-17,-35,-5,-18,6,-18,18,-35,20,-8})
    outlinedOval(base,0,-6,21,19)
    oval(light,0,3,12,8); eye(-9,-8,back); eye(9,-8,back)
    if not back then poly(cream,{-8,5,-5,13,-2,5}); poly(cream,{2,5,5,13,8,5}) end
    if id=='nocturn' then
      for i=1,4 do diamond(shine,-18-i*4,-4+(i%2)*6,1.3); diamond(shine,18+i*4,-4+(i%2)*6,1.3) end
    end
  elseif shape=='fish' and id=='auroray' then
    -- A Frost ray has a broad crystalline silhouette instead of a fish tail.
    outlinedPoly(dark,{-5,18,-1,42,5,44,7,36,3,14})
    outlinedPoly(base,{-5,-17,-22,-28,-45,-7,-42,20,-23,9,-11,22,0,16,11,22,23,9,42,20,45,-7,22,-28,5,-17})
    poly(light,{-9,-9,-21,-23,-39,-6,-36,12,-23,3,-13,13})
    poly(light,{9,-9,21,-23,39,-6,36,12,23,3,13,13})
    outlinedOval(base,0,-2,14,24)
    oval(shine,0,6,10,14)
    diamond(cream,0,-20,6)
    eye(-6,-4,back,.8); eye(6,-4,back,.8)
    if not back then stroke(ink,{-3,6,0,8,3,6},1.4) end
    for i=1,3 do
      diamond(cream,-16-i*6,-5+i*4,2.4-i*.3)
      diamond(cream,16+i*6,-5+i*4,2.4-i*.3)
    end
  elseif shape=='fish' then
    outlinedPoly(dark,{19,3,42,-17,37,7,43,27,20,19})
    outlinedPoly(base,{-12,-10,-5,-34,4,-21,16,-23,10,-9})
    outlinedOval(base,-3,7,31,25)
    oval(light,-14,9,16,18)
    outlinedPoly(dark,{-6,9,14,7,6,24})
    eye(-18,2,back,1.25)
    if not back then stroke(ink,{-30,12,-22,15},1.6) end
    for i=0,2 do stroke(shine,{9+i*6,-2,6+i*6,3},1.5) end
    for i=0,2 do color(mix(base,cream,.6),.7); G.circle('line',-29-i*7,-16-i*8,2+i) end
  elseif shape=='golem' then
    outlinedPoly(dark,{-20,-3,-35,-3,-43,16,-33,26,-22,15})
    outlinedPoly(base,{20,-3,35,-3,43,16,33,26,22,15})
    outlinedPoly(base,{-22,-7,-12,-25,13,-24,24,-4,22,24,-20,24})
    poly(light,{-20,-5,-10,-21,8,-21,2,-1,-12,10})
    outlinedPoly(dark,{-17,23,-20,38,-3,38,0,25})
    outlinedPoly(base,{3,25,4,38,21,38,18,23})
    outlinedPoly(base,{-17,-18,-13,-36,13,-36,20,-19,13,-5,-12,-5})
    poly(light,{-12,-32,8,-32,2,-21,-13,-18})
    if not back then rect(ink,-11,-22,7,4,1); rect(ink,5,-22,7,4,1); rect(cream,-9,-22,3,2) end
    diamond(shine,1,7,9); stroke(dark,{-12,13,-3,19,-8,24},1.5)
    if id=='monolisk' then
      stroke(shine,{-7,-16,-7,-10,7,-10,7,-15,0,-15,0,-9},1.3)
      stroke(shine,{-12,2,-7,5,-12,9,-7,14},1.4)
    elseif id=='cragoon' then
      outlinedPoly({.98,.69,.61},{-26,-3,-30,-25,-20,-18,-15,-2})
      outlinedPoly({.98,.77,.50},{22,-4,26,-27,34,-12,30,4})
    elseif id=='pebbloon' then
      oval(light,-15,-22,4,3); oval(light,17,12,4,3)
    end
  else
    -- Round-bodied creatures retain individual ears, crests, and type motifs.
    if s.type=='Ember' then flame(base,0,-9,.9,t)
    elseif s.type=='Tide' then outlinedPoly(light,{-17,-10,-20,-32,-2,-18,13,-31,20,-7})
    elseif s.type=='Astral' then
      for i=0,4 do local a=(i*72-90)*math.pi/180; diamond(light,math.cos(a)*28,math.sin(a)*28,10) end
    else outlinedPoly(dark,{-26,-1,-28,-24,-11,-9,9,-12,27,-25,26,1}) end
    outlinedOval(base,0,10,31,27)
    oval(light,-8,8,19,20)
    outlinedOval(dark,-18,32,10,6); outlinedOval(base,18,32,10,6)
    eye(-11,4,back); eye(11,4,back)
    if not back then stroke(ink,{-5,14,0,17,5,14},1.8) end
    if s.type=='Tide' then oval(shine,-14,-1,6,3)
    elseif s.type=='Astral' then diamond(cream,0,-7,6)
    elseif s.type=='Spark' then poly({1,.91,.49},{0,-8,-7,5,0,4,-4,13,9,0,2,1})
    elseif s.type=='Frost' then diamond(cream,0,-9,8) end
  end

  -- Type signatures and tiny highlights keep related evolutions distinct.
  if not back and (s.type=='Astral' or s.type=='Frost') then
    for i=1,3 do local xx=math.cos(seed+i*3)*38; local yy=math.sin(t+i*2)*6-18-i*5; diamond(cream,xx,yy,1.5+math.sin(t*2+i)*.6) end
  end
  if not back and s.type=='Shade' then
    color({.80,.60,1},.28); G.circle('line',0,2,39+math.sin(t)*2)
  end
  G.pop(); opacity=previousOpacity
end

function A.orb(x,y,r,t)
  G=love.graphics; G.push('all'); G.translate(x,y); G.rotate(math.sin(t or 0)*.12)
  disk(ink,0,0,r+2); disk({.96,.49,.39},0,0,r)
  color({.98,.90,.73}); G.arc('fill','closed',0,0,r,0,math.pi)
  rect(ink,-r,-2,r*2,4); disk(ink,0,0,r*.34); disk({.48,.90,.78},0,0,r*.21)
  oval({1,.90,.76,.5},-r*.30,-r*.45,r*.3,r*.14)
  G.pop()
end

local function grass(c,x,y,s,variant)
  rect(c,x,y,s,s)
  local v=variant or 0
  local dim=mix(c,ink,.08); local lit=mix(c,cream,.10)
  for i=1,3 do
    local px=x+((v*13+i*19)%29)/32*s
    local py=y+((v*7+i*11)%29)/32*s
    rect(i%2==0 and dim or lit,px,py,s*.07,s*.035)
  end
end

function A.tile(ch,x,y,s,p,t,variant)
  G=love.graphics; p=p or {}; t=t or 0; variant=variant or 0
  local g=p.grass or {.25,.51,.43}
  local water=p.water or {.17,.42,.52}
  local accent=p.accent or {.88,.67,.47}
  G.push('all')
  grass(g,x,y,s,variant)
  local u=s/32
  if ch=='~' then
    rect(water,x,y,s,s)
    local light=mix(water,cream,.22); local dark=mix(water,ink,.12)
    local shift=math.floor(t*2+variant)%3
    rect(dark,x,y+s*.8,s,s*.20)
    rect(light,x+(3+shift)*u,y+9*u,12*u,1*u)
    rect(light,x+20*u,y+22*u,(5+shift)*u,1*u)
    if variant%7==0 then diamond(mix(light,cream,.4),x+18*u,y+12*u,1.5*u) end
  elseif ch=='=' or ch==':' then
    local sand=ch==':' and {.79,.68,.46} or {.69,.62,.46}
    sand=mix(sand,accent,.15)
    rect(sand,x,y,s,s)
    rect(mix(sand,cream,.12),x,y,s,2*u)
    for i=1,3 do rect(mix(sand,ink,.1),x+((variant*9+i*7)%28)*u,y+((variant*13+i*11)%29)*u,2*u,u) end
  elseif ch==',' then
    for row=0,1 do for col=0,2 do
      local xx=x+(col*10+5)*u; local yy=y+(row*14+14)*u
      poly(mix(g,ink,.19),{xx-5*u,yy,xx-4*u,yy-10*u,xx,yy-5*u,xx+4*u,yy-12*u,xx+5*u,yy})
      stroke(mix(g,cream,.23),{xx,yy-2*u,xx+2*u,yy-8*u},u)
    end end
  elseif ch=='#' then
    oval({.06,.10,.14,.25},x+s*.53,y+s*.87,s*.43,s*.13)
    rect({.29,.23,.25},x+13*u,y+16*u,7*u,16*u)
    rect({.44,.31,.27},x+14*u,y+18*u,2*u,13*u)
    local leafc=mix(g,{.12,.30,.29},.44)
    outlinedPoly(leafc,{x+2*u,y+23*u,x+5*u,y+11*u,x+11*u,y+7*u,x+13*u,y+1*u,x+22*u,y+1*u,x+25*u,y+9*u,x+30*u,y+15*u,x+30*u,y+24*u,x+23*u,y+28*u,x+8*u,y+28*u})
    local middle=mix(leafc,cream,.08)
    oval(middle,x+10*u,y+17*u,7*u,7*u)
    oval(mix(leafc,cream,.11),x+16*u,y+9*u,7*u,6*u)
    oval(middle,x+23*u,y+17*u,6*u,7*u)
    oval(leafc,x+17*u,y+23*u,7*u,4*u)
    poly(mix(leafc,cream,.17),{x+6*u,y+13*u,x+12*u,y+8*u,x+15*u,y+4*u,x+21*u,y+5*u,x+17*u,y+9*u,x+11*u,y+12*u,x+8*u,y+19*u,x+5*u,y+19*u})
    rect(mix(leafc,cream,.08),x+20*u,y+18*u,7*u,3*u)
    stroke(mix(leafc,ink,.09),{x+6*u,y+20*u,x+11*u,y+22*u,x+15*u,y+20*u},u)
    rect(mix(leafc,cream,.24),x+15*u,y+5*u,4*u,u)
    if variant%9==0 then disk({.93,.51,.39},x+22*u,y+13*u,2*u); disk({.98,.65,.42},x+11*u,y+22*u,1.5*u) end
  elseif ch=='^' then
    oval({.07,.08,.12,.25},x+s*.53,y+s*.82,s*.43,s*.12)
    local rock=mix(accent,{.41,.44,.51},.65)
    poly(ink,{x+3*u,y+25*u,x+2*u,y+16*u,x+11*u,y+6*u,x+23*u,y+5*u,x+30*u,y+17*u,x+28*u,y+27*u,x+13*u,y+29*u})
    poly(rock,{x+5*u,y+24*u,x+4*u,y+16*u,x+12*u,y+8*u,x+22*u,y+7*u,x+28*u,y+18*u,x+26*u,y+25*u,x+13*u,y+27*u})
    poly(mix(rock,cream,.20),{x+5*u,y+16*u,x+12*u,y+8*u,x+21*u,y+8*u,x+15*u,y+15*u})
    stroke(mix(rock,ink,.20),{x+15*u,y+15*u,x+18*u,y+22*u,x+16*u,y+26*u},u)
  elseif ch=='f' then
    for i=1,3 do
      local xx=x+(5+(variant*7+i*8)%23)*u; local yy=y+(5+(variant*11+i*9)%22)*u
      rect(mix(g,ink,.12),xx,yy,1*u,5*u)
      local petals=i%2==0 and {.97,.63,.61} or {.99,.86,.53}
      rect(petals,xx-2*u,yy-1*u,5*u,2*u); rect(petals,xx,yy-3*u,u,6*u)
      rect(cream,xx,yy-1*u,u,u)
    end
  elseif ch=='b' then
    -- A roof module: adjacent building tiles form continuous tiled rooftops.
    rect({.26,.23,.33},x,y,s,s)
    rect({.64,.34,.39},x+u,y+u,s-2*u,s-2*u)
    for row=0,3 do
      rect({.79,.43,.42},x+u,y+(row*8+1)*u,s-2*u,2*u)
      rect({.45,.26,.34},x+u,y+(row*8+7)*u,s-2*u,u)
      rect({.47,.27,.34},x+((row%2)*8+8)*u,y+(row*8+3)*u,u,4*u)
    end
  elseif ch=='d' then
    rect({.27,.22,.27},x,y,s,s)
    for i=0,3 do rect({.63,.46,.34},x+u,y+(i*8+1)*u,s-2*u,6*u); rect({.76,.56,.38},x+u,y+(i*8+1)*u,s-2*u,u) end
    for i=0,1 do disk({.29,.28,.29},x+(3+i*26)*u,y+4*u,u); disk({.29,.28,.29},x+(3+i*26)*u,y+27*u,u) end
  end
  G.pop()
end

function A.building(x,y,w,h,palette,time)
  G=love.graphics; palette=palette or {}; time=time or 0
  G.push('all')
  -- Whole-footprint architecture: warm plaster walls beneath one hip roof.
  local accent=palette.accent or {.88,.67,.47}
  local roof=mix({.69,.34,.37},accent,.16)
  local roofLight=mix(roof,cream,.20)
  local roofShade=mix(roof,ink,.28)
  local wall=mix({.81,.75,.58},accent,.12)
  local timber={.34,.29,.32}
  local frame={.27,.42,.42}
  local r=math.max(1,math.min(w/190,h/120))
  local rh=h*.60
  local wy=y+rh-3*r
  local wh=h-rh
  local inset=math.min(8*r,w*.07)
  rect({.04,.05,.09,.28},x+4*r,y+h-8*r,w-4*r,10*r,3*r)
  rect(ink,x+inset-2*r,wy,w-inset*2+4*r,wh+3*r,2*r)
  rect(wall,x+inset,wy,w-inset*2,wh)
  rect(mix(wall,cream,.13),x+inset+2*r,wy+4*r,w-inset*2-4*r,wh-8*r)
  rect(mix(wall,ink,.18),x+inset,wy+wh-7*r,w-inset*2,7*r)
  -- Quiet timber framing and a broad front step.
  rect(timber,x+inset,wy,3*r,wh)
  rect(timber,x+w-inset-3*r,wy,3*r,wh)
  rect(timber,x+inset,wy+wh*.72,w-inset*2,2*r)
  local doorw=math.min(24*r,w*.22)
  local doorh=math.min(37*r,wh-6*r)
  local dx=x+w*.5-doorw*.5
  local dy=y+h-doorh-5*r
  rect(timber,dx-3*r,dy-3*r,doorw+6*r,doorh+4*r,4*r)
  rect(frame,dx,dy,doorw,doorh,3*r)
  rect(mix(frame,cream,.17),dx+3*r,dy+3*r,doorw-6*r,doorh*.38,1*r)
  rect(mix(frame,ink,.16),dx+3*r,dy+doorh*.56,doorw-6*r,doorh*.32,1*r)
  disk({1,.82,.43},dx+doorw-4*r,dy+doorh*.56,1.3*r)
  rect({.59,.54,.46},dx-6*r,y+h-5*r,doorw+12*r,4*r,1*r)
  rect(mix(wall,cream,.26),dx-6*r,y+h-5*r,doorw+12*r,r)
  local winw=math.min(27*r,w*.17)
  local winh=math.min(24*r,wh*.48)
  local winy=wy+wh*.24
  for _,cx in ipairs({x+w*.23,x+w*.77}) do
    rect(timber,cx-winw*.5-2*r,winy-2*r,winw+4*r,winh+4*r,2*r)
    rect({1,.85,.56},cx-winw*.5,winy,winw,winh,1*r)
    rect({.98,.93,.73},cx-winw*.5+2*r,winy+2*r,winw*.35,winh*.35)
    rect(timber,cx-r,winy,2*r,winh)
    rect(timber,cx-winw*.5,winy+winh*.48,winw,2*r)
    rect(frame,cx-winw*.5-5*r,winy,3*r,winh)
    rect(frame,cx+winw*.5+2*r,winy,3*r,winh)
    rect(mix(timber,cream,.25),cx-winw*.5-4*r,winy+winh+2*r,winw+8*r,2*r)
  end
  -- Roof is a single trapezoid with gently staggered clay tile courses.
  poly(ink,{x,y+rh,x+w*.075,y+2*r,x+w*.925,y+2*r,x+w,y+rh})
  poly(roof,{x+3*r,y+rh-3*r,x+w*.08,y+4*r,x+w*.92,y+4*r,x+w-3*r,y+rh-3*r})
  poly(roofShade,{x+w*.76,y+4*r,x+w*.92,y+4*r,x+w-3*r,y+rh-3*r,x+w*.84,y+rh-3*r})
  local rows=math.max(3,math.floor(rh/(8*r)))
  for row=1,rows do
    local yy=y+4*r+(rh-9*r)*row/rows
    local slope=(yy-y)/rh
    local left=x+w*.08*(1-slope)+3*r
    local right=x+w-w*.08*(1-slope)-3*r
    rect(roofShade,left,yy,right-left,1.2*r)
    rect(roofLight,left,yy-2*r,right-left,r)
    local tilew=18*r
    local xx=left+((row%2)*tilew*.5)
    while xx<right-4*r do
      rect(roofShade,xx,yy-(rh-9*r)/rows+2*r,r,math.max(2*r,(rh-9*r)/rows-3*r))
      xx=xx+tilew
    end
  end
  rect(roofLight,x+w*.08,y+3*r,w*.84,3*r,1*r)
  rect(timber,x,y+rh-2*r,w,4*r,1*r)
  rect(mix(roof,cream,.20),x+2*r,y+rh-3*r,w-4*r,r)
  -- A stout chimney adds scale and a little sense of life.
  if w>90 then
    local cx=x+w*.72
    local cy=y+rh*.19
    rect(ink,cx-2*r,cy-2*r,14*r,25*r)
    rect({.62,.47,.41},cx,cy,10*r,23*r)
    rect({.77,.58,.46},cx+2*r,cy,3*r,22*r)
    rect(ink,cx-3*r,cy-3*r,16*r,5*r,1*r)
    rect({.46,.36,.37},cx-2*r,cy-3*r,14*r,2*r)
    for i=0,2 do rect({.44,.35,.36},cx,cy+7*r+i*6*r,10*r,r) end
    for i=1,3 do
      local phase=(time*.19+i*.28)%1
      oval({.83,.80,.74,.12*(1-phase)},cx+5*r+math.sin(time+i)*3*r,cy-5*r-phase*17*r,(3+phase*4)*r,(2+phase*3)*r)
    end
  end
  G.pop()
end

local function human(x,y,size,direction,step,time,kind)
  local u=size/32
  local bob=step and math.sin((time or 0)*18)*u or 0
  G.push(); G.translate(x,y+bob); G.scale(u,u)
  oval({.05,.06,.10,.28},16,28,10,3)
  local outfit={.42,.42,.71}; local hair={.23,.19,.28}; local skin={.89,.65,.48}
  if kind=='player' then outfit={.91,.49,.36}; hair={.20,.19,.29}
  elseif kind=='healer' then outfit={.91,.83,.73}; hair={.73,.36,.44}
  elseif kind=='professor' then outfit={.88,.85,.72}; hair={.73,.71,.70}
  elseif kind=='boss' then outfit={.49,.36,.69}; hair={.18,.20,.32}
  elseif kind=='shop' then outfit={.76,.61,.33}; hair={.36,.24,.24}
  elseif kind=='trainer' then outfit={.33,.62,.62}; hair={.34,.23,.29} end
  local stride=step and math.sin((time or 0)*18)*2 or 0
  rect(ink,9,21+stride,6,9,1); rect(ink,18,21-stride,6,9,1)
  rect({.28,.31,.43},10,21+stride,4,6); rect({.28,.31,.43},19,21-stride,4,6)
  rect(ink,6,12,21,13,3); rect(outfit,7,13,19,10,2)
  rect(skin,5,17,4,5,1); rect(skin,24,17,4,5,1)
  rect(mix(outfit,cream,.35),9,14,3,7)
  if direction=='up' then
    rect({.29,.28,.38},10,14,13,10,2); rect({.54,.62,.58},12,15,9,7,1)
    rect({.79,.66,.42},14,17,5,2)
  else rect(cream,15,13,3,7); rect(mix(outfit,ink,.16),20,15,4,7) end
  rect(ink,7,1,19,14,4); rect(skin,8,3,17,11,3)
  rect(hair,7,1,19,6,3); rect(hair,7,4,4,7); rect(hair,23,4,3,7)
  if direction~='up' then
    if direction~='right' then rect(ink,12,8,2,2) end
    if direction~='left' then rect(ink,20,8,2,2) end
    rect({.75,.42,.36},16,12,3,1)
  else rect(hair,9,5,15,7,2) end
  if kind=='player' then
    rect(ink,6,-1,21,6,2); rect({.33,.57,.59},7,-2,19,5,2)
    rect({.59,.79,.70},8,-2,15,1); rect({.24,.39,.45},direction=='up' and 8 or 17,2,12,3,1)
    rect({1,.78,.46},8,13,4,3)
  elseif kind=='healer' then
    rect(cream,10,-2,13,5,1); rect({.91,.44,.44},15,-1,3,4); rect({.91,.44,.44},13,0,7,2)
  elseif kind=='boss' then
    poly({.99,.77,.46},{8,2,7,-5,13,-1,17,-7,21,-1,27,-5,25,3})
    diamond({.70,.94,.86},17,0,2)
  elseif kind=='professor' then
    stroke(ink,{10,8,16,8,17,9,18,8,24,8},1); rect(cream,11,8,4,2); rect(cream,19,8,4,2)
  end
  G.pop()
end

function A.player(x,y,size,direction,step,time)
  G=love.graphics; G.push('all'); human(x,y,size,direction,step,time,'player'); G.pop()
end

function A.npc(n,x,y,size,time)
  G=love.graphics; G.push('all')
  if n.kind=='sign' then
    local u=size/32
    rect({.29,.24,.28},x+14*u,y+13*u,4*u,17*u)
    rect(ink,x+4*u,y+3*u,25*u,17*u,2*u)
    rect({.72,.56,.36},x+5*u,y+4*u,23*u,14*u,u)
    rect({.94,.81,.57},x+9*u,y+8*u,15*u,2*u); rect({.89,.74,.50},x+9*u,y+12*u,11*u,u)
  else human(x,y,size,'down',false,time,n.kind) end
  G.pop()
end

function A.background(w,h,t)
  G=love.graphics; t=t or 0; G.push('all')
  local top={.11,.13,.25}; local bottom={.54,.35,.43}
  for i=0,31 do rect(mix(top,bottom,i/31),0,h*i/32,w,h/32+1) end
  -- Constellations, a great lunar halo, and warm distant archipelagos.
  for i=1,75 do
    local xx=(i*137.508%997)/997*w
    local yy=(i*73.87%541)/541*h*.65
    local alpha=.22+.30*(.5+.5*math.sin(t*.8+i*2))
    color(cream,alpha); G.rectangle('fill',xx,yy,i%9==0 and 3 or 1.5,i%9==0 and 3 or 1.5)
  end
  local mx,my=w*.72,h*.22
  for i=5,1,-1 do disk({.98,.75,.50,.015},mx,my,h*(.08+i*.03)) end
  disk({1,.85,.61},mx,my,h*.075)
  disk({.31,.26,.38},mx+h*.025,my-h*.012,h*.068)
  stroke({.56,.49,.64,.25},{w*.12,h*.22,w*.20,h*.14,w*.28,h*.26,w*.35,h*.15},1)
  for _,p in ipairs({{.12,.22},{.20,.14},{.28,.26},{.35,.15}}) do diamond({.97,.86,.67},w*p[1],h*p[2],3) end
  poly({.27,.29,.39},{0,h*.64,w*.13,h*.47,w*.22,h*.62,w*.36,h*.52,w*.52,h*.64,w*.66,h*.46,w*.83,h*.59,w,h*.45,w,h,0,h})
  rect({.20,.30,.39},0,h*.66,w,h*.34)
  for i=1,28 do
    local yy=h*.67+i*i*h*.00042
    local length=(i*37%67+30)/100*w*.28
    rect({.58,.49,.48,.22},mx-length/2+math.sin(i*1.7+t*.3)*w*.025,yy,length,1+i*.10)
  end
  poly({.16,.25,.31},{0,h*.79,w*.12,h*.70,w*.28,h*.76,w*.40,h*.88,w*.62,h*.85,w*.79,h*.74,w*.91,h*.70,w,h*.74,w,h,0,h})
  -- The distant beacon is the visual anchor of the title screen.
  local bx,by=w*.82,h*.705
  poly({.13,.19,.27},{bx-w*.045,by,bx-w*.035,by-h*.025,bx+w*.035,by-h*.025,bx+w*.05,by})
  poly({.44,.39,.43},{bx-w*.012,by,bx-w*.009,by-h*.16,bx+w*.009,by-h*.16,bx+w*.014,by})
  rect({.20,.23,.32},bx-w*.016,by-h*.175,w*.032,h*.022)
  poly({.22,.22,.32},{bx-w*.023,by-h*.175,bx,by-h*.205,bx+w*.023,by-h*.175})
  rect({1,.84,.49},bx-w*.008,by-h*.17,w*.016,h*.015)
  color({1,.83,.50},.10); G.polygon('fill',bx,by-h*.16,bx-w*.32,by-h*.30,bx-w*.32,by-h*.05)
  -- Foreground coastal bluff and hand-drawn grasses.
  poly({.10,.18,.23},{0,h*.89,w*.19,h*.84,w*.34,h*.90,w*.46,h,w,h,w,h,0,h})
  for i=0,29 do
    local xx=i*w*.017; local yy=h*(.93+.035*math.sin(i*.8)); local lean=math.sin(t*1.2+i*.7)*3
    stroke({.20,.34,.32},{xx,yy,xx-5+lean,yy-17,xx+2+lean,yy-7,xx+5+lean,yy-23},2)
  end
  G.pop()
end

return A
