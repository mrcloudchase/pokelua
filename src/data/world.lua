-- Aster: six hand-composed islands. Map construction uses no runtime randomness.
local World = { zones = {}, bosses = {}, questSteps = {
  "Meet Professor Selene at Hearth Harbor and choose your first companion.",
  "Follow the eastern trail. Earn the Grove Sigil from Warden Iris in Verdant Reach.",
  "Cross to Ember Coast. Earn the Cinder Sigil from Warden Sol.",
  "Find Warden Neris in Glasswater Basin and earn the Tide Sigil.",
  "Climb Moonwake Pass to the Astral Observatory. Restore the beacon with Warden Vega.",
  "The beacon shines again. Explore Aster, complete your journal, and seek Aetherion."
} }

local function canvas(width, height, base, border)
  local g = {}
  for y=1,height do
    g[y]={}
    for x=1,width do
      g[y][x]=(x==1 or y==1 or x==width or y==height) and (border or "#") or (base or ".")
    end
  end
  local c={grid=g,width=width,height=height}
  function c:set(x,y,tile)
    if x>=1 and y>=1 and x<=self.width and y<=self.height then self.grid[y][x]=tile end
  end
  function c:rect(x1,y1,x2,y2,tile)
    for y=y1,y2 do for x=x1,x2 do self:set(x,y,tile) end end
  end
  function c:ellipse(cx,cy,rx,ry,tile)
    for y=math.floor(cy-ry),math.ceil(cy+ry) do
      for x=math.floor(cx-rx),math.ceil(cx+rx) do
        if ((x-cx)/rx)^2+((y-cy)/ry)^2<=1 then self:set(x,y,tile) end
      end
    end
  end
  function c:scatter(x1,y1,x2,y2,tile,density,salt)
    for y=y1,y2 do for x=x1,x2 do
      -- A small deterministic landscape hash keeps save files seed independent.
      local v=(x*37+y*71+x*y*13+(salt or 0)*17)%101
      if self.grid[y][x]=="." and v<density then self:set(x,y,tile) end
    end end
  end
  function c:finish()
    local rows={}
    for y=1,self.height do rows[y]=table.concat(self.grid[y]) end
    return rows
  end
  return c
end

local function npc(id,name,x,y,kind,text,extra)
  local n={id=id,name=name,x=x,y=y,kind=kind,text=text}
  for k,v in pairs(extra or {}) do n[k]=v end
  return n
end
local function encounter(species,min,max,weight,ending)
  return {species=species,min=min,max=max,weight=weight or 10,requiresEnding=ending}
end
local function portal(x,y,to,tx,ty,requires,label)
  return {x=x,y=y,to=to,tx=tx,ty=ty,requires=requires or 0,label=label}
end
local function add(id,name,subtitle,palette,map,spawn,level,npcs,portals,encounters,landmarks)
  World.zones[id]={id=id,name=name,subtitle=subtitle,palette=palette,width=map.width,height=map.height,
    tiles=map:finish(),spawn=spawn,level=level,npcs=npcs,portals=portals,encounters=encounters,landmarks=landmarks or {}}
end
local palettes={
  hearth={grass={0.28,0.48,0.34},water={0.10,0.36,0.47},accent={0.99,0.74,0.49}},
  fernwood={grass={0.19,0.39,0.32},water={0.10,0.37,0.39},accent={0.62,0.88,0.58}},
  embercoast={grass={0.43,0.40,0.29},water={0.13,0.36,0.46},accent={1.00,0.57,0.36}},
  glasswater={grass={0.22,0.47,0.43},water={0.14,0.40,0.59},accent={0.46,0.85,0.91}},
  moonwake={grass={0.34,0.38,0.49},water={0.19,0.31,0.47},accent={0.75,0.76,0.97}},
  observatory={grass={0.25,0.30,0.44},water={0.16,0.23,0.40},accent={0.87,0.73,1.00}}
}

