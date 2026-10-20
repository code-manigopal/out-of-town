/* Part 2 · Episode 6 · Starratt-Olsen */
Object.assign(window.OTT_PARTS.p2.scenes, {
p2e6_open:{ep:6, card:true, place:"Hayden Deep fence line", time:"Day 10, 00:31", lines:[
  "~In the two seconds before the floodlights reach you, Preethi does something fast: she shoves both Desert Eagles and the long guns into a snowbank behind a spruce and kicks snow over them.",
  "PREETHI: (under her breath) Illegal guns, Mani. Ninaivirukkaa? || Remember?",
  "~You step out with your hands up, Ivy between you. Dunn pats you down: a USB stick, a phone full of photographs, a pocket of dried fruit."],
  next:"p2e6_dunn"},
p2e6_dunn:{ep:6, place:"OPP detachment · interview room", time:"Day 10, 02:00", lines:[
  "~Dunn scrolls through the photos on your phone: the venom farm, the whiteboard, the GH-01 record. Ivy, wrapped in a blanket, gives a statement. Dunn's face changes.",
  "DUNN: You broke into a private facility. I should charge you both.",
  "MANI: Charge me. But read page four first.",
  "~She reads it. \"Keep her alive until the brother comes.\" She closes the laptop.",
  "DUNN: I can't get a warrant for Northstar on photos from a break-in. The judge in Kenora golfs with Hayden's lawyer. And half this town's mortgages are paid by that mine.",
  "DUNN: Officially, you were found lost on a snowmobile trail. (She slides the USB back.) Get your sister her medicine. And whatever you hid in that snowbank, I didn't see it."],
  fx:{trust:{dunn:2}}, next:"p2e6_amma"},
p2e6_amma:{ep:6, radio:true, place:"Room 7", time:"Day 10, 09:00", lines:[
  "~No Nila. Instead, Amma's voice, and Appa beside her.",
  "AMMA (ON RADIO): Kanna, Nila thoonguraa. Doctor sonnaaru, unconscious-nu. Konja naal aagalaam. || Kanna, Nila is sleeping. The doctor says she's unconscious. It may take a few days.",
  "AMMA (ON RADIO): Aana naan inga irukken. Ava notes ellam en kitta irukku. Naan padichu solren. || But I'm here. I have all her notes. I'll read them to you.",
  "~Preethi sits down slowly on the bed."],
  fx:{setHealth:10}, next:"p2e6_kane"},
p2e6_kane:{ep:6, radio:true, place:"Room 7", time:"Day 10, 11:00", lines:[
  "~The radio clicks onto your channel.",
  "KANE (ON RADIO): You took the journalist. So I took the old man.",
  "~A cough, then Sully's voice, angry: \"Don't you come, son!\" A thud.",
  "KANE (ON RADIO): Starratt-Olsen. Midnight. Not the file this time, Mani. You. Walk in alone.",
  "APPA (ON RADIO): Mani. Nila ezhudhinadhu inga irukku: \"Kane fights near water. Kane likes high ground.\" Idhu ungalukku purinjadha? || Mani. Nila wrote this here: \"Kane fights near water. Kane likes high ground.\" Does this make sense to you?",
  "PREETHI: Purinjudhu, Appa. || It does, Appa."],
  next:"p2e6_guns"},
p2e6_guns:{ep:6, place:"Hayden Deep fence line", time:"Day 10, 14:00", lines:["~First, the guns. In daylight, by the mine fence, with Northstar patrols driving the access road every ten minutes."],
  choices:[
    {t:"Wait for a patrol to pass, then dig", to:"p2e6_guns_ok"},
    {t:"Dig now, fast", to:"p2e6_guns_seen", fx:{danger:1}}
  ]},
p2e6_guns_seen:{ep:6, place:"Mine fence", time:"Day 10, 14:05", lines:["~A patrol truck slows. You lie flat in the snow with a shotgun under you. The driver squints, shrugs, and drives on. Too close."], next:"p2e6_guns_ok"},
p2e6_guns_ok:{ep:6, place:"Mine fence", time:"Day 10, 14:10", lines:["~Everything is there under the snow. Cold, dry, loaded."], next:"p2e6_town"},
p2e6_town:{ep:6, place:"Starratt-Olsen", time:"Day 10, 23:50", lines:[
  "~A near-ghost town. Empty houses with dark windows. A collapsed store. A little white church with a bell tower. Snow drifting through broken doors. A blizzard coming in off the lake.",
  "~You walk down the middle of the road alone, as you were told. Preethi isn't with you. She's already in the church bell tower with the long gun.",
  "KANE (ON RADIO): Brave. Or stupid. Your wife's in the church, isn't she? (beat) That's fine. So's my sniper.",
  "AMMA (ON RADIO): Nila ezhudhiyirukka: \"Kane likes high ground.\" || Nila wrote: \"Kane likes high ground.\""],
  next:"p2e6_sniper"},
p2e6_sniper:{ep:6, place:"Church bell tower · Preethi", time:"Day 10, 23:55", lines:["~Preethi scans the town through her scope. Snow everywhere. Then: a puff of breath fog from the highest roof in town, the old hotel."],
  combat:{id:"tower", title:"Sniper duel", solo:"preethi", startAlert:true, noStealth:true, intro:"The highest roof. The old hotel.", note:"Take cover between shots.", enemies:[{n:"Kane's sniper",hp:70,boss:true}], to:"p2e6_houses", winMsg:"The rifle on the hotel roof goes quiet."}},
p2e6_houses:{ep:6, place:"Starratt-Olsen · house to house · Mani", time:"Day 11, 00:05", lines:[
  "~Three houses between you and the one with a light in the window. In the first, a frightened local hiding with his dog. You get them out the back door into the storm.",
  "~Three of Kane's men in the next two houses, waiting."],
  combat:{id:"houses", title:"House to house", solo:"mani", intro:"Two men in the kitchen. One upstairs. They're watching the road, not the back door.", enemies:[{n:"Kitchen guard",hp:45},{n:"Kitchen guard",hp:45},{n:"Upstairs guard",hp:50}], to:"p2e6_sully"}},
p2e6_sully:{ep:6, place:"Starratt-Olsen · last house", time:"Day 11, 00:12", lines:[
  "~In the last house, Sully, tied to a kitchen chair, blood in his white hair, alive.",
  "SULLY: (as you cut him loose) Told you not to come. (beat) Thank you for coming.",
  "~Outside, engines. Kane and four men, converging on the road."],
  fx:{trust:{sully:2}}, next:"p2e6_road"},
p2e6_road:{ep:6, place:"Starratt-Olsen · the road", time:"Day 11, 00:15", lines:["~Preethi comes down from the tower at a run. The two of you, behind an old truck, against Kane."],
  combat:{id:"road", title:"Kane on the road", startAlert:true, intro:"Kane and four men. Cover behind the old truck.", enemies:[{n:"Kane",hp:110,boss:true},{n:"Hunter",hp:45},{n:"Hunter",hp:45},{n:"Hunter",hp:45},{n:"Hunter",hp:45}], to:"p2e6_after", winMsg:"Kane takes a round in the shoulder from Preethi, staggers to a snowmobile, and is gone into the storm."}},
p2e6_after:{ep:6, place:"Starratt-Olsen", time:"Day 11, 00:30", lines:["~In Kane's abandoned truck: another hard case stencilled NSB. And a radio, still on Kane's channel."], fx:{trunk:6, restock:true, heal:70}, next:"p2e6_wake"},
p2e6_wake:{ep:6, radio:true, place:"Room 7", time:"Day 11, 04:00", lines:[
  "~The radio, after a day and a half of Amma's voice, clicks. A different breath on the line.",
  "NILA (ON RADIO, BARELY AUDIBLE): …Anna… Anni… naan ellathaiyum kettukittu irundhen. || I heard everything.",
  "NILA (ON RADIO): Jonah got me a thermal image. Public satellite. North-west of the Burn there's only one heat source in four hundred square kilometres. A house. And behind it, something hot. Very hot.",
  "PREETHI: That's where the cure is.",
  "NILA (ON RADIO): That's where he is. (beat) Call Daniel."],
  fx:{clue:"thermal", setHealth:20}, next:"p2e6_flight"},
p2e6_flight:{ep:6, place:"Norseman, over the Burn", time:"Day 11, 08:00", lines:[
  "~The Norseman on skis, engine roaring. Daniel at the controls, you beside him, Preethi behind with the guns. The town shrinks below.",
  "DANIEL: Northstar got this airspace restricted. Not illegal to fly. Just unwise. (He grins.) Joe would've liked you.",
  "~The Burn: endless dark forest grown thick over old fire scars. A frozen private lake. On its far shore, a stone-and-glass mansion, steam rising from its roofs. Behind it, a black cone of rock breathing a column of white steam into the blue sky.",
  "PREETHI: Is that a volcano?",
  "DANIEL: Locals call it the Smoke. Geologists say it can't exist. (beat) It does anyway.",
  "~A sharp crack. A hole punches through the fuselage beside Preethi's head. A second crack. Oil sprays across the windshield. The engine coughs.",
  "DANIEL: Rifle! From the ridge! Hold on!",
  "~Black smoke. The engine dies. In the silence, only wind. Daniel fights the stick, gliding toward a long frozen lake in the heart of the Burn. The ice rushes up.",
  "~Impact. White."],
  fx:{trust:{daniel:2}}, next:"p2e6_end"},
p2e6_end:{ep:6, place:"The Burn", time:"Day 11", lines:["~End of Episode 6."], epEnd:true}
});
