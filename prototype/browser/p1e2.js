/* Part 1 · Episode 2 · Dead Air */
Object.assign(window.OTT_PARTS.p1.scenes, {
e2_open:{ep:2, card:true, place:"Lakeview Motel lot", time:"Tue 23:02", lines:[
  "~You stumble out of the car to the edge of the lot and shout her name across the fog. Nothing comes back. Not even an echo.",
  "~Ruth's office light snaps on. She comes out in a cardigan, the scanner in her hand.",
  "RUTH: I heard it. Both voices.",
  "MANI: Where did it come from?",
  "RUTH: Somewhere on the lake. A boat, a cabin, anywhere. (beat) That man's voice. I've heard it before, on the scanner, late. Never says a name. Just listens. And every so often, he answers.",
  "~She looks at you for a long moment.",
  "RUTH: Go upstairs. Lock the door. Don't sleep in the car again."],
  next:"e2_search"},

e2_search:{ep:2, place:"Nila's flat", time:"Tue 23:20", lines:[
  "~You can't sleep. You decide to search the flat properly, the way Nila would. Methodically. Every surface."],
  puzzle:{type:"search", title:"Search the flat", prompt:"Five places worth checking. Find at least four.", need:4, doneLabel:"Look at the laptop", to:"e2_laptop", spots:[
    {t:"Under the mattress", text:"Taped to the slats: a page torn from Nila's radio log. Columns of dates, times and frequencies. Every night since October 21: \"23:00, 7.185 MHz, PP\". The last line is underlined twice: \"If I'm not here, I'm there.\"", clue:"radiolog"},
    {t:"The window", text:"Her antenna cable hangs outside, cut clean. Four metres of coax. You coil it up and put it in your bag. It feels important to keep it.", clue:"cable", fx:{flag:"cableKept"}},
    {t:"The bathroom mirror", text:"You run the hot tap. As the mirror fogs, letters appear where a finger once traced them, backwards, meant for whoever came next: MILL.", clue:"mirror"},
    {t:"Under the bed", text:"Her radio bag is gone. Its shape in the dust, and caught in the carpet, a single scale the size of a fingernail. Gold and brown. Not from any snake you've seen in Ontario.", clue:"scale"},
    {t:"The desk", text:"Nila's laptop, locked. A sticky note on the lid in her handwriting: \"Appa's shop + the year Anna joined Auragle.\""}
  ]}},

e2_laptop:{ep:2, place:"Nila's flat", time:"Wed 00:05", lines:[
  "~The sticky note. Nila always made her passwords into little riddles, so she could tell you over the phone without saying them.",
  "~\"Appa's shop + the year Anna joined Auragle.\""],
  puzzle:{type:"code", title:"Nila's laptop", prompt:"Type the password.", placeholder:"Password", answer:["SriValli2018","Sri Valli 2018","srivalli2018"], hints:["Appa's shop is Sri Valli Leathers, in Ranipet. No spaces.","You joined Auragle as an intern in 2018."], giveUp:4, answerText:"SriValli2018.", to:"e2_laptop2", okMsg:"Unlocked."}},
e2_laptop2:{ep:2, place:"Nila's flat", time:"Wed 00:08", lines:[
  "~Her desktop is a mess of folders. Three things stand out.",
  "~An unsent email draft to a journalist in Toronto: \"I have callers, photos, and a dive planned. Not just dumping. Something alive is moving through this town.\"",
  "~An audio folder of After Hours calls. The last file, dated October 20, won't play: \"File stored at station.\"",
  "~And a spreadsheet: Callers.xlsx. Forty-six listener reports, each with a date and an address. Nila never sorted them. You open the town map beside it and start plotting."],
  fx:{clue:"email"},
  puzzle:{type:"pick", title:"Plot the callers", prompt:"Forty-six reports: sick pets, rashes, night trucks, a cough that won't go away. When you put them on the map, where do they cluster?", to:"e2_laptop3", options:[
    {t:"Evenly across town", why:"Look again. The dots aren't even. They bunch up."},
    {t:"Around the school and the church", why:"A few, but not most. The school is on the hill."},
    {t:"Along Lakeshore Road and the old mill road", correct:true},
    {t:"Near the highway", why:"The highway end of town has almost none."}
  ]}},
e2_laptop3:{ep:2, place:"Nila's flat", time:"Wed 00:30", lines:[
  "~Forty of forty-six dots sit along one line: the lakeshore, and the road up to the closed paper mill.",
  "MANI: Nobody connected them because nobody plotted them.",
  "~Somewhere a floorboard creaks. Then another. Out in the hallway."],
  fx:{clue:"callers"}, next:"e2_hall"},

e2_hall:{ep:2, place:"Nila's flat, hallway door", time:"Wed 01:15", lines:[
  "~A flashlight beam slides under the door and stops. A key scrapes in the lock.",
  "MAN: Ruth said nobody's up here."],
  timer:{secs:8, to:"e2_hall_door", fx:{danger:2, flag:["met_corbin","corbinSaw"]}},
  choices:[
    {t:"Hide in the closet", to:"e2_hall_closet"},
    {t:"Climb out the window", to:"e2_hall_window", fx:{danger:1}},
    {t:"Open the door", to:"e2_hall_door", fx:{danger:2, flag:["met_corbin","corbinSaw"]}}
  ]},
e2_hall_closet:{ep:2, place:"Nila's closet", time:"Wed 01:16", lines:[
  "~Through the slats you watch a heavy man in a sheriff's jacket step inside. He doesn't search. He looks at the window where the cable was. Then at the laptop on the desk. He lays his palm on its lid. Still warm.",
  "~A long pause. You don't breathe.",
  "SHERIFF: Stubborn family.",
  "~He leaves, locking the door behind him."],
  fx:{flag:"met_corbin"}, next:"e2_diner"},
e2_hall_window:{ep:2, place:"Behind the Lakeview", time:"Wed 01:16", lines:[
  "~You drop into the wet grass and press yourself against the wall. Above you, the door opens. A flashlight sweeps the room. A man's shape at the window, looking out at the fog.",
  "~After a long minute, he's gone. You climb back up the drainpipe, shaking."],
  fx:{flag:"met_corbin"}, next:"e2_diner"},
e2_hall_door:{ep:2, place:"Nila's flat", time:"Wed 01:16", lines:[
  "~A heavy man in a sheriff's jacket fills the doorway. He smiles like a man who has already decided what you are.",
  "CORBIN: Sheriff Dale Corbin. And you'd be the brother. Long way from Windsor.",
  "CORBIN: Your sister's an adult. Adults leave. I'd start driving early, before the fog gets thick.",
  "~He writes your licence plate in a little notebook and leaves the door open behind him."],
  next:"e2_diner"},

e2_diner:{ep:2, place:"Merrow Diner", time:"Wed 08:30", lines:[
  "~Vinyl booths, a pie case, and a bulletin board of lost-pet posters. Far too many lost-pet posters. The locals stop talking when you walk in.",
  "~Tess pours your coffee and slips you extra jam without being asked. Then the kitchen door swings open and a burly man in an apron comes out wiping his hands. He stops dead.",
  "GUS: Truck stop guy. Small world. Breakfast's on me."],
  puzzle:{type:"search", title:"The counter", prompt:"Talk to the regulars.", need:2, doneLabel:"Turn back to Gus", to:"e2_gus", spots:[
    {t:"Mrs. Abernathy, retired teacher", text:"\"My dog, Biscuit, drank from the lake in September. Dead in two days. The vet said 'toxins'. What toxins? It's a lake.\""},
    {t:"Carl, hunter", text:"\"There's a black car parks up by the old water tower some nights. Engine off. Never see anybody get out. Just sits there.\""},
    {t:"A trucker at the end", text:"\"Mill road's busier now it's closed than it ever was open. Tuesdays and Fridays, two in the morning. I don't ask.\""}
  ]}},
e2_gus:{ep:2, place:"Merrow Diner", time:"Wed 08:50", lines:[
  "~Gus refills your coffee. His hand is very steady. His eyes are not."],
  choices:[
    {t:"\"How was the fishing? With that bait?\"", sub:"Let him know you remember the cooler.", to:"e2_gus_a", fx:{danger:1}},
    {t:"\"Thanks for breakfast.\"", sub:"Say nothing.", to:"e2_gus_b", fx:{trust:{gus:1}}}
  ]},
e2_gus_a:{ep:2, place:"Merrow Diner", time:"Wed 08:52", lines:[
  "~Gus spills coffee across the counter. He mops it with a rag for far too long.",
  "GUS: Fine. It was fine.",
  "~He goes back into the kitchen and doesn't come out again."], next:"e2_station"},
e2_gus_b:{ep:2, place:"Merrow Diner", time:"Wed 08:52", lines:[
  "~Gus relaxes a little.",
  "GUS: Any time. You tell your sister Gus says hi when she turns up. She always tips."], next:"e2_station"},

e2_station:{ep:2, place:"Lake Merrow 94.1 FM", time:"Wed 10:00", lines:[
  "~A small brick station. Gold records from the eighties. A brass plaque at reception: STUDIO RENEWAL 2024 MADE POSSIBLE BY THE HAYDEN FAMILY FOUNDATION.",
  "~The station manager, Brian Holt, polo shirt, too much cologne, meets you in the lobby and tries very hard to keep you there.",
  "BRIAN: Look, I'm sorry about Nila, I am. But her show was suspended for content reasons. She was making accusations on air.",
  "MANI: Accusations against who?",
  "BRIAN: Our sponsor. Merrow Mill Holdings keeps this station alive. Without them we're a guy with a playlist."],
  fx:{set:{brian:0}}, next:"e2_brian1"},
e2_brian1:{ep:2, place:"94.1 FM lobby", time:"Wed 10:04", lines:["BRIAN: So, what is it you want?"],
  choices:[
    {t:"\"Forty-six people called her show about the same road. I plotted them.\"", to:"e2_brian2", fx:{add:{brian:1}}, req:{clues:["callers"]}, lock:"You'd need the callers' data"},
    {t:"\"I want to hear her last show. Now.\"", to:"e2_brian2"},
    {t:"\"You're protecting criminals.\"", to:"e2_brian2"}
  ]},
e2_brian2:{ep:2, place:"94.1 FM lobby", time:"Wed 10:06", lines:[
  s => s.vars.brian ? "BRIAN: Forty-six? (He swallows.) People call in about all kinds of things." : "BRIAN: I don't have to show you anything.",
  "BRIAN: Even if I wanted to help, I can't just let people into the archive."],
  choices:[
    {t:"\"Someone cut her antenna cable. Clean through. Then the sheriff let himself into her flat at one in the morning.\"", to:"e2_brian3", fx:{add:{brian:1}}, req:{clues:["cable"]}, lock:"You'd need the cable"},
    {t:"\"Please. She's my sister.\"", to:"e2_brian3"},
    {t:"\"I'll call a lawyer.\"", to:"e2_brian3"}
  ]},
e2_brian3:{ep:2, place:"94.1 FM lobby", time:"Wed 10:08", lines:[
  "~Brian looks at the front door, then at the clock, then at you.",
  "BRIAN: What do you even think is on that tape?"],
  choices:[
    {t:"\"The reason she disappeared. And if she turns up dead, I'll tell everyone you had it.\"", to:"e2_brian_end", fx:{add:{brian:1}}},
    {t:"\"Nothing. I just want to hear her voice.\"", to:"e2_brian_end"},
    {t:"\"I don't know.\"", to:"e2_brian_end"}
  ]},
e2_brian_end:{ep:2, place:"94.1 FM lobby", time:"Wed 10:10", lines:s => s.vars.brian >= 2 ? [
  "~Brian deflates like a punctured tyre.",
  "BRIAN: Ten minutes. The archive's at the back. If anyone asks, you were fixing the Wi-Fi."] : [
  "BRIAN: I think you should leave.",
  "~You leave. Out in the lot, your phone buzzes.",
  "TESS (TEXT): brian keeps the back door propped for smoke breaks. 10:20. dont tell him i told u",
  "~At 10:20 the back door is propped open with a brick. Brian is out front on the phone. You slip in."],
  next:"e2_archive"},

e2_archive:{ep:2, place:"94.1 FM tape archive", time:"Wed 10:20", lines:[
  "~A cramped room of shelves. Hundreds of boxed tapes, all with labels in the same format. A laminated note on the wall: \"ARCHIVE CODES: AH – year (2 digits) – week of year – show number.\"",
  "~On the wall calendar, someone has written week numbers down the side. The week of Mon Oct 19 to Sun Oct 25 is marked \"43\".",
  "~You check Nila's radio log page. Her last After Hours: \"Tue Oct 20 — show #112.\""],
  puzzle:{type:"code", title:"Find the tape", prompt:"What is the label on Nila's last show?", placeholder:"AH-__-__-___", answer:["AH-26-43-112","AH264312","ah 26 43 112"], hints:["Year 2026 → 26. Week 43. Show #112.","Format: AH-26-43-112"], giveUp:3, answerText:"AH-26-43-112.", to:"e2_tape"}},
e2_tape:{ep:2, radio:true, place:"94.1 FM tape archive", time:"Wed 10:26", lines:[
  "~You load the tape. Nila's voice, warm and quick. Then a caller: an old man, whispering.",
  "CALLER (ON TAPE): I won't give my name. My son fishes. In seventy-seven I loaded barrels for the mill, down where the village was, before they flooded it. I was nineteen.",
  "CALLER (ON TAPE): And they're doing it again, miss. Every week. New barrels, new trucks. And the other thing. The animals.",
  "NILA (ON TAPE): Animals?",
  "CALLER (ON TAPE): In crates. Some of them alive. I hear them at night from the dock. Hissing.",
  "NILA (ON TAPE): Listeners, I'm going to the mill myself, and I'll tell you everything I find. Right here, right—",
  "~A station jingle cuts across her. Brian is in the doorway, rubbing his face.",
  "BRIAN: I cut the feed. Five minutes later I got a phone call. Not from the mill. From a consultant who'd just signed a two-year sponsorship. Paid in advance.",
  "BRIAN: Kessler. Victor Kessler.",
  "~You take Victor's business card from your wallet and look at it for a long time."],
  fx:{clue:["tape","sponsor"]}, next:"e2_lot"},

e2_lot:{ep:2, place:"94.1 FM parking lot", time:"Wed 11:00", lines:[
  "~A sheriff's cruiser is parked across the back of your car. Corbin leans on it, eating a donut from a Tom Portons bag.",
  s => s.flags.corbinSaw ? "CORBIN: We meet again." : "CORBIN: Sheriff Dale Corbin. You'd be the brother.",
  "CORBIN: Filing a missing persons report? Good. Come by the station Friday and we'll do it properly.",
  "CORBIN: Today, I'd stay out of folks' business. Folks here are private."],
  fx:{flag:"met_corbin"},
  choices:[
    {t:"\"Do you know a Victor Kessler?\"", to:"e2_lot_v", fx:{danger:1}},
    {t:"\"I heard Nila's last show.\"", to:"e2_lot_t", fx:{danger:1}},
    {t:"\"Of course, Sheriff. Thank you.\"", sub:"Stay polite.", to:"e2_lot_p", fx:{trust:{corbin:1}}}
  ]},
e2_lot_v:{ep:2, place:"94.1 FM parking lot", time:"Wed 11:02", lines:[
  "~Corbin's jaw tightens. Just for a second.",
  "CORBIN: Never heard of him. (He folds the donut bag very neatly.) Drive safe."], next:"e2_phone"},
e2_lot_t:{ep:2, place:"94.1 FM parking lot", time:"Wed 11:02", lines:[
  "~Corbin goes very quiet. He looks at the station's back door. Then at you.",
  "CORBIN: Brian should be more careful with his archive. (He gets into the cruiser.) Drive safe."], next:"e2_phone"},
e2_lot_p:{ep:2, place:"94.1 FM parking lot", time:"Wed 11:02", lines:[
  "~Corbin smiles, satisfied.",
  "CORBIN: Good man. (He moves the cruiser.) Friday."], next:"e2_phone"},

e2_phone:{ep:2, place:"Nila's flat", time:"Wed 15:30", lines:[
  "~Back at the flat. Nila's phone is charged. The lock screen asks for a password. Same riddle-maker, same family.",
  "~You try the laptop password. Wrong. You think about what Nila would use for herself."],
  puzzle:{type:"code", title:"Nila's phone", prompt:"Appa's shop, and something that belongs to Nila.", placeholder:"Password", answer:["SriValli2001","Sri Valli 2001"], hints:["Same shop. A different year: hers.","Nila is 25. She was born in 2001."], giveUp:4, answerText:"SriValli2001.", to:"e2_memo"}},
e2_memo:{ep:2, place:"Nila's flat", time:"Wed 15:34", lines:[
  "~The last voice memo, recorded Sunday 23:40. Wind. Water. Nila whispering in the dark.",
  "NILA (VOICE MEMO): Anna, idha nee kettuttu irundha, naan unkitta nerla solla mudiyala. Eli-ku theriyum. Dock pathi Eli kitta kelu, avan mela kovapadaadha. Tess-ku bayandhu dhaan avan ipdi pannaan. || Anna, if you're hearing this, I couldn't tell you in person. Eli knows. Ask Eli about the dock, and don't be angry with him. He did it because he's scared for Tess.",
  "NILA (VOICE MEMO): Andha coat potta aal thirumba vandhuttaan. Naan broadcast panra ovvoru raathiriyum avan inga irukkaan. Pakkathula varradhilla. Kettuttu mattum irukkaan. || The man in the coat is back. Every night I broadcast, he's here. He never comes closer. He just listens.",
  "~A knock at the door.",
  "~You open it. A broad young man in muddy fisherman's boots, size eleven, eyes red from no sleep.",
  "ELI: You're her brother. (He looks over his shoulder at the street.) I'm Eli. We need to talk. Not here. Come to the dock."],
  fx:{clue:"memo", flag:"met_eli"}, next:"e2_end"},
e2_end:{ep:2, place:"Greyhaven", time:"Wed 15:40", lines:["~End of Episode 2."], epEnd:true}
});
