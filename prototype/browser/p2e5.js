/* Part 2 · Episode 5 · Hayden Deep */
Object.assign(window.OTT_PARTS.p2.scenes, {
p2e5_open:{ep:5, card:true, radio:true, place:"Room 7", time:"Day 9, Thursday 18:00", lines:s => [
  "~Sully's map, Ivy's sketch and your notes spread on the bed. Nila on the radio, voice weak but precise.",
  s.flags.tylerFlipped ? "NILA (ON RADIO): Kane expects you at the front gate at midnight with the file. So you'll be there, Anna, and you won't. The convoy Tyler told us about stops for fuel at Ear Falls at nine." : "NILA (ON RADIO): Kane expects you at the front gate at midnight with the file. So you'll be there, Anna, and you won't. Ivy told me Northstar runs a supply convoy on Thursdays; it fuels at Ear Falls at nine.",
  "NILA (ON RADIO): Last truck, there's a gap between the pallets and the cab. You ride in. Anni takes the old ventilation raise near Madsen. You meet on Level 9.",
  "PREETHI: And if one of us gets caught?",
  "NILA (ON RADIO): Then the other one is the plan. (beat) Bring me pictures. Bring me voices. Bring Ivy."],
  choices:[
    {t:"Mani takes the M4, Preethi the shotgun", to:"p2e5_ear", fx:{set:{x:1}}},
    {t:"Preethi takes the M4, Mani the shotgun", to:"p2e5_ear", fx:s => { s.big = {mani:"Shotgun", preethi:"M4"}; return {toast:"Preethi takes the M4."}; }}
  ]},
p2e5_ear:{ep:5, place:"Gas station, Ear Falls", time:"21:00", lines:[
  "~Three Northstar trucks fuelling under floodlights. The drivers are inside, buying coffee. You need to reach the last truck without being seen.",
  "~Between you and it: the ice machine, a parked snowplough, and twenty metres of bright concrete."],
  choices:[
    {t:"Ice machine, then the snowplough's shadow, then the truck", to:"p2e5_ear2"},
    {t:"Walk straight across like you belong there", to:"p2e5_ear_seen", fx:{danger:1}}
  ]},
p2e5_ear_seen:{ep:5, place:"Ear Falls", time:"21:03", lines:["~A driver comes out with his coffee and looks right at you. You freeze in the shadow of the truck."],
  timer:{secs:5, to:"p2e5_ear_caught"},
  choices:[{t:"Stay absolutely still", to:"p2e5_ear2"},{t:"Run", to:"p2e5_ear_caught"}]},
p2e5_ear_caught:{ep:5, place:"Ear Falls", time:"21:04", lines:["~The driver yells. You dive into the gap behind the cab as he comes round the corner with a flashlight. He swears, decides it was a raccoon, and climbs in. Your heart is louder than the engine."], fx:{danger:1}, next:"p2e5_vent"},
p2e5_ear2:{ep:5, place:"Last Northstar truck", time:"21:05", lines:["~You fold yourself into the gap behind the cab. Diesel and cold metal. The truck pulls out. North."], next:"p2e5_vent"},
p2e5_vent:{ep:5, place:"Bush near Madsen · Preethi", time:"21:30", lines:[
  "~Deep snow. Preethi follows Sully's map by headlamp to a rusted steel cap in the trees: the 1974 ventilation raise. She cuts the padlock with Ruth's old bolt cutters.",
  "PREETHI (INTO RADIO): Lighthouse, I'm at the side door.",
  "NILA (ON RADIO): Three hundred metres of ladder, Anni. Don't look down. Actually, look down. Watch where you put your feet.",
  "~Halfway down, a rung snaps under her boot."],
  timer:{secs:4, to:"p2e5_vent_slip", fx:{hp:{preethi:-20}}},
  choices:[{t:"Grab the rail with both hands", to:"p2e5_vent2"},{t:"Reach for the next rung down", to:"p2e5_vent_slip", fx:{hp:{preethi:-20}}}]},
p2e5_vent_slip:{ep:5, place:"Ventilation raise", time:"21:50", lines:["~She drops a metre and catches a rung with one hand, slamming her knee into the rock. She hangs there, breathing. Then she climbs on."], next:"p2e5_vent2"},
p2e5_vent2:{ep:5, place:"Ventilation raise", time:"22:00", lines:["~A bat colony explodes past her face in the dark, hundreds of wings. She swears in Tamil, loudly. On the radio, Nila laughs weakly for the first time in days.","~Two hundred metres to go."], next:"p2e5_surface"},
p2e5_surface:{ep:5, place:"Hayden Deep · surface · Mani", time:"22:15", lines:[
  "~The truck rolls through the gate. Floodlights, the headframe, a modern glass office bolted onto old brick. You slip out at the loading dock.",
  "~Three guards between you and the freight elevator. A locker room. Cameras."],
  combat:{id:"surface", title:"The surface", solo:"mani", intro:"Three guards on their rounds. None of them has seen you.", note:"Stay quiet and the alarm never sounds. Go loud and Level 9 will be waiting for you.", enemies:[{n:"Dock guard",hp:45},{n:"Camera room guard",hp:45},{n:"Elevator guard",hp:50}], to:"p2e5_surface_loud", cleanTo:"p2e5_surface_clean", cleanMsg:"Three guards asleep in a locker room. You take a lab coat and an ID badge."}},
p2e5_surface_clean:{ep:5, place:"Guard post", time:"22:25", lines:["~Under the guard post bench: a hard case stencilled NSB. Grenades. And on a hook, a lab coat and an ID badge that opens the freight elevator to Level 6."], fx:{trunk:6, restock:true, flag:"quietSurface"}, next:"p2e5_meet"},
p2e5_surface_loud:{ep:5, place:"Guard post", time:"22:25", lines:["~An alarm starts somewhere and stops. They'll be looking now. Under the guard post bench: a hard case stencilled NSB. Grenades. You take the elevator badge from a guard's belt."], fx:{trunk:6, restock:true, danger:1}, next:"p2e5_meet"},
p2e5_meet:{ep:5, place:"Level 9", time:"23:00", lines:[
  "~Preethi drops from the last rung into warm air. You find the old ramp down from Level 6. You meet in a tunnel lit by white LEDs. She grabs your coat with both hands and doesn't say anything.",
  "~Then the tunnel opens."],
  next:"p2e5_farm"},
p2e5_farm:{ep:5, place:"Level 9 · the venom farm", time:"23:05", lines:[
  "~A cavern of heated glass tanks, hundreds of them, in rows that disappear into the dark. In every tank, a golden lancehead. Robotic arms move from tank to tank, pinning the snakes and milking venom into vials. Freezers hum.",
  "PREETHI: (whispering) This is a farm. He's farming them."],
  puzzle:{type:"search", title:"The venom farm", prompt:"Photograph everything.", need:3, doneLabel:"Find the lab", to:"p2e5_server", spots:[
    {t:"The tank rows", text:"You count one row: forty-two tanks. There are twelve rows. Five hundred snakes from one island the size of a few city blocks.", clue:"farm"},
    {t:"The milking arms", text:"A robotic arm pins a snake behind the head, presses its fangs over a membrane, and a gold drop runs into a vial. It moves to the next tank. And the next."},
    {t:"The whiteboard", text:"\"HX-7 batch 41 → trial. HX-7C batch 3 → HOUSE ONLY.\""},
    {t:"The lab fridge", text:"Rows of labelled vials. Preethi reads them fast and takes one small box: antivenom. \"One dose. If either of us gets bitten.\"", clue:"antivenom"}
  ]}},
p2e5_server:{ep:5, place:"Level 9 · the lab", time:"23:20", lines:[
  "~A clean lab behind glass. A server terminal. You plug in the USB with the encrypted file from Greyhaven. Hades_contacts.enc.",
  "~It isn't a list of contacts. It's a key. The terminal asks for three fields to unlock the trial database."],
  puzzle:{type:"multi", title:"Unlock the database", prompt:"Pick the three fields the key expects. They come from the batch whiteboard, Victor's ledger, and the GH-01 delivery note.", submit:"Unlock", to:"p2e5_files", options:[
    {t:"Batch number: 41", correct:true},
    {t:"Ledger code: H — 60%", correct:true},
    {t:"Delivery note: Pike Point, the week of November 1", correct:true},
    {t:"Victor's keypad code: 0314"},
    {t:"Nila's phone password"},
    {t:"Ivy's badge number: 0417"}
  ], hints:["Whiteboard, ledger, delivery note: one field from each.","41, H — 60%, and the Pike Point delivery."], giveUp:3, answerText:"41, H — 60%, and the Pike Point delivery date."}},
p2e5_files:{ep:5, place:"Level 9 · the lab", time:"23:25", lines:[
  "~The records open.",
  "~SUBJECT GH-01. Nila. \"Route: drinking water. Location: Pike Point, Greyhaven. Progression: as expected.\" A scanned note in the margin, in neat handwriting: \"Keep her alive until the brother comes. — M.H.\"",
  "~SUBJECTS RL-01 to RL-04: the four dead men. Joe Keeper is RL-03.",
  "~HX-7C (antidote): \"Three doses. Stored at the house vault. Access: M.H. only.\"",
  "MANI (INTO RADIO): Nila. He wrote your name. In his own handwriting.",
  "~A long silence on the radio.",
  "NILA (ON RADIO): Then we have him on paper. Copy everything, Anna."],
  fx:{clue:["gh01","rl","cure"]}, next:"p2e5_ivy"},
p2e5_ivy:{ep:5, place:"Level 9 · cold store", time:"23:35", lines:[
  "~Behind a steel door marked SAMPLES −4°C: Ivy, zip-tied to a shelf, lips blue, a bruise over one eye. Preethi cuts her free and wraps her in her own parka.",
  "IVY: (teeth chattering) I came back to warn you. They were in the parking lot.",
  "PREETHI: You're okay. I've got you. (She checks Ivy's pupils and fingers.) Early hypothermia. You'll keep your fingers.",
  "~Alarms. Red lights. A voice on the PA.",
  "KANE (PA): Mani. You were supposed to come to the front door."],
  fx:{trust:{ivy:2}}, next:"p2e5_esc1"},
p2e5_esc1:{ep:5, place:"Level 9 · the venom farm", time:"23:40", lines:s => ["~Guards pour into the venom farm between the tank rows. " + (s.flags.quietSurface ? "They didn't expect you this deep." : "They've been waiting.")],
  combat:s => ({id:"farm", title:"Escape: the venom farm", startAlert:!s.flags.quietSurface, intro:"Guards among the tanks. A stray shot could shatter glass.", enemies:[{n:"Guard",hp:50},{n:"Guard",hp:50},{n:"Guard",hp:50},{n:"Shift lead",hp:65}], to:"p2e5_esc2", winMsg:"A stray round shatters a tank. A golden lancehead drops onto the floor between you and the last guard, who decides he's done for the night."}),
  fx:{heal:60}},
p2e5_esc2:{ep:5, place:"Mine cage elevator", time:"23:50", lines:["~The old mine cage elevator. A slow ride up three hundred metres. Kane's men fire down the shaft from above."],
  combat:{id:"cage", title:"The cage", startAlert:true, noStealth:true, intro:"Rounds spark off the cage bars from above. Use grenades.", enemies:[{n:"Shooter on Level 6",hp:55},{n:"Shooter on Level 4",hp:55}], to:"p2e5_cliff", winMsg:"A grenade down the shaft brings the old timbers down on them. The cage grinds up into the cold."}},
p2e5_cliff:{ep:5, place:"Hayden Deep fence line", time:"Day 10, 00:30", lines:[
  "~You crash through a gap in the fence into the bush and run, Ivy between you. Then lights everywhere, red and blue. A ring of OPP cruisers on the access road. A megaphone.",
  "DUNN (MEGAPHONE): Hands where I can see them. Both of you. Now.",
  "~Preethi looks at the Desert Eagle in her hand, then at you. Behind you, on the mine road, Kane's SUVs stop, turn, and drive calmly away."],
  next:"p2e5_end"},
p2e5_end:{ep:5, place:"Red Lake", time:"Day 10", lines:["~End of Episode 5."], epEnd:true}
});
