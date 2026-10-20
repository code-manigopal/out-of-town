/* Part 2 · Episode 3 · Gold Country */
Object.assign(window.OTT_PARTS.p2.scenes, {
p2e3_open:{ep:3, card:true, radio:true, place:"Room 7, Northern Star Motel", time:"Day 6, 06:00", lines:[
  "~You haven't slept. The radio on the bed. Ortiz's voice on it, from the highway.",
  "ORTIZ (ON RADIO): Took three days off. I'll sit outside her door in Windsor till you come home. Nobody brings her flowers but family. (beat) That's not a favour, Mani. I owe her.",
  "NILA (ON RADIO): Sam's here. He brought Tom Portons. Okay. Plan for today, Anna. Hospital, museum, rocks."],
  next:"p2e3_hosp"},
p2e3_hosp:{ep:3, place:"Red Lake Margaret Cochenour Memorial Hospital", time:"Day 6, 09:00", lines:[
  "~A small, clean hospital, snow piled at the doors. Preethi introduces herself at the desk as a visiting hospital pharmacist from Windsor, which is true, and asks for the director. She gets Dr. Helen Marchetti, fifty-two, sharp, tired, stethoscope worn like a necklace.",
  "DR. MARCHETTI: Windsor? You drove all this way to ask about my formulary?",
  "PREETHI: I drove all this way because my sister-in-law has a cancer nobody understands. (She hands over Nila's panel.) This compound. Have you seen it?",
  "~Marchetti reads it. Closes her office door.",
  "DR. MARCHETTI: Four times. Four men who did contract work at the Hayden Deep. All dead within five months. I sent samples to Winnipeg. The results came back \"lost\". Then Northstar donated a CT scanner to this hospital. (beat) I was told to stop asking."],
  fx:{flag:"met_marchetti", trust:{marchetti:1}},
  puzzle:{type:"multi", title:"Five blood panels", prompt:"Preethi lays Nila's panel beside the four dead men's. Which findings do all five share? Choose all that apply.", submit:"Show Dr. Marchetti", to:"p2e3_hosp2", options:[
    {t:"The same unnamed peptide", correct:true},
    {t:"Rising liver enzymes over three weeks", correct:true},
    {t:"Low iron"},
    {t:"The same blood type"},
    {t:"Normal white cell count"}
  ], hints:["Two things only: one compound, one pattern.","The peptide, and the liver enzymes."], giveUp:3, answerText:"The peptide and the three-week rise in liver enzymes."}},
p2e3_hosp2:{ep:3, place:"Dr. Marchetti's office", time:"Day 6, 09:30", lines:[
  "PREETHI: Same compound. Same pattern. Different start dates. (beat) Nila's three weeks behind the last man.",
  "DR. MARCHETTI: (quietly) Then you have about three months. Maybe less.",
  "~Preethi doesn't move. You take her hand under the desk."],
  fx:{clue:"panels5", trust:{marchetti:1}}, next:"p2e3_museum"},
p2e3_museum:{ep:3, place:"Red Lake Regional Heritage Centre", time:"Day 6, 11:00", lines:[
  "~Gold pans, Norseman models, mine photographs. A volunteer docent, Mrs. Lindqvist, seventies, is delighted to have a visitor."],
  puzzle:{type:"search", title:"The Hayden family", prompt:"Find what you can about the Haydens.", need:4, doneLabel:"Talk to Mrs. Lindqvist", to:"p2e3_museum2", spots:[
    {t:"A 1934 photo", text:"Two prospectors grinning over a claim post. \"Hayden brothers, Hayden Deep claim.\""},
    {t:"A mine plaque", text:"\"Hayden Deep Mine, 1946–1991. At its peak, 300 men.\""},
    {t:"A 1974 newspaper clipping", text:"\"Engineer R. Hayden leaves for southern Ontario dam project.\" The dam at Old Merrow. You know that name from a photo in a church basement in Greyhaven."},
    {t:"The donor wall", text:"\"Northstar Biologics — Mark Hayden, 2015.\"", clue:"hayden"}
  ]}},
p2e3_museum2:{ep:3, place:"Heritage Centre", time:"Day 6, 11:30", lines:[
  "MRS. LINDQVIST: Mark came home in 2015. Bought the old mine, built a big house way out past the Burn. Nobody's ever been invited.",
  "MRS. LINDQVIST: His father too, they say. Though old Robert must be ninety if he's a day.",
  "~You write down \"Robert\"."],
  fx:{clue:"robert"}, next:"p2e3_overlook"},
p2e3_overlook:{ep:3, place:"Dickenson Mine viewing lot, Balmertown", time:"Day 6, 13:00", lines:[
  "~A lot overlooking the mine buildings and headframe. A.Y. Jackson painted this view once. You and Preethi eat the last of Amma's puliyodharai in the car, heater running.",
  "PREETHI: Three months.",
  "MANI: Less.",
  "PREETHI: What if the cure doesn't exist?",
  "MANI: Then Hades wouldn't send presents. You don't brag about a lock unless you have the key."],
  next:"p2e3_rocks"},
p2e3_rocks:{ep:3, place:"Balmertown Municipal Office · mineral collection", time:"Day 6, 14:00", lines:[
  "~Cases of minerals: thousands of specimens, quartz, pyrite, real gold glinting under the lights. Somewhere in here are rocks from the Hayden Deep."],
  puzzle:{type:"search", title:"The mineral collection", prompt:"Find the Hayden Deep specimens.", need:3, doneLabel:"Look closer at the gold", to:"p2e3_rocks2", spots:[
    {t:"Case 4: \"Red Lake Mine\"", text:"Quartz veins, gold flecks. Not Hayden Deep."},
    {t:"Case 9: \"Hayden Deep, Level 2\"", text:"Grey rock with pyrite. 1951."},
    {t:"Case 9: \"Hayden Deep, Level 4\"", text:"A fist of quartz. 1958."},
    {t:"Case 9: \"Hayden Deep, Level 6, 1962\"", text:"A beautiful gold specimen. The label is slightly crooked. Underneath, the edge of an older tag."}
  ]}},
p2e3_rocks2:{ep:3, place:"Mineral collection", time:"Day 6, 14:20", lines:["~You borrow the case magnifier. Under the Level 6 label, an older typed tag, mostly hidden."],
  puzzle:{type:"code", title:"The hidden tag", prompt:"You can make out: \"HAYDEN DEEP — LEV_L _ — 1962\". The missing letter is obvious. The number is the last digit, partly scratched: it looks like a 6 with a tail, or a 9. The public maps show levels 1 to 6. What does the hidden tag say?", placeholder:"Level ?", answer:["9","level 9","level9","nine"], hints:["If it were 6, why hide it under a label that says 6?","Level 9."], giveUp:3, answerText:"Level 9.", to:"p2e3_rocks3"}},
p2e3_rocks3:{ep:3, place:"Mineral collection", time:"Day 6, 14:25", lines:[
  "MANI: The public mine maps show six levels.",
  "NILA (ON RADIO): So there are three more nobody talks about. That's where the lab is, Anna."],
  fx:{clue:"level9"}, next:"p2e3_dunn"},
p2e3_dunn:{ep:3, place:"OPP detachment, Red Lake", time:"Day 6, 15:30", lines:[
  "~A call to your phone brings you in. Constable Rachel Dunn, thirty-three, ponytail, notebook, very direct.",
  "DUNN: Two people from Windsor, long gun cases, asking about Northstar at the hospital and the museum. You know what that sounds like to me?"],
  fx:{flag:"met_dunn", set:{dunnScore:0}},
  choices:[
    {t:"\"Grace Okafor said you were honest.\"", to:"p2e3_dunn2", fx:{add:{dunnScore:1}}},
    {t:"\"We're tourists.\"", to:"p2e3_dunn2"},
    {t:"\"Some men shot at us near Ignace.\"", to:"p2e3_dunn2", fx:{danger:1, add:{dunnScore:-1}}}
  ]},
p2e3_dunn2:{ep:3, place:"OPP detachment", time:"Day 6, 15:35", lines:["DUNN: (writing) Why Northstar?"],
  choices:[
    {t:"Tell her about Nila's cancer and show the five blood panels", to:"p2e3_dunn3", fx:{add:{dunnScore:1}}, req:{clues:["panels5"]}, lock:"You'd need the blood panels"},
    {t:"\"We're thinking of investing.\"", to:"p2e3_dunn3"},
    {t:"Show her the gun cases are locked", to:"p2e3_dunn3", fx:{danger:1}}
  ]},
p2e3_dunn3:{ep:3, place:"OPP detachment", time:"Day 6, 15:40", lines:s => s.vars.dunnScore >= 2 ? [
  "DUNN: Grace taught me at Lakehead. (She closes her notebook.) I can't help you. I also can't arrest you for being sad.",
  "DUNN: Go home, Mr. Mani. Northstar pays half this town's wages. (beat) And if you don't go home, don't make me find you in a ditch."] : [
  "DUNN: I'll be watching you two. Closely. Don't give me a reason."],
  fx:s => s.vars.dunnScore >= 2 ? {trust:{dunn:2}} : {trust:{dunn:0}, danger:1}, next:"p2e3_daniel"},
p2e3_daniel:{ep:3, place:"Floatplane base, Red Lake", time:"Day 6, 16:30", lines:[
  "~Planes on skis on the frozen bay. A man in a heavy parka works on the engine of an old Norseman. Daniel Keeper, forty-five.",
  "DANIEL: You're the couple asking about Hayden Deep. (beat) My cousin Joe worked there. He was the third one who died.",
  "DANIEL: There's a stretch of land past the Burn nobody's allowed to fly over. Northstar got a restriction put on it. I know every lake around it.",
  "MANI: Would you fly us?",
  "DANIEL: When it's time. Not before. (He looks at the gun cases in your back seat.) And not with those pointed at my plane."],
  fx:{flag:"met_daniel", trust:{daniel:1}}, next:"p2e3_cliff"},
p2e3_cliff:{ep:3, radio:true, place:"Room 7", time:"Day 6, 22:00", lines:[
  "~The nightly check-in. Nila reads the five blood panels back to you, voice thin.",
  "NILA (ON RADIO): …so if the peptide binds in the liver first, then the three-week lag means he dosed me in the—",
  "~Her voice stops. A long electronic tone. Then voices in the room, running feet, the clatter of a falling tray. Then Amma.",
  "AMMA (ON RADIO): Kanna! Nurses vandhurukkaanga, ava moochu— || Kanna! The nurses are here, her breathing—",
  "~Static."],
  fx:{setHealth:35}, next:"p2e3_end"},
p2e3_end:{ep:3, place:"Red Lake", time:"Day 6", lines:["~End of Episode 3."], epEnd:true}
});
