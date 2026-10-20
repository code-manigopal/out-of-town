/* Part 1 · Episode 4 · The Mill */
Object.assign(window.OTT_PARTS.p1.scenes, {
e4_open:{ep:4, card:true, place:"Marsh family dock", time:"Thu 07:00", lines:[
  "~Dawn. Margaret is a blackened hull. Walter sits on an upturned crate, coughing into his fist. Sheriff Corbin walks the dock, hands in his pockets.",
  "CORBIN: Electrical fault. Old boat, old wiring. Happens.",
  "ELI: Somebody pinned a photo of my sister to that post.",
  "CORBIN: Kids. (He looks at you.) Trouble does seem to follow strangers around, doesn't it."],
  choices:[
    {t:"Show Corbin the knife and photo", to:"e4_open_a", fx:{danger:1, flag:"photoTaken"}},
    {t:"Keep them hidden in your jacket", to:"e4_open_b"}
  ]},
e4_open_a:{ep:4, place:"Marsh family dock", time:"Thu 07:04", lines:[
  "~Corbin takes the knife and photo in a plastic bag.",
  "CORBIN: Evidence. I'll look into it.",
  "~You will never see either of them again."], next:"e4_interview"},
e4_open_b:{ep:4, place:"Marsh family dock", time:"Thu 07:04", lines:[
  "~You say nothing. The knife is a cold weight against your ribs. Corbin watches you a beat too long, then walks away whistling."], next:"e4_interview"},

e4_interview:{ep:4, place:"Lakeview Motel office", time:"Thu 10:50", lines:[
  "~Your phone alarm: \"Interview — Data Analytics Engineer, Round 2, 11:00.\" You'd forgotten. Completely.",
  "~Ruth lets you use the office. Behind your laptop camera: her scanner, the shotgun, a stuffed pike on the wall. You turn the laptop so the pike is out of frame.",
  "DEBORAH: Thanks for joining, Mani. Let's start. Tell us about a time you found a pattern nobody else noticed."],
  fx:{set:{interview:0}},
  choices:[
    {t:"\"Forty-six reports. Different people, different complaints. Nobody connected them because nobody plotted them. On a map they all sit on one road.\"", to:"e4_int2", fx:{add:{interview:1}}, req:{clues:["callers"]}, lock:"You haven't plotted the callers"},
    {t:"\"At Auragle I optimised a billing pipeline and cut processing time by forty percent.\"", to:"e4_int2", fx:{add:{interview:1}}},
    {t:"\"Honestly, I'm having a strange week. Can we reschedule?\"", to:"e4_int2"}
  ]},
e4_int2:{ep:4, place:"Lakeview Motel office", time:"Thu 11:08", lines:["DEBORAH: How do you handle working with incomplete or messy data?"],
  choices:[
    {t:"\"I start with what I can verify, label everything I'm assuming, and test the assumptions first.\"", to:"e4_int3", fx:{add:{interview:1}}},
    {t:"\"I clean it until it's perfect, then I start.\"", to:"e4_int3"},
    {t:"\"I trust my gut.\"", to:"e4_int3"}
  ]},
e4_int3:{ep:4, place:"Lakeview Motel office", time:"Thu 11:15", lines:["~Ruth's scanner crackles behind you. Deborah's eyebrows go up.","DEBORAH: Last one. Why do you want this job?"],
  choices:[
    {t:"\"Because data is just people, written down. I like finding them in it.\"", to:"e4_int_end", fx:{add:{interview:1}}},
    {t:"\"The salary.\"", to:"e4_int_end"},
    {t:"\"I've been out of work for a while and I'm good at this.\"", to:"e4_int_end", fx:{add:{interview:1}}}
  ]},
e4_int_end:{ep:4, place:"Lakeview Motel office", time:"Thu 11:22", lines:s => [
  s.vars.interview >= 2 ? "~Deborah smiles for the first time. \"That's a great answer. We'll be in touch very soon.\"" : "~Deborah nods politely. \"Thank you, Mani. We'll be in touch.\"",
  "~You close the laptop. Ruth is watching you from the doorway.",
  "RUTH: You're going to that mill, aren't you."],
  fx:s => s.vars.interview >= 2 ? {flag:"interviewGood"} : null, next:"e4_ruth"},

e4_ruth:{ep:4, place:"Lakeview Motel office", time:"Thu 13:00", lines:s => s.trust.ruth >= 2 ? [
  "~Ruth closes the blinds and lifts a floorboard behind the desk. Under it, fourteen spiral notebooks.",
  "RUTH: Harold died in 2011. Lungs. The doctor said \"rare\". I didn't believe in rare. So I started writing down every truck that went up the mill road. Date, time, plate. Fourteen years. Nobody ever asked to see these."] : [
  "~Ruth hesitates. Then she takes one spiral notebook out of a drawer and drops it on the desk.",
  "RUTH: This year's. Trucks up the mill road. Date, time, plate. Don't ask me why I keep it."],
  fx:{clue:"notebooks"}, next:"e4_ruth_p1"},
e4_ruth_p1:{ep:4, place:"Lakeview Motel office", time:"Thu 13:20", lines:[
  "~You spread the notebook pages across the desk and do what you do best. Sort by day. Sort by hour. Count."],
  puzzle:{type:"pick", title:"The truck log", prompt:"When do the trucks run?", to:"e4_ruth_p2", options:[
    {t:"Every night, at random times", why:"Count again. Some nights are empty."},
    {t:"Tuesdays and Fridays, between 01:30 and 03:00", correct:true},
    {t:"Weekends, in the afternoon", why:"Almost nothing in daylight."},
    {t:"Mondays only", why:"Mondays are nearly blank."}
  ]}},
e4_ruth_p2:{ep:4, place:"Lakeview Motel office", time:"Thu 13:40", lines:[
  "~The same nights as the boats. In the margins, Ruth has scribbled scanner notes. You read them down the page.",
  "~\"Mill security, 23:40: 'Shift change, cams going to reset.' 23:52: 'Cams back up.'\" Every night, the same.",
  "~Twelve minutes, every night, when the yard cameras are blind."],
  puzzle:{type:"code", title:"The gap", prompt:"What time do the cameras go down? (24-hour clock)", placeholder:"HH:MM", answer:["23:40","2340"], hints:["It's in the scanner note: the shift change.","23:40"], giveUp:3, answerText:"23:40.", to:"e4_ruth_end"}},
e4_ruth_end:{ep:4, place:"Lakeview Motel office", time:"Thu 13:45", lines:[
  "MANI: Tonight. 23:40. North fence.",
  "RUTH: You're going in there. (It isn't a question.) Then take these.",
  "~A heavy flashlight and a pair of bolt cutters.",
  "RUTH: Not the shotgun. You'd shoot your own foot."], next:"e4_fence"},

e4_fence:{ep:4, place:"Mill road, north fence", time:"Thu 23:38", lines:[
  "~Merrow Paper Mill. Brick sheds, a smokestack, broken windows. But warm light leaks from the pulping hall, and steam rises from the boiler house. A sign: CLOSED 2009. PRIVATE PROPERTY.",
  "~23:40. The camera on the fence post stops blinking. Twelve minutes.",
  "~You cut the fence. Ahead, the yard: a gravel path straight to the pulping hall, or the long way round through the dead grass."],
  choices:[
    {t:"Through the grass, the long way", to:"e4_fence2"},
    {t:"Straight across the gravel", to:"e4_fence2", fx:{danger:1, toast:"Gravel crunches. A guard looks your way."}}
  ]},
e4_fence2:{ep:4, place:"Mill yard", time:"Thu 23:43", lines:[
  "~A guard's flashlight swings along the wall toward you. Behind you, a stack of pallets. To your left, an open shed door."],
  timer:{secs:6, to:"e4_hall", fx:{danger:1}},
  choices:[
    {t:"Duck behind the pallets", to:"e4_hall"},
    {t:"Slip into the shed", to:"e4_hall", fx:{toast:"Dark, dusty, safe."}}
  ]},
e4_hall:{ep:4, place:"Pulping hall", time:"Thu 23:45", lines:[
  "~The paper machines are gone. In their place: plastic sheeting, ventilation fans, a long steel table. Three workers in respirators feed powder into two pill presses that thump out small blue tablets stamped M30.",
  "~Counterfeit oxycodone. Which means fentanyl.",
  "~Blue barrels of chemical sludge stand by the loading door, waiting."],
  puzzle:{type:"search", title:"The lab", prompt:"Photograph everything. Quietly.", need:3, doneLabel:"Move on", to:"e4_pills", spots:[
    {t:"The pill presses", text:"Two industrial presses. Thump. Thump. Thump. A tray of blue tablets fills every few seconds."},
    {t:"The barrels", text:"Blue plastic barrels with hazard labels peeled off. One is cracked; something milky has dried down its side. The smell makes your eyes water."},
    {t:"The whiteboard", text:"Batch numbers, dates, and counts in the thousands. At the bottom: \"BOAT — TUE/FRI\".", clue:"lab"},
    {t:"The workers", text:"Respirators, gloves, hairnets. One of them is barely older than Tess."}
  ]}},
e4_pills:{ep:4, place:"Pulping hall", time:"Thu 23:47", lines:["~A sealed bag of pills sits on the end of the table, a metre from the nearest worker's back. Physical evidence. If you can reach it."],
  choices:[
    {t:"Crouch-walk out and grab the bag", to:"e4_pills_try"},
    {t:"Leave it. The photos are enough.", to:"e4_boiler"}
  ]},
e4_pills_try:{ep:4, place:"Pulping hall", time:"Thu 23:48", lines:["~You crouch. The worker shifts his weight. The press thumps."],
  timer:{secs:4, to:"e4_pills_seen", fx:{danger:2}},
  choices:[{t:"Grab it NOW, between thumps", to:"e4_pills_ok", fx:{clue:"pills"}},{t:"Wait for him to turn away", to:"e4_pills_seen", fx:{danger:2}}]},
e4_pills_ok:{ep:4, place:"Pulping hall", time:"Thu 23:48", lines:["~Your hand closes on the bag between one thump and the next. You're back in the shadows before the press lands again."], next:"e4_boiler"},
e4_pills_seen:{ep:4, place:"Pulping hall", time:"Thu 23:48", lines:["~The worker turns. Your eyes meet over his respirator. He opens his mouth. You run, and he hesitates just long enough. You don't get the bag."], next:"e4_boiler"},

e4_boiler:{ep:4, place:"Boiler house", time:"Thu 23:49", lines:[
  "~Heat hits like a wall. Humid, green, almost beautiful. Rows of glass tanks under heat lamps.",
  "~Tiny poison dart frogs, bright blue and yellow. Radiated tortoises from Madagascar stacked in crates. Slow lorises in small cages, blinking. And at the far end, a locked glass vault with a brass plate: B. INSULARIS — ILHA DA QUEIMADA GRANDE — 6.",
  "~Only five snakes inside. The one from Eli's bucket came from here. Someone took it back.",
  "~You step back and your shoulder catches a heat-lamp cable. The lights flicker, buzz, and die. In the dark, somewhere close, a tank latch clicks."],
  fx:{set:{bites:0}}, next:"e4_snake1"},
e4_snake1:{ep:4, place:"Boiler house, dark", time:"Thu 23:50", lines:["~Your flashlight finds it: gold coils on the floor, a metre in front of your boots, head lifting."],
  timer:{secs:5, to:"e4_snake2", fx:{add:{bites:1}}},
  choices:[{t:"Freeze", to:"e4_snake2"},{t:"Step back", to:"e4_snake2", fx:{add:{bites:1}}}]},
e4_snake2:{ep:4, place:"Boiler house, dark", time:"Thu 23:50", lines:["~It slides past your boot. It's behind you now, between you and the door. A pipe runs along the floor to your right."],
  timer:{secs:5, to:"e4_snake3", fx:{add:{bites:1}}},
  choices:[{t:"Step over the pipe, away from it", to:"e4_snake3"},{t:"Turn and shine the light on it", to:"e4_snake3", fx:{add:{bites:1}}}]},
e4_snake3:{ep:4, place:"Boiler house, dark", time:"Thu 23:51", lines:["~It rises. Its head sways at knee height, tasting the heat of you."],
  timer:{secs:5, to:"e4_snake_end", fx:{add:{bites:1}}},
  choices:[{t:"Back away slowly", to:"e4_snake_end"},{t:"Run for the door", to:"e4_snake_end", fx:{add:{bites:1}}}]},
e4_snake_end:{ep:4, place:"Boiler house", time:"Thu 23:52", lines:s => s.vars.bites > 0 ? [
  "~Something hits your calf like a hammer. Then fire. You stumble out of the boiler house, gasping, your leg burning through your jeans.",
  "~You don't know yet that it was a dry bite. Almost no venom. You only know it hurts, and you're limping."] : [
  "~You back out of the boiler house one slow step at a time. The snake loses interest and coils under a tank.",
  "~Behind you, a worker swears in the dark: \"Which idiot left the lamp off?\""],
  fx:s => s.vars.bites > 0 ? {flag:"bitten", danger:1} : null, next:"e4_keypad"},

e4_keypad:{ep:4, place:"Outside the manager's office", time:"Thu 23:53", lines:[
  "~The old mill manager's office, upstairs. A keypad on the door. Beside it, a framed Diwali card, of all things, signed \"V.K. — every lock should remember the day it all began.\"",
  "~Next to it, a framed newspaper clipping: \"KESSLER RESTRUCTURING TAKES OVER MERROW MILL HOLDINGS — signed March 14, 2019.\"",
  "~Four digits."],
  puzzle:{type:"code", title:"The keypad", prompt:"The day it all began. Four digits.", placeholder:"####", answer:["0314","314"], hints:["Month and day, two digits each.","March 14 → 0314."], giveUp:3, answerText:"0314.", to:"e4_office"}},
e4_office:{ep:4, place:"Manager's office", time:"Thu 23:54", lines:[
  "~Leather chairs, whisky, a hotel-suite carpet. On the desk, a large glass terrarium with one golden lancehead, bigger than the rest. A brass tag: MIDAS.",
  "~Victor's laptop is open. A spreadsheet."],
  puzzle:{type:"search", title:"Victor's laptop", prompt:"Ninety seconds before it locks. Copy everything to your USB stick.", need:2, doneLabel:"Pull the USB", to:"e4_overhear", spots:[
    {t:"The ledger", text:"D.C. — \"law\": $4,000/month. G.P. — runs: $1,200 per run. B.H. — sponsorship: $30,000 per year. Venom, 6 × B.I.: $210,000. And at the bottom: H. — 60%. D.C. is Dale Corbin. G.P., Gus Pell. B.H., Brian Holt. H…?", clue:"ledger"},
    {t:"A folder called \"H\"", text:"One file: Hades_contacts.enc. Encrypted. You copy it anyway.", clue:"hadesFile"},
    {t:"The email inbox", text:"An email from a blocked sender: \"Clean before Friday. Don't make me come down there. — H\""}
  ]}},
e4_overhear:{ep:4, place:"Manager's office", time:"Thu 23:58", lines:[
  "~Footsteps on the stairs. You duck behind the terrarium. Victor comes in with Corbin, mid-conversation.",
  "VICTOR: …and I don't care what he looks like, Dale. He's a nice boy from Windsor with a box of sweets. Nice boys go home if you ask them correctly.",
  "CORBIN: And the sister?",
  "VICTOR: Hades wants her found before she broadcasts again. She knows his voice. Nobody knows his voice.",
  "~He taps the terrarium. Midas rises.",
  "VICTOR: Find her, Dale. Or I find a use for you.",
  "~Corbin leaves. Victor pours a whisky and talks to the snake.",
  "VICTOR: Festival of lights, Midas. Good triumphs over evil. (He laughs.) Every year, they still believe it."],
  next:"e4_chase"},

e4_chase:{ep:4, place:"Mill yard", time:"Fri 00:00", lines:[
  "~An alarm whoops. The camera reset is over. A guard with a shotgun sees you at the office window.",
  "GUARD: HEY!",
  "~The window beside your head explodes. You run."],
  fx:{set:{chase:0}}, next:"e4_ch1"},
e4_ch1:{ep:4, place:"Mill yard", time:"Fri 00:00", lines:["~Down from the office: a catwalk across the hall, or the stairs to the yard."],
  timer:{secs:4, to:"e4_ch2", fx:{add:{chase:1}}},
  choices:[{t:"Catwalk", to:"e4_ch2"},{t:"Stairs", to:"e4_ch2", fx:{add:{chase:1}}}]},
e4_ch2:{ep:4, place:"Mill yard", time:"Fri 00:01", lines:["~Two men ahead. Cover: a row of barrels, or a parked truck."],
  timer:{secs:4, to:"e4_ch3", fx:{add:{chase:1}}},
  choices:[{t:"The barrels", to:"e4_ch3", fx:{add:{chase:1}}},{t:"The truck", to:"e4_ch3"}]},
e4_ch3:{ep:4, place:"Mill yard", time:"Fri 00:01", lines:["~A conveyor belt blocks the way. Over it or under it?"],
  timer:{secs:4, to:"e4_ch4", fx:{add:{chase:1}}},
  choices:[{t:"Under", to:"e4_ch4"},{t:"Over", to:"e4_ch4", fx:{add:{chase:1}}}]},
e4_ch4:{ep:4, place:"Mill yard", time:"Fri 00:02", lines:["~The fence, ten metres. Or the outflow ditch beside it."],
  timer:{secs:4, to:"e4_ch_end", fx:{add:{chase:1}}},
  choices:[{t:"The gap in the fence you cut", to:"e4_ch_end"},{t:"The outflow ditch", to:"e4_ch_end", fx:{add:{chase:1}}}]},
e4_ch_end:{ep:4, place:"Mill road", time:"Fri 00:03", lines:s => s.vars.chase >= 2 ? [
  "~A hand grabs your jacket at the fence. You twist free and the jacket tears. A shotgun blast shreds the branches above you as you crash into the trees."] : [
  "~You're through the fence and into the trees before the first guard reaches the yard. Flashlights sweep the woods behind you, too late."],
  fx:s => s.vars.chase >= 2 ? {danger:2} : null, next:"e4_ditch"},
e4_ditch:{ep:4, place:"Ditch by the mill road", time:"Fri 00:20", lines:[
  "~You lie in a ditch of freezing water, heart hammering, the USB stick clenched in your fist. A refrigerated truck rumbles past: MERROW PALLETS & SUPPLY. The cab light flicks on.",
  "~The driver is Gus Pell, still in his diner apron, humming.",
  "~Your phone buzzes. Unknown number. You answer and say nothing.",
  "VICTOR (ON PHONE): You left your coffee cup at my truck stop, Mani. And your footprints all over my boiler house.",
  "VICTOR (ON PHONE): You've got her eyes. Did anyone tell you that? Same stubborn eyes.",
  "VICTOR (ON PHONE): Here's my last offer. Go home. Light your lamps. Call your mother. Or I start taking the people you've met here. One at a time. Until you do.",
  "~The line goes dead. On the hill, the red light on the water tower blinks twice."],
  next:"e4_end"},
e4_end:{ep:4, place:"Greyhaven", time:"Fri 00:25", lines:["~End of Episode 4."], epEnd:true}
});