-- Hearth Harbor: open village square, southern harbor, and a beginner meadow.
do
  local m=canvas(40,28)
  m:rect(2,22,39,27,"~")
  m:rect(2,20,39,21,":")
  m:rect(16,20,24,25,"d")
  m:ellipse(10,5,7,3,"#")
  m:ellipse(33,6,5,3,"#")
  m:ellipse(6,16,3,3,",")
  m:ellipse(33,17,5,3,",")
  m:rect(7,7,12,10,"b")
  m:rect(28,7,33,10,"b")
  m:rect(17,5,23,8,"b")
  m:rect(8,11,32,18,"=")
  m:rect(2,14,39,15,"=")
  m:rect(18,9,22,21,"=")
  m:rect(14,12,16,14,"f")
  m:rect(24,12,26,14,"f")
  m:rect(13,18,16,19,"f")
  m:rect(24,18,27,19,"f")
  m:scatter(3,3,37,19,"f",9,1)
  add("hearth","Hearth Harbor","Every journey begins beneath the same stars.",palettes.hearth,m,{x=20,y=17},3,{
    npc("selene","Professor Selene",20,14,"professor",{
      "Welcome to Aster, wayfinder. Our islands once shared the light of a celestial beacon.",
      "When it fell silent, our companions grew restless. Four wardens keep its scattered sigils safe.",
      "Choose a companion, earn their trust, and bring the light home. A journey is better with a friend."
    }),
    npc("hearth_healer","Mira the Caretaker",10,11,"healer",{
      "A long road starts with a little kindness. Let me tend to your whole team.",
      "Visit any caretaker to restore your companions. There is never a charge."
    }),
    npc("hearth_shop","Pip's Provision Stand",30,11,"shop",{
      "Orbs hold a promise of friendship. Tonics keep that promise going!"
    }),
    npc("hearth_sign","Wayfinder's Board",18,11,"sign",{
      "EAST: Verdant Reach. NORTH: Selene's field station. SOUTH: Hearth Harbor.",
      "Walk through rustling grass to meet wild companions. Weaken them before using an orb.",
      "Open your journal with Tab. You can manage your team and save your journey there."
    }),
    npc("harbor_keeper","Old Marlow",20,24,"story",{
      "I used to steer my boat by the beacon. Now I steer by the stars.",
      "The four sigils are Grove, Cinder, Tide, and Astral. Together, they remember the way."
    }),
    npc("hearth_trainer","Apprentice Jun",5,12,"trainer",{
      "Professor Selene says practice makes partners. Want to try a friendly battle?"
    },{party={{species="budpip",level=4}},reward=80})
  },{
    portal(39,14,"fernwood",3,14,0,"Verdant Reach")
  },{
    encounter("budpip",2,4,30),encounter("lunacalf",2,4,24),encounter("flitfin",3,4,20),
    encounter("glimmerbug",3,5,16),encounter("pebbloon",3,5,10)
  },{{x=20,y=6,text="SELENE'S STATION"},{x=20,y=22,text="HEARTH HARBOR"}})
end

