/* Part 1 · Episode 3 · Low Water */
Object.assign(window.OTT_PARTS.p1.scenes, {
e3_open:{ep:3, card:true, place:"Marsh family dock", time:"Wed 16:00", lines:[
  "~A weathered dock below a clapboard house. Two boats: the family's old trawler, Margaret, and Eli's smaller skiff. Nets, crab traps, a single bulb on a pole.",
  "~Eli doesn't look at you. He talks to the water.",
  "ELI: Sunday night I stood under her window for an hour. I wanted to tell her to stop. To leave. I didn't have the guts to knock.",
  "ELI: Corbin came to our house two weeks ago. He said if I didn't tell him when Nila went out at night, Tess would get arrested for stealing from the diner till. He had a video. It wasn't her. But it looked like her.",
  "ELI: So I told him. I told him she goes out at night with the radio. And three days later she was gone."],
  fx:{flag:"met_eli"},
  choices:[
    {t:"\"You did what you had to. Help me now.\"", sub:"Forgive him.", to:"e3_bucket", fx:{trust:{eli:2}}},
    {t:"\"You sold her out.\"", sub:"Anger.", to:"e3_bucket", fx:{trust:{eli:-1}}},
    {t:"\"Nila said you'd know about the dock. Show me.\"", sub:"Stay focused.", to:"e3_bucket", fx:{trust:{eli:1}}}
  ]},
e3_bucket:{ep:3, place:"Marsh family dock", time:"Wed 16:10", lines:[
  "~Eli leads you to a white bucket behind the crab traps, its lid weighted with a brick.",
  "ELI: Found it under the dock Saturday. Nila photographed it. Nobody here knows what it is.",
  "~He lifts the lid with a boat hook. Inside, coiled and still: a thick snake, gold and brown, with a broad, arrow-shaped head. It lifts that head toward the light. Its tongue tastes the air.",
  "~You pull out your phone and start comparing photos."],
  puzzle:{type:"pick", title:"Identify the snake", prompt:"Gold-and-brown blotches. A wide, arrow-shaped head with a pit between eye and nostril. Thick body, about 70 cm. No rattle.", to:"e3_snake", options:[
    {t:"Eastern garter snake", why:"Garter snakes have stripes and slim heads. This head is wide and arrow-shaped."},
    {t:"Massasauga rattlesnake, Ontario's only venomous snake", why:"A massasauga is grey-brown with a rattle. This one has no rattle, and it's gold."},
    {t:"Golden lancehead (Bothrops insularis)", correct:true},
    {t:"Corn snake, an escaped pet", why:"Corn snakes have narrow heads and no heat pits. This is a pit viper."}
  ]}},
e3_snake:{ep:3, place:"Marsh family dock", time:"Wed 16:14", lines:[
  "~Golden lancehead. Bothrops insularis. Found in exactly one place on Earth: Ilha da Queimada Grande, \"Snake Island\", off the coast of Brazil. Critically endangered. Venom several times stronger than its mainland cousins. On the black market, one can sell for tens of thousands of dollars.",
  "MANI: This isn't from Ontario. Someone brought it here. On purpose.",
  "ELI: The night boats. Tuesdays and Fridays. They come in to the old mill pier around two in the morning. Dad says he can hear the crates hissing.",
  "~Something about the way he says \"Dad\" makes you turn and look up at the house."],
  fx:{clue:"lancehead"}, next:"e3_dinner"},

e3_dinner:{ep:3, place:"Marsh house kitchen", time:"Wed 18:30", lines:[
  "~A warm, cramped kitchen. Fish stew, fresh bread, a wood stove ticking. Walter Marsh, seventy-two, big scarred hands and a cough he tries to hide in his sleeve. Tess sets the table and squeezes your arm as she passes.",
  "WALTER: Eli says you're Nila's brother. She ate at this table every Sunday. Told terrible jokes.",
  "~His voice. You've heard it before. On a tape, in a cramped room, whispering about barrels."],
  fx:{flag:"met_walter"},
  choices:[
    {t:"\"You called Nila's show. The night before it was cut.\"", sub:"Confront him now.", to:"e3_walter", fx:{trust:{walter:-1}}},
    {t:"Say nothing and eat", sub:"Wait for him to tell it.", to:"e3_walter", fx:{trust:{walter:1}}}
  ]},
e3_walter:{ep:3, place:"Marsh house kitchen", time:"Wed 19:00", lines:[
  "~Walter puts his spoon down. The kitchen goes quiet.",
  "WALTER: Yes. That was me.",
  "WALTER: Old Merrow was my village. School, church, my mother's grave. In seventy-seven the mill paid boys fifty dollars a night to roll barrels down into the valley, around the old church, before the dam closed. Said it was safe. Said the water would cover it.",
  "WALTER: I bought Margaret's wedding ring with that money.",
  "TESS: Dad.",
  "WALTER: And now it's happening again. New barrels, every week, same place. But this time it isn't paper waste. It smells like a hospital. And the boats bring crates. Live ones."],
  next:"e3_house"},
e3_house:{ep:3, place:"Marsh house", time:"Wed 19:30", lines:["~After dinner, Walter falls asleep in his chair. Eli washes dishes. You look around."],
  puzzle:{type:"search", title:"The Marsh house", prompt:"Look around the house.", need:2, doneLabel:"Find Eli", to:"e3_map", spots:[
    {t:"A drawer in the hall", text:"Walter's old mill ID badge. MERROW PAPER MILL — W. MARSH — 1977. The photo shows a skinny boy with Eli's jaw."},
    {t:"A framed photo above the stove", text:"Old Merrow before the flood. A main street, a schoolhouse, a stone church with a tall spire. Children on the church steps in Sunday clothes."},
    {t:"A newspaper clipping on the fridge", text:"2011. \"Local man, 61, dies of rare lung illness.\" Harold Vane. Ruth's husband. Someone has written \"the lake\" in pencil in the margin."},
    {t:"Tess's room, door open", text:"A Toronto bus schedule taped above her bed, routes highlighted. A jar of tips with a label: \"OUT\"."}
  ]}},

e3_map:{ep:3, place:"Eli's room", time:"Wed 19:45", lines:[
  "~Eli brings a shoebox from under his bed.",
  "ELI: Nila left this on my boat. When she disappeared I tore it up. I don't know why. I couldn't look at it. Then I couldn't throw it away.",
  "~Pieces of a hand-drawn map. Nila's handwriting. Street names. You lay Walter's photo of Old Merrow beside them and match each piece, from the shore up to the church."],
  puzzle:{type:"order", title:"Reassemble the map", prompt:"Put the pieces in order, from the lakeshore up the hill to the church.", to:"e3_map2", items:["Dock Lane (the shoreline)","Mill Street (the mill's loading road)","Main Street (the general store)","School Row (the schoolhouse)","Church Hill (St. Brendan's)"], hints:["Start at the water.","The church is at the top of the hill."], giveUp:3, answerText:"Shore, mill street, main street, school, church."}},
e3_map2:{ep:3, place:"Eli's room", time:"Wed 19:55", lines:[
  "~The map is whole. Three marks in Nila's red pen.",
  "~An X on the drowned church: \"barrels — dive here\".",
  "~The old mill pier, Pier 3: \"boats Tue/Fri 02:00\".",
  "~And at the far end of the lake, a little tower symbol on a headland: \"PP. Jonah. Safe.\"",
  "MANI: PP. It's in her radio log. Every night. PP.",
  "ELI: Pike Point. There's an old radio tower out there. Nobody goes out there except a crazy old guy. Jonah Pike."],
  fx:{clue:"map"}, next:"e3_porch"},

e3_porch:{ep:3, place:"Marsh house porch", time:"Wed 20:15", lines:[
  "~Tess walks you to the porch. Wind off the lake. She hugs herself.",
  "TESS: Everybody here's waiting for something to come up out of that lake. Me, I'm just waiting for a bus.",
  "TESS: Corbin came by the diner again today. He asked if I'd seen \"the brother\"."],
  choices:[
    {t:"\"Nobody's going to touch you. I promise.\"", sub:"Promise to protect her.", to:"e3_porch_a", fx:{flag:"protectTess", trust:{tess:1, eli:1}}},
    {t:"\"Then tell me everything Corbin asked you.\"", sub:"Get information.", to:"e3_porch_b"}
  ]},
e3_porch_a:{ep:3, place:"Marsh house porch", time:"Wed 20:17", lines:[
  "~Tess looks at you for a long time. Then she nods once, like she's decided to believe it.",
  "TESS: Okay. (beat) Okay.",
  "~Behind the screen door, Eli has heard every word."], next:"e3_boat"},
e3_porch_b:{ep:3, place:"Marsh house porch", time:"Wed 20:17", lines:[
  "TESS: He asked if Nila ever talked about Pike Point. I said no. That was a lie. She talked about it all the time.",
  "~So the villains already suspect where Nila is."],
  fx:{flag:"corbinKnowsPP"}, next:"e3_boat"},

e3_boat:{ep:3, place:"Lake Merrow, Eli's skiff", time:"Thu 01:30", lines:[
  "~Eli rows you out with the engine off. Fog as thick as milk. You can't see the bow of the boat. St. Brendan's bell tolls the half hour from the shore.",
  "ELI: Pier 3 is northeast of the church bell. Steer by the sound. Keep it over your left shoulder.",
  "~The bell rings. It sounds like it's coming from behind you, slightly to the right."],
  choices:[
    {t:"Turn left until the bell is over your left shoulder", to:"e3_pier"},
    {t:"Row straight ahead", to:"e3_boat_wrong"},
    {t:"Turn right toward the bell", to:"e3_boat_wrong"}
  ]},
e3_boat_wrong:{ep:3, place:"Lake Merrow", time:"Thu 01:40", lines:[
  "~A hollow knock under the hull. The boat lurches. Eli flinches and grabs the gunwale.",
  "ELI: Rooftop. The old village. We're right over it.",
  "~Somewhere beneath you, a drowned house. You hold your breath until the boat slides free. The bell rings again; this time you keep it over your left shoulder."],
  next:"e3_pier"},
e3_pier:{ep:3, place:"Off the old mill pier", time:"Thu 02:00", lines:[
  "~Floodlights through the fog. An unmarked boat ties up at the old mill pier. Men pass crates up a ramp. Some crates have air holes and are stencilled LIVE BAIT — KEEP WARM. Blue barrels roll the other way, down onto the boat.",
  "~A man in a tailored wool coat supervises with a coffee cup. Victor."],
  puzzle:{type:"search", title:"Binoculars", prompt:"Photograph what you can before the light comes round.", need:3, doneLabel:"Duck down", to:"e3_light", spots:[
    {t:"A crate label", text:"MANIFEST 0412 — CONSIGNEE: M. HAYDEN, WINDSOR, ON. Windsor. Your city.", clue:"manifest"},
    {t:"A small cage", text:"A worker lifts a small cage into the light. Enormous round eyes blink out of it. A slow loris. You've seen them in videos people share, being tickled. You didn't know they were smuggled."},
    {t:"Victor on the phone", text:"Victor laughs into his phone, and the water carries every word: \"Tell Hades it'll be clean by Friday. The girl's the only loose end.\" A pause. \"And the brother.\"", clue:"hadesName"},
    {t:"The water tower on the hill", text:"Above the pier, on the old water tower, a tiny red light. Not a warning light. It moves, just slightly. Someone up there with a radio, watching the pier. Watching you."}
  ]}},
e3_light:{ep:3, place:"Off the old mill pier", time:"Thu 02:06", lines:["~A searchlight swings across the water toward the skiff."],
  timer:{secs:7, to:"e3_light_c", fx:{danger:2}},
  choices:[
    {t:"Lie flat in the bottom of the boat", to:"e3_light_a"},
    {t:"Row hard into the fog", to:"e3_light_b", fx:{danger:1}},
    {t:"Drift and hope", to:"e3_light_c", fx:{danger:2}}
  ]},
e3_light_a:{ep:3, place:"Lake Merrow", time:"Thu 02:07", lines:["~You press your faces into the wet planks. The light passes over the boat like a hand. It doesn't stop. Eli exhales."], next:"e3_fire"},
e3_light_b:{ep:3, place:"Lake Merrow", time:"Thu 02:07", lines:["~The oars splash. The light swings back and finds your wake. A shout from the pier. Then the fog closes and you're gone."], next:"e3_fire"},
e3_light_c:{ep:3, place:"Lake Merrow", time:"Thu 02:07", lines:["~The light lands full on the skiff. For one long second you are lit up like a stage. Victor lowers his coffee cup. Then the fog rolls between you."], next:"e3_fire"},

e3_fire:{ep:3, place:"Marsh family dock", time:"Thu 02:40", lines:[
  "~Orange light through the fog before you can see the dock. Margaret, the family trawler, is on fire. Walter is on the dock in his undershirt with a garden hose. Tess is screaming for help.",
  "~Eli jumps onto the dock and runs to his father. You reach the white bucket behind the crab traps.",
  "~The lid is off. The bucket is empty.",
  "~On the post beside it, pinned with a fishing knife: a photo of Tess serving coffee at the diner, taken through the window. On the back, in neat handwriting:",
  "~\"Bait.\"",
  "~On the road above, a sheriff's cruiser rolls slowly away with its lights off."],
  fx:{clue:"knifephoto", danger:1}, next:"e3_end"},
e3_end:{ep:3, place:"Greyhaven", time:"Thu 02:45", lines:["~End of Episode 3."], epEnd:true}
});
