/* Part 2 · Episode 1 · Lighthouse */
Object.assign(window.OTT_PARTS.p2.scenes, {
p2e1_open:{ep:1, card:true, radio:true, place:"Windsor radio studio", time:"23:40", lines:[
  "~A small studio, red ON AIR light. Nila, twenty-six, headphones on, hosting her new late show on a Windsor station.",
  "NILA (ON AIR): …and that's why you never trust a man who says he \"doesn't really like music\". Next up, something slow for the night shift—",
  "~She coughs. Covers her mouth. Looks at her palm. Blood. She keeps her voice perfectly steady.",
  "NILA (ON AIR): —here it is.",
  "~She presses play. The song starts. She slides off her chair onto the floor. The ON AIR light stays red."],
  next:"p2e1_hosp"},
p2e1_hosp:{ep:1, place:"Hospital, Windsor", time:"Five days later", lines:[
  "~A blur. You and Preethi running through emergency doors. Scans. Waiting rooms. Preethi in her hospital pharmacy uniform, between shifts. An oncologist, Dr. Singh, with a tablet.",
  "DR. SINGH: It's aggressive. And it's atypical. Honestly, I've never seen a progression like this. We'll start treatment, but I won't pretend I understand it.",
  "~Preethi reads the blood panel over his shoulder. She stops on one line.",
  "PREETHI: What's this compound? It's not on any standard panel.",
  "DR. SINGH: The lab flagged it as an artefact.",
  "PREETHI: (quietly, to you) It's not an artefact.",
  "~Amma and Appa arrive from Chennai, still in travel clothes. Amma takes Nila's hand.",
  "AMMA: Kanna… enna aachu unakku? || My dear… what happened to you?",
  "NILA: Onnum illa, Amma. Konjam blood, avlo dhaan. || It's nothing, Amma. Just a little blood, that's all.",
  "APPA: Unmaiya sollu. Evlo serious? || Tell me the truth. How serious?",
  "MANI: Romba serious, Appa. || Very serious, Appa."],
  fx:{clue:"panel", setHealth:80}, next:"p2e1_case"},
p2e1_case:{ep:1, place:"Nila's hospital room", time:"Night", lines:[
  "~Nila props herself up, a notepad on her knees. You and Preethi on the visitor chairs.",
  "NILA: Okay. Treat it like a case. Exposure. Opportunity. Motive.",
  "NILA: Exposure: Old Merrow. I dived in that water twice. But Anna, you dived too, and you're fine.",
  "MANI: So it's something only you had.",
  "NILA: Pike Point. Six days in that shed. (beat) The water bottles.",
  "~She hands you her ham handheld.",
  "NILA: Call Jonah. He's always on, after dark."],
  puzzle:{type:"tune", title:"Call Jonah", prompt:"Nila: \"Jonah listens on 146.52, the national calling frequency. Everybody knows it.\"", min:144, max:148, step:0.01, startAt:144, target:146.52, tol:0.03, decimals:2, unit:"MHz", hints:["146.52 MHz.","Slide slowly near the middle of the dial."], giveUp:4, answerText:"146.52.", to:"p2e1_jonah"}},
p2e1_jonah:{ep:1, radio:true, place:"Nila's hospital room", time:"Night", lines:[
  "JONAH (ON RADIO): Pike Point, go ahead. (beat) Nila? Kid, is that you?",
  "NILA: Jonah. The water in the shed. Did you leave it for me?",
  "JONAH (ON RADIO): I told you last year, kid. I never brought you water.",
  "~Nila lowers the radio.",
  "NILA: Yaaro naan andha thanni kudikkanumnu nenachirukkaanga, Anna. || Someone wanted me to drink that water, Anna.",
  "~Preethi has gone very still.",
  "PREETHI: If someone put something in it… there'd be a record. A supplier. A delivery.",
  "NILA: Then go and find it. Greyhaven. The mill. Victor kept everything."],
  fx:{clue:"jonahWater"}, next:"p2e1_drive"},

p2e1_drive:{ep:1, place:"County Road 20 / Tom Portons", time:"Night", lines:[
  "~You and Preethi drive east on the county roads you swore you'd never drive again. Preethi reads Nila's notes by phone light.",
  "PREETHI: She wrote \"GH-01\" here and circled it three times.",
  "~A Tom Portons stop. Harold and June at the window table.",
  "HAROLD: The data fella! June, it's the data fella!",
  "JUNE: Still on decaf, Harold, don't get excited.",
  "PREETHI: (whispering) You know these people?",
  "MANI: Long story. It involved a cat phone case."],
  next:"p2e1_mill"},
p2e1_mill:{ep:1, place:"Merrow Mill ruins, Greyhaven", time:"02:00", lines:[
  "~A blackened shell behind police tape. A private guard in a hut with a space heater. Ruth, a year older, scanner on her belt, shotgun on her shoulder, meets you at the fence.",
  "RUTH: Corbin's in prison. Victor's in the ground. And nobody in this town says the name Hades out loud.",
  "RUTH: (to Preethi) You must be the wife. He talks about you on the phone to Nila. Nauseating.",
  "RUTH: Guard changes at two-fifteen. You've got ten minutes.",
  "~Preethi climbs the water tower ladder with binoculars. You wait at the fence for her call."],
  next:"p2e1_mill2"},
p2e1_mill2:{ep:1, place:"Mill yard", time:"02:04", lines:[
  "PREETHI (ON RADIO): He's in the hut. Heater's on. He's watching something on his phone. Go now. Stay left, along the wall.",
  "~You cross the yard in the shadows. Halfway, Preethi's voice again, sharp:",
  "PREETHI (ON RADIO): Stop. He's standing up."],
  timer:{secs:6, to:"p2e1_mill3", fx:{danger:1}},
  choices:[
    {t:"Freeze against the wall", to:"p2e1_mill3"},
    {t:"Keep moving, fast", to:"p2e1_mill3", fx:{danger:1, toast:"Gravel crunches. The guard's flashlight swings out."}}
  ]},
p2e1_mill3:{ep:1, place:"Ruins of Victor's office", time:"02:07", lines:[
  "PREETHI (ON RADIO): …He's just stretching. Okay. Go.",
  "~Victor's office is a burned box open to the sky. In the corner, his fireproof safe survived, blackened but whole. A keypad. You remember this keypad. You remember his love of anniversaries."],
  puzzle:{type:"code", title:"Victor's safe", prompt:"Victor's codes always remembered \"the day it all began\": the day he took over the mill.", placeholder:"####", answer:["0314","314"], hints:["March 14, 2019.","Month and day: 0314."], giveUp:3, answerText:"0314.", to:"p2e1_safe"}},
p2e1_safe:{ep:1, place:"Ruins of Victor's office", time:"02:09", lines:[
  "~The safe door swings open. Ash and papers. Two things matter.",
  "~A shipping label: \"NORTHSTAR BIOLOGICS — HX-7 — HAYDEN DEEP, RED LAKE, ON.\"",
  "~A delivery note: \"24 × spring water, 1 L. Pike Point. Attn: GH-01.\" Dated the week Nila hid there.",
  "MANI (INTO RADIO): Anni. GH-01. It's her. She was a subject. A test subject.",
  "~Silence on the radio. Then, very tight:",
  "PREETHI (ON RADIO): Get out. Guard's coming your way."],
  fx:{clue:["label","delivery"]},
  timer:{secs:6, to:"p2e1_safe_run", fx:{danger:1}},
  choices:[{t:"Hide behind the safe", to:"p2e1_safe_hide"},{t:"Run for the fence", to:"p2e1_safe_run", fx:{danger:1}}]},
p2e1_safe_hide:{ep:1, place:"Mill ruins", time:"02:11", lines:["~The flashlight passes over the ash a metre from your boots. The guard yawns, scratches, and walks back to his heater. You slip out the way you came."], next:"p2e1_plan"},
p2e1_safe_run:{ep:1, place:"Mill ruins", time:"02:11", lines:["~The guard shouts. Before he reaches the fence, a shotgun blast booms into the sky from the road. Ruth. The guard dives for his hut. You're over the fence and gone."], next:"p2e1_plan"},

p2e1_plan:{ep:1, place:"Nila's hospital room", time:"Next day", lines:[
  "~The label and the note on Nila's bed tray. Nila looks stronger, the way people do when they have a job.",
  "NILA: Red Lake. Northwestern Ontario. Gold country. End of the road. (She taps the label.) Northstar Biologics, registered 2015. Director: M. Hayden. The same Hayden from the plaque at the station. Victor's \"Mark\".",
  "NILA: He's not hiding, Anna. He's waiting.",
  "PREETHI: Then we take it to the police.",
  "NILA: With what? A label from a burned building. Ortiz already tried; the OPP said Greyhaven is closed. (beat) Hades has the cure. I'd bet my life on it. I am betting my life on it.",
  "MANI: Then we go.",
  "NILA: Then you go prepared. Kane's people shot at you in Greyhaven. Up there it'll be worse. (beat) Which brings us to the guns.",
  "PREETHI: We can buy hunting rifles, right? People up north have them.",
  "NILA: Legally? A licence takes months: a course, a test, background checks. An M4-style rifle is prohibited in Canada, full stop. A Desert Eagle is a restricted handgun; you'd need a special licence just to drive it anywhere. Grenades, forget it.",
  "NILA: We don't have months, Anni. I have weeks.",
  "MANI: So what are you saying?",
  "NILA: I studied criminals for four years. Tonight I need one. (She opens her laptop.) Rocco Delisle. Auto body shop off Wyandotte West. Charged twice, never convicted. Brings guns over the river from Detroit. I covered his second trial for a class project. I know what he sells, what he charges, and that he's terrified of court.",
  "PREETHI: Nila, this is a crime.",
  "NILA: So is what's happening in my blood. (beat) Anni, I'll understand if you don't go."],
  choices:[
    {t:"\"Naan varen. Nee en thangachi maadhiri.\"", sub:"PREETHI: I'm coming. You're like my own little sister.", to:"p2e1_deal"},
    {t:"\"I'm coming. But we use them only to survive.\"", sub:"PREETHI: Restraint.", to:"p2e1_deal", fx:{flag:"restraint"}}
  ]},

p2e1_deal:{ep:1, place:"Under the Ambassador Bridge, Windsor", time:"23:00", lines:[
  "~Rain. The bridge's lights above, trucks rumbling across to Detroit. A grey van with its rear doors open. Rocco Delisle, fifties, leather jacket, two silent men behind him.",
  "~Nila is on the radio in your ear, from her hospital bed.",
  "NILA (ON RADIO): Let him talk first. He likes the sound of his own voice.",
  "ROCCO: The radio girl's brother. She sent me a very polite message. Mentioned my court dates. Very polite.",
  "~He opens a case.",
  "ROCCO: Pump shotgun, twelve-gauge. M4, clean, no serial. Two Desert Eagles. Ammo. Forty grand.",
  "NILA (ON RADIO): He charged the last buyer twenty-two. Say twenty-five."],
  choices:[
    {t:"\"Twenty-five. Cash.\"", to:"p2e1_deal2", fx:{set:{price:26}}},
    {t:"\"Fine. Forty.\"", to:"p2e1_deal2", fx:{set:{price:40}}},
    {t:"\"You charged the last guy twenty-two, Rocco.\"", to:"p2e1_deal2", fx:{set:{price:24}, toast:"Rocco's smile slips."}}
  ]},
p2e1_deal2:{ep:1, place:"Under the Ambassador Bridge", time:"23:04", lines:s => [
  s.vars.price <= 26 ? "ROCCO: (sighing) Your sister should be a lawyer. " + s.vars.price + "." : "ROCCO: Pleasure doing business with a reasonable man.",
  "~Preethi steps forward to inspect the weapons. She handles them like she handles a pharmacy order: everything checked, nothing assumed."],
  puzzle:{type:"pick", title:"Inspect the guns", prompt:"Preethi compares the two Desert Eagles side by side. One of them is wrong. What's wrong with it?", to:"p2e1_deal3", options:[
    {t:"The slide is scratched", why:"Scratches are cosmetic. It'll still fire."},
    {t:"The firing pin has been filed down; it won't fire", correct:true},
    {t:"The magazine is a different colour", why:"Aftermarket magazines are common. Not the problem."},
    {t:"It's heavier than the other", why:"Within a few grams. Normal."}
  ]}},
p2e1_deal3:{ep:1, place:"Under the Ambassador Bridge", time:"23:07", lines:[
  "PREETHI: This one's dead, Rocco. The pin's filed.",
  "~Rocco laughs and swaps it from the van without argument.",
  "ROCCO: Your sister said you were sharp. She didn't say it was the wife.",
  "~Headlights on the riverfront road above. A police cruiser, rolling slowly.",
  "NILA (ON RADIO): Patrol car, westbound. Ninety seconds. Close the doors."],
  timer:{secs:8, to:"p2e1_deal_run", fx:{danger:1}},
  choices:[
    {t:"Close the van doors and stand like you're chatting", to:"p2e1_deal_ok"},
    {t:"Grab the cases and run for the car", to:"p2e1_deal_run", fx:{danger:1}}
  ]},
p2e1_deal_ok:{ep:1, place:"Under the Ambassador Bridge", time:"23:09", lines:[
  "~The cruiser slows. An officer glances down at three men and a woman by a van in the rain. Rocco lifts a coffee cup in greeting. The cruiser rolls on.",
  "ROCCO: No grenades. I'm not crazy. (He pockets the cash.) And tell your sister: if she ever mentions my court dates again, I'll stop being polite."],
  fx:{clue:"guns", ammo:{rifle:120, shells:30, pistol:42}}, next:"p2e1_shop"},
p2e1_deal_run:{ep:1, place:"Under the Ambassador Bridge", time:"23:09", lines:[
  "~The cruiser's brake lights flare. Rocco's men scatter. You throw the cases into your trunk and Rocco shouts the last of the ammo boxes after you. You're gone before the cruiser turns.",
  "~You got the guns. Less ammunition than you paid for."],
  fx:{clue:"guns", ammo:{rifle:80, shells:20, pistol:28}}, next:"p2e1_shop"},

p2e1_shop:{ep:1, place:"Outdoor store, Windsor", time:"Day 1, 09:00", lines:[
  "~Day 1. Nila reads the list over the radio from her bed while you and Preethi push a cart through a huge outdoor store.",
  "NILA (ON RADIO): Red Lake in November can drop below minus thirty at night. Phones die in the cold. The cell signal ends before Red Lake does. Do not drink any water up there you didn't filter yourself. Ever.",
  "NILA (ON RADIO): Ever, Anna."],
  puzzle:{type:"multi", title:"The shopping list", prompt:"Pick everything Nila would approve. Leave out what will get you killed or slow you down.", submit:"Check out", to:"p2e1_pack", options:[
    {t:"Parkas rated to −40°C", correct:true},
    {t:"Cotton jeans and sneakers"},
    {t:"Sleeping bags rated to −30°C", correct:true},
    {t:"Water filter and purification tablets", correct:true},
    {t:"Trauma kit: tourniquets, chest seals, clotting gauze", correct:true},
    {t:"A drone for scouting", correct:true},
    {t:"Bear spray, flares, hand warmers", correct:true},
    {t:"A big cooler of bottled water from home"},
    {t:"Paper maps and a compass", correct:true},
    {t:"Winter tyres, chains, a shovel, two jerry cans", correct:true}
  ], hints:["Cotton kills in the cold: it holds water. Bottled water freezes and isn't needed if you filter.","Everything rated for cold, plus medical, navigation, survival, and the car. Nothing cotton, no bottled water."], giveUp:3, answerText:"Everything except the cotton clothes and the cooler of bottled water.", fx:{medkits:3}}},
p2e1_pack:{ep:1, place:"Your building's parking lot", time:"Day 1, 11:30", lines:["~Now it all has to fit in the trunk."],
  puzzle:{type:"order", title:"Pack the trunk", prompt:"Load the trunk in order, from the first thing in (bottom, back) to the last thing in (top, front).", to:"p2e1_bye", items:["Long gun cases, flat on the floor","Jerry cans and tools, wedged at the sides","Sleeping bags and tent, on top of the cases","Food crate, where you can reach it","Medical kit, last in, first out"], hints:["Heavy and flat at the bottom.","The thing you need fastest goes in last."], giveUp:3, answerText:"Guns flat, heavy at the sides, soft on top, food reachable, medical last."}},
p2e1_bye:{ep:1, place:"Curbside, Windsor", time:"Day 1, 12:00", lines:[
  "~At the curb, Amma presses a steel box into Preethi's hands.",
  "AMMA: Puliyodharai. Sudbury-ku munnadi saapdunga. || Tamarind rice. Eat it before Sudbury.",
  "APPA: Naanum varen. || I'm coming too.",
  "MANI: Appa, venaam. Nila-va paathukkonga. Adhu dhaan unga velai. || No, Appa. Look after Nila. That's your job.",
  "~Appa nods slowly and holds your face in both hands. He doesn't say anything. He doesn't have to.",
  "~Preethi gets in the passenger seat and puts on her seatbelt with great precision, the way she does when she's frightened."],
  next:"p2e1_parry"},

p2e1_parry:{ep:1, place:"Tom Portons near Parry Sound", time:"Day 1, 16:00", lines:[
  "~Highway 401, then 400 north. Rock cuts and pine. At a Tom Portons near Parry Sound, a woman in a grey coat jumps up from her booth.",
  "WOMAN: My bag! My laptop bag was right here!"],
  puzzle:{type:"search", title:"The Missing Laptop Bag", prompt:"Find it.", need:3, doneLabel:"Go to the parking lot", to:"p2e1_parry2", spots:[
    {t:"Her booth", text:"A coffee, a half-eaten muffin, a notebook full of shorthand. Wet sneaker tracks lead from the booth to the side door."},
    {t:"The teen at the counter", text:"He keeps glancing out at the parking lot, then at the woman, then at his phone."},
    {t:"Her phone", text:"She shows Preethi a tracker app. Her bag's tag: moving slowly, twenty metres away, in the lot."},
    {t:"The side door", text:"Propped with a napkin. Outside, a rusty hatchback with two kids in it, laughing."}
  ]}},
p2e1_parry2:{ep:1, place:"Tom Portons parking lot", time:"Day 1, 16:08", lines:[
  "~Preethi taps on the hatchback window and gives the two boys a look she normally saves for doctors who prescribe the wrong dose. They hand the bag over without a word.",
  "WOMAN: Thank you. Really. (beat) I'm Ivy.",
  "~Ivy Laurent, mid-thirties. She thanks you a little too carefully. She glances at your face like she's checking it against a photo. Then she leaves, heading north."],
  fx:{flag:"met_ivy", trust:{ivy:1}}, next:"p2e1_sudbury"},
p2e1_sudbury:{ep:1, place:"Motel, Sudbury · Night 1", time:"Day 1, 22:00", lines:[
  "~A tired roadside motel. Through the window, the lit-up Big Nickel. You eat Amma's puliyodharai cross-legged on the bed.",
  "~Your phone buzzes: \"Unknown tracker detected travelling with you.\""],
  puzzle:{type:"search", title:"The Uninvited Passenger", prompt:"Search the car in the cold.", need:1, doneLabel:"Decide what to do with it", to:"p2e1_tracker", spots:[
    {t:"Front wheel wells", text:"Salt, slush, nothing."},
    {t:"Under the bumpers", text:"Your fingers go numb. Nothing."},
    {t:"Under the seats", text:"Fries. A hair tie. Nothing."},
    {t:"The spare tyre well", text:"Taped inside the spare tyre: a small black tracker the size of a coin. Someone put this here in Windsor."}
  ]}},
p2e1_tracker:{ep:1, place:"Motel lot, Sudbury", time:"Day 1, 22:20", lines:["PREETHI: Smash it?"],
  choices:[
    {t:"Smash it", to:"p2e1_day2", fx:{danger:1, toast:"Whoever's watching knows you found it."}},
    {t:"Stick it on a transport truck heading east", to:"p2e1_day2", fx:{toast:"Somewhere tonight, Northstar is following a load of frozen fries to Montreal."}}
  ]},

p2e1_day2:{ep:1, place:"Lake Superior shore", time:"Day 2", lines:[
  "~Day 2. Lake Superior opens up: huge, grey, empty, like the sea. Preethi presses her face to the window like a child.",
  "PREETHI: This is a lake? This is a LAKE?",
  "~At a Tom Portons in Sault Ste. Marie, the cashier is in tears. The staff tip jar has vanished."],
  puzzle:{type:"pick", title:"The Tip Jar", prompt:"There's a ring of coffee on the counter where the jar sat. There's a matching ring of coffee on the glove of a delivery driver unloading a crate of cups. What happened?", to:"p2e1_wawa", options:[
    {t:"The driver stole it", why:"He's whistling and in no hurry. Thieves don't whistle."},
    {t:"The driver knocked it into his crate by accident", correct:true},
    {t:"A customer took it", why:"No customer touched that end of the counter."}
  ], okMsg:"The jar is in the crate of cups, full and unbroken. The cashier hugs Preethi."}},
p2e1_wawa:{ep:1, place:"The Wawa goose", time:"Day 2, 16:30", lines:[
  "~At the giant Canada goose statue in Wawa, snow starting. Ivy is there, photographing it.",
  "PREETHI: That's not a coincidence."],
  next:"p2e1_ivy"},
p2e1_ivy:{ep:1, place:"Motel, Wawa · Night 2", time:"Day 2, 21:00", lines:[
  "~Ivy's room, two doors down. A laptop, maps, a bottle of wine she isn't drinking.",
  "IVY: Your sister emailed me last year. From Greyhaven. I never wrote back. (beat) I'm sorry. I was hiding.",
  "MANI: From who?",
  "IVY: From Northstar. I was a lab tech there for two years before I became a journalist. I saw what HX-7 does. I took a photo of one file, quit, and ran.",
  "~She draws a rough map of the surface buildings: gatehouse, office, loading dock, and a freight elevator that goes deeper than the mine maps say.",
  "NILA (ON RADIO): Put me on speaker. I want to ask her three things. In the right order."],
  fx:{clue:"ivyMap"},
  puzzle:{type:"order", title:"Nila's questions", prompt:"Nila builds an interview like a trap: easy questions first, the dangerous one last. Put the questions in Nila's order.", to:"p2e1_ivy2", items:["\"What was your badge number at Northstar?\" (easy to check)","\"Who was your supervisor?\" (a name we can verify)","\"What colour is HX-7 in the vial?\" (only a real tech would know)","\"Why didn't you answer my email?\" (the emotional one, last)"], hints:["Verifiable facts first.","The emotional question goes last, when she's relaxed."], giveUp:3, answerText:"Badge, supervisor, the vial, then the email."}},
p2e1_ivy2:{ep:1, place:"Motel, Wawa", time:"Day 2, 21:20", lines:[
  "IVY: Badge 0417. Dr. Lund. Clear, with a faint blue tint under UV. (beat) And I didn't answer because I was scared, Nila. That's all. I'm sorry.",
  "NILA (ON RADIO): She's telling the truth. Mostly. (beat) Welcome to the team, Ivy."],
  fx:{trust:{ivy:2}}, next:"p2e1_cliff"},
p2e1_cliff:{ep:1, radio:true, place:"Your motel room, Wawa", time:"Day 3, 02:00", lines:[
  "~Snow on the window. Preethi asleep. You awake, the handheld on the bedside table, tuned to your private frequency.",
  "~It crackles. A calm voice. The voice from the water tower in Greyhaven.",
  "HADES (ON RADIO): Welcome to the north, Mani. Bring the file. (beat) And tell your sister: GH-01 is doing very well.",
  "~Preethi's eyes open in the dark."],
  fx:{danger:1, setHealth:75}, next:"p2e1_end"},
p2e1_end:{ep:1, place:"Wawa", time:"Day 3", lines:["~End of Episode 1."], epEnd:true}
});