-- Verdant Reach: a crossed river, giant old-growth pockets, and a garden arena.
do
  local m=canvas(40,28)
  m:scatter(3,3,38,26,"#",20,4)
  m:ellipse(8,6,6,4,"#")
  m:ellipse(11,22,7,4,"#")
  m:rect(20,2,22,27,"~")
  m:ellipse(31,20,6,4,",")
  m:ellipse(11,9,5,4,",")
  m:ellipse(29,6,5,3,"f")
  m:rect(2,13,39,15,"=")
  m:rect(20,13,22,15,"d")
  m:rect(28,6,31,15,"=")
  m:rect(25,6,35,9,"=")
  m:rect(7,10,13,13,"=")
  m:rect(14,15,17,20,"=")
  m:rect(24,21,29,23,"=")
  m:rect(29,15,30,23,"=")
  m:rect(7,8,11,9,"b")
  add("fernwood","Verdant Reach","Where old roots hold the island together.",palettes.fernwood,m,{x=3,y=14},5,{
    npc("warden_iris","Warden Iris",30,7,"boss",{
      "The grove listens before it speaks. Can you and your companions do the same?",
      "Show me a bond that can weather a storm, and the Grove Sigil is yours."
    },{party={{species="mossmoth",level=7},{species="briarhart",level=8}},reward=240,bossIndex=1}),
    npc("fern_healer","Caretaker Fern",9,10,"healer",{"Rest under the old branches. Your friends will feel like themselves again."}),
    npc("fern_ranger","Ranger Aven",16,19,"trainer",{"No two leaves are alike. Neither are our battle styles!"},
      {party={{species="gustwing",level=5},{species="budpip",level=6}},reward=110}),
    npc("fern_watcher","Field Researcher Lio",26,22,"trainer",{"I've been studying how Spark companions move through the canopy."},
      {party={{species="glimmerbug",level=6},{species="sparkit",level=6}},reward=120}),
    npc("fern_sign","Mossbound Marker",26,12,"sign",{
      "NORTH: Warden Iris's garden. EAST: Ember Coast, open to bearers of the Grove Sigil.",
      "Leaf companions drink Tide attacks but wilt near Ember. Every strength has a season."
    }),
    npc("fern_story","The Seedkeeper",34,8,"story",{
      "The beacon was never merely a lamp. It was a meeting place for every kind of companion.",
      "We keep our garden open so the smallest bud remembers it belongs."
    })
  },{
    portal(2,14,"hearth",38,14,0,"Hearth Harbor"),
    portal(39,14,"embercoast",3,14,1,"Ember Coast — Grove Sigil")
  },{
    encounter("budpip",4,6,25),encounter("mossmoth",5,7,23),encounter("gustwing",4,7,20),
    encounter("sparkit",5,7,16),encounter("thornowl",6,8,8),encounter("spriglet",5,7,8)
  },{{x=30,y=5,text="IRIS'S GARDEN"},{x=11,y=23,text="THE OLD ROOTS"}})
end

-- Ember Coast: warm sand, dark rock pools, a lighthouse, and a seaward arena.
do
  local m=canvas(40,28,".")
  m:rect(2,20,39,27,"~")
  m:rect(2,17,39,19,":")
  m:ellipse(9,6,6,4,"^")
  m:ellipse(33,5,5,3,"^")
  m:ellipse(10,17,5,3,"^")
  m:ellipse(11,10,5,3,",")
  m:ellipse(32,17,5,3,",")
  m:ellipse(19,6,4,3,",")
  m:rect(6,6,10,8,"b")
  m:rect(2,13,39,15,"=")
  m:rect(26,6,31,15,"=")
  m:rect(24,6,34,10,":")
  m:rect(7,9,12,13,"=")
  m:rect(16,14,18,22,"d")
  m:rect(15,21,21,23,"d")
  m:rect(34,21,37,24,"^")
  m:rect(35,22,36,23,"b")
  m:rect(24,11,32,12,"f")
  add("embercoast","Ember Coast","A little courage burns brighter than fear.",palettes.embercoast,m,{x=3,y=14},10,{
    npc("warden_sol","Warden Sol",29,8,"boss",{
      "The beacon went dark, but the sun kept rising. That is the lesson of this coast.",
      "Stand your ground, wayfinder. Let your courage speak."
    },{party={{species="sootlet",level=12},{species="emberlynx",level=13}},reward=420,bossIndex=2}),
    npc("ember_healer","Caretaker Alba",8,9,"healer",{"Salt air and warm blankets. Let's give your whole team a rest."}),
    npc("ember_shop","Coastal Outfitter",11,10,"shop",{"A few extra orbs? Something unusual has been splashing near the pier."}),
    npc("ember_sailor","Sailor Kit",18,22,"trainer",{"The tide turns, and so will this battle!"},
      {party={{species="reefin",level=10},{species="jellydrop",level=10}},reward=180}),
    npc("ember_hiker","Hiker Oren",20,13,"trainer",{"These old coast stones have a stubborn streak. Just like me."},
      {party={{species="pebbloon",level=10},{species="cragoon",level=11}},reward=190}),
    npc("ember_sign","Sunbleached Sign",25,13,"sign",{
      "NORTH: Sunstone Arena. EAST: Glasswater Basin, open to bearers of two sigils.",
      "Tide cools Ember. Stone grounds Spark. Gale carries Leaf away."
    }),
    npc("ember_keeper","Lighthouse Keeper",32,9,"story",{
      "My lighthouse still works. The great beacon is different: it needs living light.",
      "When four wardens agree that a wayfinder is ready, the Observatory opens its heart."
    })
  },{
    portal(2,14,"fernwood",38,14,0,"Verdant Reach"),
    portal(39,14,"glasswater",3,14,2,"Glasswater Basin — two sigils")
  },{
    encounter("sootlet",8,11,26),encounter("pebbloon",8,11,20),encounter("reefin",9,12,18),
    encounter("cragoon",10,12,14),encounter("cindercub",8,11,8),encounter("lavadon",11,13,7),
    encounter("sparkit",9,11,7)
  },{{x=29,y=5,text="SUNSTONE ARENA"},{x=17,y=24,text="SALTWIND PIER"}})
