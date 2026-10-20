/* Part 1 · Episode 5 · The Badge */
Object.assign(window.OTT_PARTS.p1.scenes, {
e5_open:{ep:5, card:true, place:"Nila's flat", time:"Fri 07:30", lines:s => s.flags.bitten ? [
  "~You wake on the couch, sweating. Your calf is swollen and purple around two neat puncture marks.",
  "~Tess, getting ready for her shift, sees it and drops her mug.",
  "TESS: That's a bite. Mani, that's a BITE. We're going to Dr. Rao. Now."] : [
  "~You wake on the couch. Your palms are torn from the fence wire and one cut on your hand won't stop bleeding through the tissue.",
  "~Tess, getting ready for her shift, sees the blood on the cushion and drops her mug.",
  "TESS: That needs stitches. We're going to Dr. Rao. Now."],
  choices:[
    {t:"Tell Tess the truth about the mill", to:"e5_clinic", fx:{trust:{tess:1}, flag:"tessKnows"}},
    {t:"\"I slipped on the dock.\"", to:"e5_clinic"}
  ]},
e5_clinic:{ep:5, place:"Greyhaven Medical Clinic", time:"Fri 08:15", lines:s => [
  "~A small clinic with faded flu-shot posters. Dr. Anika Rao, forty-six, sharp, exhausted, examines you with gloved hands.",
  s.flags.bitten ? "DR. RAO: Pit viper. A dry bite, or nearly. You're lucky. (beat) You're the third one I've seen this year. The other two said they were bitten by a garter snake. Garter snakes don't do this." : "DR. RAO: Four stitches. Wire, not glass. (beat) There's only one fence in this town with wire like that. You've been up at the mill.",
  "MANI: There's a lab up there. And a room full of animals. Golden lanceheads, from Brazil.",
  "~She stops wrapping the bandage.",
  "DR. RAO: I don't know anything about that. Keep it clean. Come back if it blackens."],
  fx:{flag:"met_rao", set:{rao:0}}, next:"e5_rao1"},
e5_rao1:{ep:5, place:"Greyhaven Medical Clinic", time:"Fri 08:25", lines:["~She's already turning away. You have one chance to make her listen."],
  choices:[
    {t:"Show her the 46 callers on the map", to:"e5_rao2", fx:{add:{rao:1}}, req:{clues:["callers"]}, lock:"You'd need the callers' data"},
    {t:"\"You took an oath.\"", to:"e5_rao2"},
    {t:"\"My sister is missing because of this.\"", to:"e5_rao2"}
  ]},
e5_rao2:{ep:5, place:"Greyhaven Medical Clinic", time:"Fri 08:28", lines:s => [
  s.vars.rao ? "DR. RAO: (very quietly) I have that map. I drew it myself in 2015. Nobody wanted it." : "DR. RAO: Please leave, Mr. Mani.",
  "~She folds her arms."],
  choices:[
    {t:"Show her the photos of the blue M30 pills", to:"e5_rao3", fx:{add:{rao:1}}, req:{clues:["lab"]}, lock:"You'd need the lab photos"},
    {t:"Show her the bag of pills", to:"e5_rao3", fx:{add:{rao:2}}, req:{clues:["pills"]}, lock:"You didn't take the pills"},
    {t:"\"I'll go to the newspapers.\"", to:"e5_rao3"}
  ]},
e5_rao3:{ep:5, place:"Greyhaven Medical Clinic", time:"Fri 08:32", lines:s => s.vars.rao >= 2 ? [
  "~Dr. Rao goes white.",
  "DR. RAO: Four overdoses since spring. Young people. I was told to sign them as heart failure.",
  "MANI: Told by whom?",
  "DR. RAO: The county coroner. Who is also our sheriff.",
  "~She turns her back to you, very deliberately, and puts a small brass key on the counter beside the sink.",
  "DR. RAO: I go to lunch at one. The back door sticks. Everyone knows that."] : [
  "DR. RAO: I have a practice to run and a town that needs one doctor more than it needs the truth. Please go.",
  "~On your way out, a nurse catches your sleeve and whispers: \"Records room. Back door. One o'clock. She won't stop you.\""],
  fx:s => s.vars.rao >= 2 ? {trust:{rao:2}} : {trust:{rao:1}}, next:"e5_station"},

e5_station:{ep:5, place:"Sheriff's station", time:"Fri 10:00", lines:[
  "~Wood panelling, burnt coffee, a wall of framed photos. Corbin with the mayor. Corbin at a fish fry. Corbin shaking hands at a ribbon cutting, captioned \"Mill Holdings partners, 2019\". Victor, younger, smiling in the background.",
  "~At a side desk, a young deputy types slowly, watching everything. His name plate says S. ORTIZ.",
  "~You're here to file a missing persons report. Corbin takes it personally.",
  "CORBIN: Your sister had a gift for stirring things up. People here don't like being stirred."],
  fx:{flag:"met_ortiz", set:{cb:0}}, next:"e5_cb1"},
e5_cb1:{ep:5, place:"Sheriff's station", time:"Fri 10:05", lines:["CORBIN: When did you last speak to her?"],
  choices:[
    {t:"\"Sunday night. She left me a voicemail.\"", to:"e5_cb2"},
    {t:"\"Sunday. She sounded scared of someone.\"", to:"e5_cb2", fx:{add:{cb:1}}},
    {t:"\"Why don't you tell me, Sheriff?\"", to:"e5_cb2", fx:{add:{cb:2}}}
  ]},
e5_cb2:{ep:5, place:"Sheriff's station", time:"Fri 10:08", lines:["CORBIN: And what have you been doing in town all week?"],
  choices:[
    {t:"\"Waiting. Walking. Eating too much pie.\"", to:"e5_cb3"},
    {t:"\"Asking around.\"", to:"e5_cb3", fx:{add:{cb:1}}},
    {t:"\"Looking into the mill.\"", to:"e5_cb3", fx:{add:{cb:2}}}
  ]},
e5_cb3:{ep:5, place:"Sheriff's station", time:"Fri 10:10", lines:["CORBIN: (writing nothing down) Anything else? Anything you've seen?"],
  choices:[
    {t:"\"Only fog.\"", to:"e5_cb_end"},
    {t:"\"A burning boat.\"", to:"e5_cb_end", fx:{add:{cb:1}}},
    {t:"\"Trucks on the mill road at two in the morning.\"", to:"e5_cb_end", fx:{add:{cb:2}}}
  ]},
e5_cb_end:{ep:5, place:"Sheriff's station", time:"Fri 10:12", lines:s => [
  s.vars.cb >= 3 ? "~Corbin's pen stops. He looks at you for a long, flat moment. You've said too much." : "~Corbin relaxes, almost bored with you.",
  "~His radio squawks. He steps into the back room. His desk drawer is open about an inch."],
  fx:s => s.vars.cb >= 3 ? {danger:1} : null,
  timer:{secs:s => (s.trust.corbin >= 1 ? 8 : 6) - (s.vars.cb >= 3 ? 2 : 0), to:"e5_stay"},
  choices:[{t:"Open the drawer", to:"e5_drawer"},{t:"Stay in your chair", to:"e5_stay"}]},
e5_drawer:{ep:5, place:"Sheriff's station", time:"Fri 10:13", lines:[
  "~A thick envelope of cash, rubber-banded, with a sticky note: \"Nov — V.\" Under it, a folder: Coroner's reports — Greyhaven, 2026. Four death certificates, all signed \"cardiac arrest\".",
  "~Three seconds. Three photos. You're back in your chair when Corbin comes out."],
  fx:{clue:"payroll"}, next:"e5_ortiz"},
e5_stay:{ep:5, place:"Sheriff's station", time:"Fri 10:13", lines:[
  "~You stay put. Corbin comes back, hands you a form, and watches you fill it in. Across the room, Deputy Ortiz is watching too. Watching the drawer."],
  fx:{flag:"missedDrawer"}, next:"e5_ortiz"},

e5_ortiz:{ep:5, place:"Station side lot", time:"Fri 10:40", lines:[
  "~Ortiz walks you to your car. Out of Corbin's earshot, he speaks without turning his head.",
  "ORTIZ: Did your sister ever say my name?"],
  choices:[
    {t:"\"No. But she said someone at the station was decent.\"", sub:"Honest.", to:"e5_ortiz2", fx:{trust:{ortiz:2}}},
    {t:"\"Yes. She trusted you.\"", sub:"A kind lie.", to:"e5_ortiz2", fx:{trust:{ortiz:1}}}
  ]},
e5_ortiz2:{ep:5, place:"Station side lot", time:"Fri 10:42", lines:s => [
  "ORTIZ: I didn't sign up to be anybody's dog. (beat) Two of those kids who died, I went to school with their brothers.",
  s.flags.missedDrawer ? "~He slides a folded envelope into your jacket pocket. Photocopies: a cash envelope marked \"Nov — V.\", four death certificates. \"From the sheriff's drawer. I've been copying them for a month. I didn't know who to give them to.\"" : "~He glances at the station.",
  "ORTIZ: The men at that mill carry rifles, Mani. You don't.",
  "~He opens his trunk and hands you a small revolver wrapped in a cloth.",
  "ORTIZ: Confiscated off a poacher last year. It's not in any system. I didn't give you this."],
  fx:s => s.flags.missedDrawer ? {clue:["payroll","revolver"]} : {clue:"revolver"}, next:"e5_range"},
e5_range:{ep:5, place:"Old gravel pit", time:"Fri 11:30", lines:[
  "~Behind the old gravel pit, Ortiz sets three cans on a log.",
  "ORTIZ: Six rounds. Every one counts. Show me how you'd do it."],
  puzzle:{type:"order", title:"First lesson", prompt:"Put the steps in the order Ortiz teaches them.", to:"e5_range2", items:["Check it's loaded and point it downrange","Grip high with both hands","Feet apart, weight forward","Line up the sights on the target","Breathe out","Squeeze the trigger slowly"], hints:["Safety first, then the grip.","Sights before breath, breath before trigger."], giveUp:3, answerText:"Safety, grip, stance, sights, breath, squeeze."}},
e5_range2:{ep:5, place:"Old gravel pit", time:"Fri 11:40", lines:[
  "~You miss the first can. You miss the second. The third jumps off the log. The sound is enormous. Your ears ring and your hands shake.",
  "MANI: I write code, man.",
  "ORTIZ: Then think of it as the last line. You hope you never reach it."],
  next:"e5_gus"},

e5_gus:{ep:5, place:"Merrow Diner, back alley", time:"Fri 12:30", lines:[
  "~Gus is smoking by the dumpsters. You step out of the shadow behind him and hold up your phone: the ledger. \"G.P. — runs, $1,200 per run.\"",
  "~Gus drops the cigarette.",
  "GUS: The diner's been losing money for nine years. My wife's chemo wasn't covered. Victor came in with an envelope.",
  "GUS: I drive. That's all. I don't look in the back."],
  fx:{trust:{gus:0}},
  choices:[
    {t:"\"Then you'll talk to the police. Today.\"", sub:"Threaten him.", to:"e5_gus_a", fx:{danger:1}},
    {t:"\"Help me, and I'll tell them you did.\"", sub:"Offer him a way out.", to:"e5_gus_b", fx:{flag:"gusInformant", trust:{gus:2}}}
  ]},
e5_gus_a:{ep:5, place:"Merrow Diner, back alley", time:"Fri 12:33", lines:[
  "~Gus panics. He talks fast, too fast, to make you go away.",
  "GUS: Saturday. Tomorrow night. The last run. Victor's shutting it all down. The lab, the animals, everything into the lake. Then he burns the mill.",
  "~He goes back inside. Through the window, you see him pick up the phone."], next:"e5_records"},
e5_gus_b:{ep:5, place:"Merrow Diner, back alley", time:"Fri 12:33", lines:[
  "~Gus looks at you for a long time. Then he sits down on an upturned milk crate.",
  "GUS: Saturday night. Tomorrow. The last run. Victor's shutting it all down: the lab, the animals, everything into the lake. Then he burns the mill for the insurance. He wants it clean before the partner comes to look.",
  "MANI: Hades.",
  "GUS: I've never seen him. Nobody has. Victor calls him Mark when he's drunk. Just Mark.",
  "GUS: If you need a truck, or a road, or a door left open, you call me."], next:"e5_records"},

e5_records:{ep:5, place:"Clinic records room", time:"Fri 13:05", lines:[
  "~The back door sticks, exactly as promised. A narrow room of filing cabinets and boxes going back to 1979. Thirty years of a town's bodies, on paper.",
  "~You do what you know. You treat it like a dataset."],
  puzzle:{type:"pick", title:"Sort by street", prompt:"Lung illness, rashes, rare cancers. Where do the addresses cluster?", to:"e5_records2", options:[
    {t:"Lakeshore Road and Mill Road", correct:true},
    {t:"The new subdivision by the highway", why:"Built in 2012. Almost no cases."},
    {t:"Evenly across town", why:"Not even close. Look at the street column."}
  ]}},
e5_records2:{ep:5, place:"Clinic records room", time:"Fri 13:15", lines:["~Now the four 2026 \"cardiac\" deaths. You line up their dates against Ruth's truck log."],
  puzzle:{type:"pick", title:"Sort by date", prompt:"Each of the four deaths happened…", to:"e5_records3", options:[
    {t:"…on a Sunday", why:"Check the calendar again."},
    {t:"…within two days after a Tuesday or Friday night boat", correct:true},
    {t:"…in the same week", why:"They're months apart."}
  ]}},
e5_records3:{ep:5, place:"Clinic records room", time:"Fri 13:22", lines:[
  "~Clipped to the last file, in Dr. Rao's handwriting: \"Not cardiac. Fentanyl. Signed under protest. A.R.\"",
  "~You photograph everything. Thirty years. Four kids. One road."],
  fx:{clue:"medical"}, next:"e5_motel"},
e5_motel:{ep:5, place:"Lakeview Motel office", time:"Fri 17:30", lines:[
  "~Dusk. The motel sign is dark. The office door is open.",
  "~Inside: drawers on the floor. The stuffed pike smashed. Ruth's scanner stamped flat on the tiles, still hissing. Her chair tipped over. The shotgun gone.",
  "~The floorboard behind the desk is still in place. You lift it. Fourteen notebooks, untouched. She hid them before they came.",
  "~On the counter, set neatly in the middle of the mess: Victor's business card. On the back, in the same neat hand as the note on the Marsh dock:",
  "~\"One at a time.\"",
  "~Outside, your car sits on four slashed tyres. Out on the lake, the church bell rings six. Then, a seventh time. It never does that."],
  fx:{danger:1}, next:"e5_end"},
e5_end:{ep:5, place:"Greyhaven", time:"Fri 17:35", lines:["~End of Episode 5."], epEnd:true}
});
