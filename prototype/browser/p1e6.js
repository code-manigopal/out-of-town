/* Part 1 · Episode 6 · Old Merrow */
Object.assign(window.OTT_PARTS.p1.scenes, {
e6_open:{ep:6, card:true, place:"Nila's flat", time:"Fri 22:30", lines:[
  "~You, Eli and Ortiz, off duty in a hoodie, have searched the lakeshore for Ruth for four hours. Her skiff is gone from its mooring. That's all you found.",
  "~Ortiz leaves to cover his night shift so Corbin won't suspect him. Eli falls asleep in a chair, boots still on.",
  "~Your phone lights up. Amma, video call. It's Saturday morning in Vellore. Behind her, oil lamps lined up on the windowsill. Appa is hanging a string of mango leaves over the door.",
  "AMMA: Kanna! Naalaiku Deepavali. Nila-va kooppidu, rendu pasangalaiyum onna paakkanum. || Kanna! Tomorrow is Deepavali. Call Nila over, I want to see both my children together."],
  choices:[
    {t:"\"Amma, Nila-va kaanom. Naan thedittu irukken. Promise-aa kandupidipen.\"", sub:"Amma, Nila's missing. I'm searching for her. I promise I'll find her. (The truth.)", to:"e6_truth", fx:{flag:"honest6"}},
    {t:"\"Ava kulichittu irukka, Amma, naalaiku call pannuva.\"", sub:"She's having a bath, Amma, she'll call you tomorrow. (Protect them.)", to:"e6_lie"}
  ]},
e6_truth:{ep:6, place:"Nila's flat", time:"Fri 22:34", lines:[
  "~Amma's face crumples. She puts her hand over her mouth. Appa takes the phone from her, and his voice is steady.",
  "APPA: Appo kandupidi, kanna. Naanga vilakku yethi kaathirukkom. || Then find her, kanna. We'll light the lamps and wait.",
  "APPA: Mani. Airport-la unna anuppa vandhappo nee sonna, \"Naan avala paathukuren, Appa.\" Naan oru naalum sandhegapattadhilla. || Mani. When we came to see you off at the airport, you said, \"I'll look after her, Appa.\" I have never doubted it."],
  next:"e6_church"},
e6_lie:{ep:6, place:"Nila's flat", time:"Fri 22:34", lines:[
  "~Amma beams. She tells you what she's cooking. She tells you to make Nila wear the green silk. You say yes to everything.",
  "APPA: Mani. Airport-la unna anuppa vandhappo nee sonna, \"Naan avala paathukuren, Appa.\" Naan oru naalum sandhegapattadhilla. || Mani. When we came to see you off at the airport, you said, \"I'll look after her, Appa.\" I have never doubted it.",
  "~The call ends. You sit alone in the dark flat with the lie, and it is very heavy."],
  next:"e6_church"},

e6_church:{ep:6, place:"St. Brendan's church", time:"Sat 07:00", lines:[
  "~A small stone church on the hill, lit by candles. The bell rope hangs in a corner. An old priest pulls it for seven o'clock, slowly, exactly seven times.",
  "MANI: Last night it rang seven at six o'clock.",
  "FATHER REID: It did. Ruth Vane and I have an arrangement, from years ago, when she first started writing down trucks. If anyone ever came for her, I was to ring once more than the hour.",
  "FATHER REID: It means she got away. It means she's safe.",
  "MANI: Where?",
  "FATHER REID: She didn't tell me, so no one could make me tell them. But she left a message, if you came asking. (He reads from a folded paper.) \"Get the camera from the church. It's what Nila went back for. Then the water will bring you to me.\"",
  "MANI: This church?",
  "FATHER REID: No, son. The other one. The one underneath the lake."],
  next:"e6_archive"},
e6_archive:{ep:6, place:"St. Brendan's basement archive", time:"Sat 07:30", lines:[
  "~Rows of boxes. Parish records. Photographs of Old Merrow: a schoolhouse, a general store, a stone church with a tall spire, families in Sunday clothes.",
  "FATHER REID: I was born down there. Baptised in that church. When they flooded the valley, they promised us the water would be clean. They moved our dead up the hill. (beat) Not all of them."],
  puzzle:{type:"search", title:"The archive", prompt:"Look through the boxes.", need:3, doneLabel:"Go to Walter", to:"e6_walter", spots:[
    {t:"A box marked 1977", text:"A photo: mill trucks parked beside the old church before the flood. Young men rolling barrels down the slope. One of them, unmistakably, is a nineteen-year-old Walter Marsh."},
    {t:"Architect's drawings", text:"A plan of the old church: main doors at the west, a side door at the north into the bell tower, a crypt beneath the altar. Useful, if you were ever inside it underwater.", fx:{flag:"churchPlan"}},
    {t:"A box marked 1978", text:"The dam opening: a crowd, a ribbon, officials in hard hats. The caption: \"R. Hayden, Merrow Dam Authority, opens the gates.\" At the edge of the crowd, a figure in a long dark coat, face turned away. The same coat. The same posture. Forty-eight years ago.", clue:"photo1978"},
    {t:"A parish register", text:"Baptisms, weddings, funerals, 1842 to 1978. The last entry, in a shaking hand: \"The bell is moved to the new church. Let it ring for those below.\""}
  ]}},
e6_walter:{ep:6, place:"Marsh family dock", time:"Sat 09:30", lines:[
  "~You show Walter the 1977 photo. He looks at it for a long time.",
  "WALTER: Fifty dollars a night. I bought Margaret's ring with it. I've been paying for that ring my whole life.",
  "WALTER: I told Father Tom, in confession, forty years ago. He never told a soul. (He stands.) My old diving gear's in the shed. The hose is good. I'll run the compressor myself. Eli steers."],
  choices:[
    {t:"\"You were nineteen. Help me now and it counts.\"", sub:"Forgive him.", to:"e6_prep", fx:{flag:"forgaveWalter", trust:{walter:2, eli:1}}},
    {t:"\"You let this whole town get sick.\"", sub:"Hold it against him.", to:"e6_prep", fx:{trust:{walter:-1, eli:-1}}}
  ]},
e6_prep:{ep:6, place:"Lake Merrow, above Old Merrow", time:"Sat 11:00", lines:[
  "~Walter's old aluminium workboat. A small petrol compressor chugging on deck. A long yellow air hose. The fog is lifting into a grey, cold day.",
  "~You're in Walter's ancient wetsuit, a mask, a waterproof flashlight, Nila's map sealed in a plastic sleeve on your wrist. Your phone in a waterproof pouch.",
  "ELI: Three tugs on the line means pull you up. You tug three times, we pull. Don't be a hero.",
  "~You roll backward off the side."],
  fx:{set:{air:100}}, next:"e6_dive"},
e6_dive:{ep:6, place:"Underwater · Old Merrow", time:"Sat 11:10", lines:[
  "~Green darkness. Then shapes. A drowned village, perfectly still.",
  "~Your breath roars in your ears. The yellow hose trails up behind you to a pale disc of light."],
  puzzle:{type:"search", title:"Old Merrow", prompt:"Swim down the main street toward the church. Photograph what you find.", need:4, doneLabel:"Swim to the church", to:"e6_church_in", spots:[
    {t:"The schoolhouse", text:"A chalkboard still on the wall. Rows of rotted desks. A child's tin lunchbox on the floor, rusted shut."},
    {t:"The general store", text:"A faded sign: MERROW GENERAL — EST. 1891. A shelf of jars, still sealed, full of something dark."},
    {t:"The graveyard", text:"Headstones leaning in the silt. Some graves were never moved. \"Reid, Thomas and Agnes.\" Father Reid's grandparents."},
    {t:"The slope below the church", text:"The ground changes. Rusted 1977 barrels half-buried in silt. On top of them, dozens of newer blue barrels, some split open, leaking a slow milky cloud. Dead fish, belly up in the weeds. A sunken wire cage holding the shells of dead tortoises: animals that didn't survive the trip, dumped like rubbish. You photograph all of it.", clue:"dumping"}
  ]}},
e6_church_in:{ep:6, place:"Underwater · the drowned church", time:"Sat 11:20", lines:[
  "~You swim through the open doors of the church. Pews in rows. A fallen cross. A stained-glass window glowing faintly green. Barrels stacked to the rafters down the aisles.",
  "~In the front pew, wedged under the kneeler, where she must have dropped it when her own air ran low: a yellow dive-camera housing. NILA, in marker on the strap.",
  "~You pull it free. A barrel shifts above you. Then another. A slow avalanche of steel. Silt explodes into the water and the light goes brown."],
  fx:{flag:"camera"}, next:"e6_silt1"},
e6_silt1:{ep:6, place:"Underwater · zero visibility", time:"Sat 11:24", lines:s => [
  "~Brown nothing. Your flashlight shows only your own hand. Then, faintly: clank. Clank. Clank. Walter, tapping a wrench on the hull above. Louder to your left.",
  s.flags.churchPlan ? "~You remember the drawings: main doors west, bell tower door north." : "~You try to remember which way you came in."],
  choices:[
    {t:"Follow the tapping, left along the wall", to:"e6_silt2"},
    {t:"Back the way you came, toward the main doors", to:"e6_silt_bad"},
    {t:"Straight ahead, toward the altar", to:"e6_silt_bad2"}
  ]},
e6_silt_bad:{ep:6, place:"Underwater", time:"Sat 11:25", lines:["~Barrels. A wall of barrels where the doors were. The avalanche has blocked the main entrance. You turn back.","~The tapping, to your left."], next:"e6_silt2", fx:{add:{air:-20}}},
e6_silt_bad2:{ep:6, place:"Underwater", time:"Sat 11:25", lines:["~Your hand finds stone steps going down. The crypt. Absolutely not. You turn around, heart slamming.","~The tapping, to your left."], next:"e6_silt2", fx:{add:{air:-20}}},
e6_silt2:{ep:6, place:"Underwater · the church", time:"Sat 11:27", lines:["~Your glove finds a wooden door frame. A narrow doorway. Above it, the silt is thinner, and there's grey light."],
  choices:[{t:"Swim up through the bell tower", to:"e6_ascend"},{t:"Keep feeling along the wall", to:"e6_silt3"}]},
e6_silt3:{ep:6, place:"Underwater", time:"Sat 11:28", lines:["~The wall goes on. The tapping is directly above the doorway you just passed. You go back."], next:"e6_ascend"},
e6_ascend:{ep:6, place:"Underwater · ascending", time:"Sat 11:30", lines:[
  "~You rise through the drowned bell tower. Daylight above, a pale disc. The shadow of Walter's boat. And beside it, a second hull: longer, darker, an outboard idling.",
  "~You draw a breath from the regulator. Air comes. Then half a breath. Then nothing.",
  "~You look up. The yellow air hose drifts down past your face, cut clean. On the surface, a gloved hand pulls back into the second boat. A blade flashes.",
  "~You tug three times on the hose. It comes down limp into your hands.",
  "~Four metres to the surface. Your lungs burn. The light gets further away."],
  next:"e6_end"},
e6_end:{ep:6, place:"Lake Merrow", time:"Sat 11:31", lines:["~End of Episode 6."], epEnd:true}
});