end

-- Glasswater Basin: a network of broad boardwalks across a luminous lake.
do
  local m=canvas(40,28)
  m:rect(15,4,38,25,"~")
  m:ellipse(10,7,6,4,",")
  m:ellipse(8,22,5,3,",")
  m:ellipse(30,7,7,4,".")
  m:ellipse(29,21,6,3,".")
  m:rect(2,13,39,15,"d")
  m:rect(19,2,21,15,"d")
  m:rect(28,7,31,22,"d")
  m:rect(24,6,35,10,"=")
  m:rect(23,20,34,23,"=")
  m:rect(6,9,12,13,"=")
  m:rect(6,7,9,8,"b")
  m:rect(6,15,10,20,"=")
  m:ellipse(31,20,2,1,",")
  m:rect(25,5,34,5,"f")
  m:rect(25,10,34,10,"f")
  m:scatter(3,3,13,26,"f",10,5)
  add("glasswater","Glasswater Basin","Still water can carry the deepest resolve.",palettes.glasswater,m,{x=3,y=14},15,{
    npc("warden_neris","Warden Neris",30,8,"boss",{
      "Look into this water. Not at your reflection, but at the lives beneath it.",
      "A wayfinder protects what they cannot always see. Show me that kind of strength."
    },{party={{species="jellydrop",level=17},{species="tideling",level=18}},reward=650,bossIndex=3}),
    npc("glass_healer","Caretaker Willow",8,9,"healer",{"There's room on the boardwalk for tired feet and tired paws. Rest here."}),
    npc("glass_shop","Basin Trading Post",11,10,"shop",{"Moonwake Pass is a long climb. A few tonics can make all the difference."}),
    npc("glass_diver","Diver Cass",27,22,"trainer",{"Some companions shine brightest in deep water."},
      {party={{species="reefin",level=14},{species="jellydrop",level=15},{species="voltail",level=15}},reward=280}),
    npc("glass_archivist","Archivist Edda",8,19,"trainer",{"Astral companions have been returning since you began your journey. Coincidence?"},
      {party={{species="starling",level=14},{species="lumifly",level=15}},reward=270}),
    npc("glass_sign","Boardwalk Chart",18,13,"sign",{
      "NORTH: Moonwake Pass. Three sigils are required to begin the climb.",
      "The Observatory stands beyond the mountain. A caretaker waits along the path."
    }),
    npc("glass_story","Lakeside Dreamer",33,8,"story",{
      "Aetherion used to circle the beacon every night. My grandmother saw its wings once.",
      "She said it looked like a piece of sky that had decided to stay."
    })
  },{
    portal(2,14,"embercoast",38,14,0,"Ember Coast"),
    portal(20,2,"moonwake",20,26,3,"Moonwake Pass — three sigils")
  },{
    encounter("jellydrop",13,16,24),encounter("reefin",13,16,20),encounter("dripple",12,15,10),
    encounter("lumifly",14,16,16),encounter("starling",13,16,14),encounter("voltail",14,17,10),
    encounter("thornowl",14,16,6)
  },{{x=30,y=4,text="THE MIRROR GARDEN"},{x=28,y=24,text="GLASSWATER WALK"}})
