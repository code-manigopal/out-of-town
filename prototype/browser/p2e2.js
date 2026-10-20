/* Part 2 · Episode 2 · Highway 17 */
Object.assign(window.OTT_PARTS.p2.scenes, {
p2e2_open:{ep:2, card:true, place:"Highway 17, westbound", time:"Day 3, 08:30", lines:[
  "~Wawa behind you. Ivy's dented hatchback ahead. Snow on the shoulders. Preethi has the Hades recording on repeat on her phone.",
  "PREETHI: \"GH-01 is doing very well.\" He talks about her like a houseplant.",
  "NILA (ON RADIO): That's what he wants you to feel. Angry people make mistakes. (cough) Don't give him that.",
  "MANI: Nila, how are you feeling?",
  "NILA (ON RADIO): Amma made me eat idli at six a.m. I'm feeling attacked. (beat) Drive, Anna."],
  next:"p2e2_winnie"},
p2e2_winnie:{ep:2, place:"White River", time:"Day 3, 10:00", lines:[
  "~A tiny town. A sign: Home of Winnie. A statue of a bear cub in a tree: the real bear that inspired Winnie-the-Pooh. A cluster of kids and a frazzled teacher.",
  "TEACHER: Someone stole Winnie's scarf! The kids knitted it!",
  "~Red wool fibres on the bark of the statue's tree. Twigs and droppings under the gas station sign across the road. Through your binoculars: a nest on top of the sign, with a flash of red."],
  puzzle:{type:"pick", title:"Winnie's Scarf", prompt:"Who stole the scarf?", to:"p2e2_winnie2", options:[
    {t:"The gas station attendant", why:"He's been inside all morning. The fibres are on the tree."},
    {t:"A tourist souvenir hunter", why:"Then why is there red wool in a nest?"},
    {t:"A crow", correct:true},
    {t:"The kids, as a prank", why:"They're genuinely upset. And they can't reach the top of that sign."}
  ]}},
p2e2_winnie2:{ep:2, place:"White River", time:"Day 3, 10:15", lines:[
  "~Preethi climbs the gas station ladder, retrieves the scarf, and is attacked by an extremely angry crow. The kids cheer. You film all of it.",
  "NILA (ON RADIO): Anni lost a fight to a crow. Best day of my life.",
  "PREETHI: I WON. I have the scarf. I won.",
  "~At the pumps, a trucker with a grey beard and a CB radio watches you fill up.",
  "BIG LOU: You folks headed west? Two black SUVs been running Highway 17 all week. No front plates. They stop where nobody stops. (He spits.) You hear \"Kane\" on channel nineteen, you get off the road."],
  next:"p2e2_nipigon"},
p2e2_nipigon:{ep:2, place:"Nipigon / Lake Superior", time:"Day 3, 16:30", lines:[
  "~The cable-stayed bridge over the Nipigon River. Superior's frozen edge. At sunset, the Sleeping Giant on the horizon across the bay. Preethi asks you to stop the car. You stand in the cold and watch it.",
  "PREETHI: Nee bayappadriya? || Are you scared?",
  "MANI: Romba. || Very. (beat) You?",
  "PREETHI: I'm a pharmacist, Mani. Last month my biggest problem was a doctor's handwriting.",
  "~She puts her cold hand in your coat pocket with yours."],
  next:"p2e2_okafor"},
p2e2_okafor:{ep:2, place:"Dr. Okafor's house, Thunder Bay · Night 3", time:"Day 3, 20:00", lines:[
  "~A warm house full of books. Dr. Grace Okafor, sixty, Nila's former criminology professor. Jollof rice and tea. Nila on speaker.",
  "DR. OKAFOR: Nila was the best student I ever had, and she chose radio. I've never forgiven her.",
  "NILA (ON RADIO): You came to my first show.",
  "DR. OKAFOR: I came to judge it. (To you.) Tell me about the man."],
  puzzle:{type:"multi", title:"Build the profile", prompt:"Which conclusions does the evidence actually support? Choose all that apply.", submit:"Give Dr. Okafor the profile", to:"p2e2_okafor2", options:[
    {t:"He collects rare, dangerous animals → he needs control", correct:true},
    {t:"He talked to Nila on the radio for months → he needs an audience", correct:true},
    {t:"He sends gifts and taunts → he wants to seem generous, even while killing", correct:true},
    {t:"He shot Victor at 600 metres → he's patient and practised", correct:true},
    {t:"He hides in Red Lake → he's afraid of you"},
    {t:"He poisoned Nila → he's impulsive"}
  ], hints:["He planned the poisoning months in advance. Not impulsive.","He isn't hiding. He gave you his address on a shipping label."], giveUp:3, answerText:"Control, audience, false generosity, patience. Not fear. Not impulse."}},
p2e2_okafor2:{ep:2, place:"Dr. Okafor's house", time:"Day 3, 21:00", lines:[
  "DR. OKAFOR: He won't kill you from a distance, Mani. He'll want you in the room. He'll want to watch you choose.",
  "~She writes a name on a card.",
  "DR. OKAFOR: Constable Rachel Dunn, OPP, Red Lake. She was my student too. Honest. Too honest for her own good."],
  fx:{clue:["profile","dunnName"]}, next:"p2e2_storm"},

p2e2_storm:{ep:2, place:"Highway 17 near Ignace", time:"Day 4, 14:00", lines:[
  "~Whiteout. Visibility ten metres. A transport truck jackknifed across both lanes, hazard lights blinking in the snow.",
  "BIG LOU (ON CB): …whoever's westbound by Ignace, that's no accident, I just came through—",
  "~Two black SUVs slide out of the snow behind you. Doors open. Men in white parkas with rifles.",
  "KANE (ON RADIO): Mani. Just the file. Nobody has to freeze tonight.",
  "PREETHI: Mani.",
  "MANI: I know.",
  "~You have seconds. The whiteout is your friend: if you move now, they haven't seen where you went."],
  next:"p2e2_fight1"},
p2e2_fight1:{ep:2, place:"Highway 17 · whiteout", time:"Day 4, 14:02", lines:["~First fight. In stealth you can take them one by one in the snow. If they spot you, it turns into a firefight."],
  combat:{id:"ignace1", title:"Ambush at Ignace", intro:"Four men fan out from the SUVs. They can't see you in the whiteout. Yet.", note:"Stealth: take them down one at a time. Aggressive: open fire. Switch characters any time.", enemies:[{n:"Rifleman",hp:45},{n:"Rifleman",hp:45},{n:"Driver",hp:40},{n:"Spotter",hp:40}], to:"p2e2_fight2", cleanMsg:"Four men down in the snow, and not one of them ever saw you coming."}},
p2e2_fight2:{ep:2, place:"Highway 17 · the truck", time:"Day 4, 14:08", lines:["~A man on the roof of the jackknifed truck has seen the bodies. He opens up. The second SUV's driver tries to swing round to block your car."],
  combat:{id:"ignace2", title:"The truck roof", startAlert:true, intro:"They know you're here now.", enemies:[{n:"Man on the roof",hp:60},{n:"SUV driver",hp:50}], to:"p2e2_case"}},
p2e2_case:{ep:2, place:"Highway 17", time:"Day 4, 14:15", lines:[
  "~Silence, except the wind. Ivy's hatchback is full of bullet holes. Ivy is crouched behind it, shaking, unhurt.",
  "~In the back of an SUV: a hard case stencilled NSB. Inside, in grey foam, six fragmentation grenades.",
  "PREETHI: (staring at it) These are grenades, Mani. Real grenades.",
  "NILA (ON RADIO): Then they're your grenades now. Put them in the trunk, Anni.",
  "~You each take two. The rest go in the trunk."],
  fx:{trunk:6, restock:true}, next:"p2e2_dryden"},
p2e2_dryden:{ep:2, place:"Motel, Dryden · Night 4", time:"Day 5, 07:30", lines:[
  "~A motel by the highway. Preethi patches a graze on your arm. Neither of you sleeps much.",
  "~Morning. The car won't start. There's fuel on the snow under the engine."],
  fx:{heal:90},
  puzzle:{type:"search", title:"The Fuel Line", prompt:"Someone cut it. Find out who.", need:3, doneLabel:"Confront the culprit", to:"p2e2_tyler", spots:[
    {t:"The snow by the car", text:"Fresh boot prints. Big, new tread, crisp edges. They come from the motel office door, go to your car, and go back."},
    {t:"The fuel line", text:"Cut with a blade. Clean. Not an accident, not the cold."},
    {t:"The night clerk", text:"Tyler, twenties, wearing brand-new winter boots. There's $200 in crisp new bills in his tip cup."},
    {t:"The office trash can", text:"Under a coffee cup: a Northstar Biologics business card."}
  ]}},
p2e2_tyler:{ep:2, place:"Motel office, Dryden", time:"Day 5, 07:45", lines:["~Tyler sees your face and goes white."],
  choices:[
    {t:"Report him to the OPP", to:"p2e2_tyler_a"},
    {t:"Flip him: \"Tell us who paid you, and we never met.\"", to:"p2e2_tyler_b", fx:{clue:"convoy", flag:"tylerFlipped"}}
  ]},
p2e2_tyler_a:{ep:2, place:"Motel office, Dryden", time:"Day 5, 08:30", lines:["~An OPP cruiser takes Tyler away. He won't say a word. A man with a scar on his chin paid him, is all he'll admit. You lose an hour giving statements."], next:"p2e2_ear"},
p2e2_tyler_b:{ep:2, place:"Motel office, Dryden", time:"Day 5, 07:50", lines:[
  "TYLER: A guy paid me. Big. Scar on his chin. Said you were thieves.",
  "TYLER: Every Thursday night they run a convoy up 105. Northstar trucks. They stop for fuel at Ear Falls at nine. Three trucks, sometimes four. Please don't tell anyone I told you."], next:"p2e2_ear"},
p2e2_ear:{ep:2, place:"Highway 105 / diner, Ear Falls", time:"Day 5, 13:00", lines:[
  "~Ivy and you fix the fuel line with tape and a hose clamp from her trunk. She turns back toward Dryden to get her own car repaired: \"I'll catch up in Red Lake.\"",
  "~Highway 105 narrows to two lanes. Forest on both sides for 170 km. No cell signal. Then Ear Falls: a dam, a gas station, a diner. Pie and coffee.",
  "NILA (ON RADIO, WEAK): Anna. Anni. Naan ungala nenachu romba perumai padaren. || I'm so proud of you both. (beat) Okay, that's enough emotions. Eat your pie."],
  fx:{setHealth:70}, next:"p2e2_arrive"},
p2e2_arrive:{ep:2, place:"Red Lake", time:"Day 5, 17:00", lines:[
  "~Snow falling. A gold-mining town on a frozen lake. Headframes against a violet sky. On the waterfront, the Norseman floatplane monument, frosted white.",
  "PREETHI: It's beautiful.",
  "MANI: Everything up here is beautiful. That's what scares me.",
  "~The Northern Star Motel: twelve rooms, a coffee pot, a moose head over the desk. The owner, Bev Arsenault, reading glasses on her head, eyes your long cases.",
  "BEV: Hunting?",
  "MANI: Something like that.",
  "BEV: Mm. Last person I had who was \"something like that\" was a girl from Toronto in 2024. Disappeared in the night, left her toothbrush. (She hands you a key.) Room seven. Checkout's at eleven. Murders are extra."],
  fx:{flag:"met_bev", trust:{bev:1}}, next:"p2e2_gift"},
p2e2_gift:{ep:2, place:"Room 7", time:"Day 5, 17:45", lines:[
  "~On the bed, a gift box with a silk ribbon. Preethi stops your hand.",
  "PREETHI: Wait. (She checks it like a package at the pharmacy: no wires, no smell.) Okay.",
  "~Inside, on tissue paper: the shed skin of a golden lancehead. And a photo of Nila asleep in her hospital bed in Windsor, taken from inside her room. A card, in neat handwriting:",
  "~\"Welcome to my town.\"",
  "MANI: Lighthouse! Nila! Answer me!",
  "~Static. Then Appa's voice, confused.",
  "APPA (ON RADIO): Mani? Ava thoongittu irukkaa. Enna aachu? || Mani? She's sleeping. What happened?",
  "MANI: Appa, room-la yaarachum vandhaangala? || Appa, has anyone been in the room?",
  "APPA (ON RADIO): Oru doctor vandhaaru, kaalaila. Romba nalla manushan. Nila-ku flowers kondu vandhaaru. || A doctor came this morning. A very nice man. He brought Nila flowers."],
  fx:{clue:"gift", danger:1}, next:"p2e2_end"},
p2e2_end:{ep:2, place:"Red Lake", time:"Day 5", lines:["~End of Episode 2."], epEnd:true}
});