end

-- Moonwake Pass: switchback trails, frost meadows, and a sheltered rest station.
do
  local m=canvas(40,28)
  m:ellipse(8,9,7,6,"^")
  m:ellipse(33,20,6,5,"^")
  m:ellipse(31,6,6,4,"^")
  m:rect(3,22,12,25,"~")
  m:ellipse(10,18,5,3,",")
  m:ellipse(29,10,6,3,",")
  m:ellipse(11,5,5,3,",")
  m:rect(19,18,21,27,"=")
  m:rect(12,17,28,19,"=")
  m:rect(12,10,14,19,"=")
  m:rect(12,9,28,11,"=")
  m:rect(26,5,28,11,"=")
  m:rect(19,4,28,6,"=")
  m:rect(19,2,21,6,"=")
  m:rect(19,14,24,16,"b")
  m:rect(20,17,25,18,"=")
  m:rect(15,12,18,14,"f")
  m:rect(30,12,33,13,"f")
  add("moonwake","Moonwake Pass","Keep close. Even the stars need company.",palettes.moonwake,m,{x=20,y=26},20,{
    npc("moon_healer","Caretaker Rune",23,17,"healer",{"The air is thin up here. Share my fire before your final climb."}),
    npc("moon_shop","Summit Supply Cache",25,18,"shop",{"Packed by the wardens for every wayfinder. Stock up before the Observatory."}),
    npc("moon_trainer","Mountaineer Sera",13,14,"trainer",{"Every summit asks something of us. What will you bring to yours?"},
      {party={{species="frostoat",level=19},{species="tempestrel",level=20}},reward=380}),
    npc("moon_watcher","Nightwatcher Eli",26,6,"trainer",{"Look up! The Shade companions are making room for something brighter."},
      {party={{species="nocturn",level=20},{species="umbraclaw",level=20}},reward=400}),
    npc("moon_sign","Summit Cairn",20,22,"sign",{
      "SOUTH: Glasswater Basin. NORTH: Astral Observatory.",
      "Your party can hold six companions. Others rest safely in storage, accessible from the journal."
    }),
    npc("moon_story","Stargazer Mae",17,10,"story",{
      "Vega stayed at the Observatory when everyone else left. Night after night, keeping watch.",
      "Tell her the villages still look up. Tell her we're ready to see the light again."
    })
  },{
    portal(20,27,"glasswater",20,3,0,"Glasswater Basin"),
    portal(20,2,"observatory",20,26,3,"Astral Observatory")
  },{
    encounter("frostoat",17,20,25),encounter("duskbat",17,19,18),encounter("nocturn",18,21,13),
    encounter("monolisk",18,21,13),encounter("tempestrel",19,21,12),encounter("rimehorn",19,22,10),
    encounter("umbraclaw",20,22,9),encounter("auroray",17,21,5)
  },{{x=22,y=14,text="WAYFINDER'S REST"},{x=20,y=4,text="THE FINAL ASCENT"}})
end

-- Astral Observatory: four gardens, a central celestial dais, and the last warden.
do
  local m=canvas(40,28)
  m:rect(2,2,39,27,"^")
  m:rect(4,4,37,25,".")
  m:rect(6,6,14,11,",")
  m:rect(27,6,35,11,",")
  m:rect(6,18,14,23,",")
  m:rect(27,18,35,23,",")
  m:rect(16,5,24,8,"b")
  m:rect(16,9,24,15,"=")
  m:rect(19,9,21,27,"=")
  m:rect(4,13,37,15,"=")
  m:rect(5,16,9,17,"f")
  m:rect(31,16,35,17,"f")
  m:rect(16,19,18,21,"f")
  m:rect(22,19,24,21,"f")
  m:rect(3,3,37,3,"~")
  m:rect(3,24,17,25,"~")
  m:rect(23,24,37,25,"~")
  m:rect(8,12,10,15,"=")
  m:rect(30,12,32,15,"=")
  add("observatory","Astral Observatory","The light remembers everyone who carried it.",palettes.observatory,m,{x=20,y=26},23,{
    npc("warden_vega","Warden Vega",20,10,"boss",{
      "For years I thought keeping the beacon safe meant keeping it untouched.",
      "Then your companions began to sing. From grove, coast, and lake, I heard them.",
      "One final battle, wayfinder. Let us find out what our light can become."
    },{party={{species="rimehorn",level=22},{species="umbraclaw",level=23},{species="astralune",level=24}},reward=1200,bossIndex=4}),
    npc("observatory_healer","Caretaker Nova",9,13,"healer",{
      "You've carried your friends a long way. Let them carry you through this last step."
    }),
    npc("observatory_sign","Celestial Inscription",18,16,"sign",{
      "Four sigils. One sky. A thousand paths home.",
      "When the beacon wakes, Aetherion may return to the star gardens. Seek its light in the grass."
    }),
    npc("observatory_story","Beacon Archivist",31,13,"story",{
      "This instrument gathers the bonds between companions. Every friendship adds a little light.",
      "Your journal is part of that story. Keep meeting new companions after the beacon shines."
    })
  },{
    portal(20,27,"moonwake",20,3,0,"Moonwake Pass")
  },{
    encounter("starling",20,23,20),encounter("astralune",22,24,15),encounter("lunacalf",20,23,15),
    encounter("lumifly",20,23,15),encounter("verdantler",22,24,8),encounter("pyrolion",22,24,8),
    encounter("abysshell",22,24,8),encounter("monolisk",21,24,8),encounter("aetherion",25,25,3,true)
  },{{x=20,y=4,text="THE CELESTIAL BEACON"},{x=10,y=20,text="STAR GARDENS"}})
end

World.start={zone="hearth",x=20,y=17}
World.bosses={
  {id="warden_iris",name="Iris",title="Warden of the Grove",zone="fernwood",badge="Grove Sigil",bossIndex=1,color={0.59,0.84,0.47}},
  {id="warden_sol",name="Sol",title="Warden of the Coast",zone="embercoast",badge="Cinder Sigil",bossIndex=2,color={1.00,0.57,0.36}},
  {id="warden_neris",name="Neris",title="Warden of the Basin",zone="glasswater",badge="Tide Sigil",bossIndex=3,color={0.40,0.83,0.91}},
  {id="warden_vega",name="Vega",title="Warden of the Stars",zone="observatory",badge="Astral Sigil",bossIndex=4,color={0.83,0.69,1.00}}
}
World.zoneOrder={"hearth","fernwood","embercoast","glasswater","moonwake","observatory"}
local solid={ ["#"]=true,["~"]=true,["^"]=true,["b"]=true }
function World.tile(zone,x,y)
  if type(zone)=="string" then zone=World.zones[zone] end
  if not zone or not x or not y or x<1 or y<1 or x>zone.width or y>zone.height then return "#" end
  return zone.tiles[y]:sub(x,x)
end
function World.isWalkable(zone,x,y)
  return not solid[World.tile(zone,x,y)]
end
return World
