/* Part 1 · Episode 7 · Pike Point */
Object.assign(window.OTT_PARTS.p1.scenes, {
e7_open:{ep:7, card:true, place:"Lake Merrow", time:"Sat 11:31", lines:[
  "~Black. A muffled boom through the water: a shotgun. Then a hand grabs your harness and hauls you upward. Eli, who dived in after you without a mask.",
  "~You break the surface choking. A small skiff roars out of the fog. Standing in it, soaked, grey hair loose, shotgun at her shoulder: Ruth Vane. She fires again over the second boat. Its outboard screams and it flees into the fog.",
  "RUTH: Told you I sleep light.",
  "~Walter, shaking, wraps you in a blanket. You check the yellow housing in your arms. Nila's camera is safe."],
  fx:{trust:{ruth:1, eli:1}}, next:"e7_skiff"},
e7_skiff:{ep:7, place:"Ruth's skiff, crossing the lake", time:"Sat 12:15", lines:[
  "~Ruth steers north toward a dark wooded headland. An old steel radio tower rises out of the trees. Pike Point.",
  "RUTH: They came Thursday night. Two of them. I went out the back with Harold's shotgun and took the skiff. I've been at Jonah Pike's cabin since.",
  "RUTH: Nila told me once: \"If I'm not home, I'm with Jonah.\" Jonah won't tell even me where she is. Stubborn old goat.",
  "MANI: Is she—",
  "RUTH: He says she's alive. He says it every day. I choose to believe him."],
  next:"e7_jonah"},
e7_jonah:{ep:7, place:"Jonah's cabin, Pike Point", time:"Sat 13:00", lines:[
  "~A log cabin crammed with radios: shortwave sets, oscilloscopes, a wall of QSL cards from around the world. Jonah Pike, seventy, white beard, a cardigan full of holes, looks at you over his glasses for a long time.",
  "JONAH: You're Anna. She talks about you on the air when she thinks nobody's listening. (beat) Somebody always was.",
  "~He's recorded every one of Nila's 23:00 broadcasts. And something else."],
  puzzle:{type:"search", title:"Jonah's tapes", prompt:"Listen to the recordings.", need:3, doneLabel:"Play Nila's camera", to:"e7_footage", spots:[
    {t:"Tape 1 · October 23", text:"Nila broadcasting about the callers. Then, on a frequency right beside hers, a man's calm voice: \"Brave girl.\""},
    {t:"Tape 2 · October 30", text:"Nila describing the night boats. The voice again: \"You're very close now, Nila.\""},
    {t:"Tape 3 · Tuesday", text:"The voice from your car radio: \"He's already here.\" And then, on a private channel Jonah caught by luck, the same voice speaking to someone else: \"Victor, you're sloppy. Clean it before I come. Or I clean you.\"", clue:"jonahTapes"},
    {t:"Jonah's notebook", text:"\"Uses relays. Bounces off three or four repeaters. Can't fix his position. A professional. Victor is afraid of him. You can hear it.\""}
  ]}},
e7_footage:{ep:7, place:"Jonah's cabin", time:"Sat 13:40", lines:[
  "~You connect Nila's camera to Jonah's monitor. Timestamped last Sunday, 22:10.",
  "~Underwater: the barrels, the dead tortoises, a milky cloud. Then Nila surfaces under a dock and films the boat above it. Victor and Corbin, side by side, watching workers drop a crate over the side.",
  "CORBIN (ON FOOTAGE): Is that the last of the dead ones?",
  "VICTOR (ON FOOTAGE): The ones Hades won't pay for, yes.",
  "~The camera turns to Nila's face, lit by her dive torch, whispering:",
  "NILA (ON FOOTAGE): If someone's watching this, I didn't make it back. Barrels at St. Brendan's. Victor Kessler. Sheriff Corbin. Tell everyone.",
  "MANI: She made it back. (To Jonah.) Take me to her."],
  fx:{clue:"footage"}, next:"e7_trail"},
e7_trail:{ep:7, place:"Pike Point trail", time:"Sat 16:30", lines:[
  "~Jonah leads you and Ruth up a rough path through the pines. Wind off the lake. Above, the rusted tower, a single red aircraft light still blinking at the top.",
  "JONAH: That was 94.1's original transmitter, till they moved it into town in '98. They left everything. I kept it alive, out of spite. (beat) It still reaches every radio in the county.",
  "MANI: That's how she broadcast on 94.1 when the station was off.",
  "JONAH: Watch your feet. She's rigged the trail. Trip wires, tin cans, a flare."],
  fx:{set:{trips:0}}, next:"e7_trip1"},
e7_trip1:{ep:7, place:"Pike Point trail", time:"Sat 16:35", lines:["~Your flashlight catches a glint at ankle height between two pines. Or was it just ice?"],
  choices:[{t:"Step high over the glint", to:"e7_trip2"},{t:"Brush it aside with your boot", to:"e7_trip2", fx:{add:{trips:1}, toast:"Tin cans rattle in the trees."}}]},
e7_trip2:{ep:7, place:"Pike Point trail", time:"Sat 16:38", lines:["~A fallen log across the path. The obvious step is right in the middle."],
  choices:[{t:"Step on the middle", to:"e7_trip3", fx:{add:{trips:1}, toast:"Cans clatter. Somewhere a bird explodes from a tree."}},{t:"Climb over at the root end", to:"e7_trip3"}]},
e7_trip3:{ep:7, place:"Pike Point trail", time:"Sat 16:41", lines:["~The shed is in sight. A string of fishing line runs low across the last metre, tied to a flare stake."],
  choices:[{t:"Duck under at the stake end, where it's highest", to:"e7_trip_end"},{t:"Hurry through", to:"e7_trip_end", fx:{add:{trips:2}}}]},
e7_trip_end:{ep:7, place:"Pike Point", time:"Sat 16:45", lines:s => s.vars.trips >= 2 ? [
  "~A flare whooshes up from the trees and bursts red over the headland. Ruth swears. Jonah closes his eyes.",
  "JONAH: Well. If anybody in town was looking at Pike Point, they just got a postcard."] : [
  "~You reach the shed without a sound. Jonah nods, impressed."],
  fx:s => s.vars.trips >= 2 ? {flag:"flareTripped", danger:1} : null, next:"e7_reunion"},

e7_reunion:{ep:7, place:"Transmitter shed, Pike Point", time:"Sat 17:00", lines:[
  "~A concrete shed at the foot of the tower. A camp stove, a sleeping bag, tins of beans, a crate of bottled spring water (half empty), a rack of humming transmitter equipment. Nila's radio bag on a hook.",
  "NILA: Stop right there.",
  "~She steps from behind the transmitter rack with a flare gun in a shaking hand. Thinner. Hair tied back. A scrape across one cheek.",
  "~She sees your face. The flare gun drops.",
  "NILA: Anna?",
  "~For a long moment, neither of you moves. Then she's across the shed and you're holding her, and she's crying and laughing and hitting your shoulder.",
  "NILA: Naan dhaan vara vendaamnu sonnene! || I told you not to come!",
  "MANI: Eppo naan un pechu kettirukken? || Since when do I listen to you?"],
  next:"e7_talk"},
e7_talk:{ep:7, place:"Transmitter shed", time:"Sat 17:10", lines:s => [
  "~Ruth and Jonah step outside to give you a minute. You sit on the sleeping bag together.",
  (["t1","t2","t3","t4"].filter(t => s.flags["once_" + t]).length >= 3) ? "~There's one more thing in your bag." : "~There's so much to say. Where do you start?"],
  choices:[
    {t:"\"Amma and Appa.\"", to:"e7_t1", once:"t1"},
    {t:"\"What happened Sunday?\"", to:"e7_t2", once:"t2"},
    {t:"\"The voice.\"", to:"e7_t3", once:"t3"},
    {t:"\"Eli.\"", to:"e7_t4", once:"t4"},
    {t:"Give her the Diwali present", to:"e7_gift", show:s => ["t1","t2","t3","t4"].filter(t => s.flags["once_" + t]).length >= 3}
  ]},
e7_t1:{ep:7, place:"Transmitter shed", time:"Sat 17:12", lines:s => s.flags.honest6 ? [
  "NILA: Amma-ku theriyuma? || Does Amma know?",
  "MANI: Theriyum. Naan sonnen. || She knows. I told her.",
  "NILA: Nalladhu. Amma kitta poi solla enakku pidikkadhu. || Good. I hate lying to Amma."] : [
  "NILA: Amma-ku theriyuma? || Does Amma know?",
  "MANI: Illa. Nee kulichittu irukkannu sonnen. || No. I told her you were having a bath.",
  "~Nila laughs, then stops laughing.",
  "NILA: Naalaiku naane solren. || I'll tell her myself tomorrow."],
  fx:{trust:{}}, next:"e7_talk"},
e7_t2:{ep:7, place:"Transmitter shed", time:"Sat 17:15", lines:[
  "NILA: Corbin's car outside the flat. Men on the stairs. I went out the back with my radio bag, along the shore in the dark, all the way to Jonah's.",
  "NILA: Phone-a vittutu odinen. Rangoli-a paadhi-la vittutten. Kaalaila thirumbi varuvennu nenachen. || I ran and left my phone. I left my rangoli half done. I thought I'd be back by morning."],
  next:"e7_talk"},
e7_t3:{ep:7, place:"Transmitter shed", time:"Sat 17:18", lines:[
  "~Nila goes quiet.",
  "NILA: Avan enakku badhil sonnaan. Ovvoru raathiriyum. Naan enna dress pottirukkennu avanukku theriyum. Naan azhudhadhu kooda theriyum. Water tower-ai vida pakkathula naan avana paathadhe illa. || He answered me. Every night. He knew what I was wearing. He even knew when I cried. I never saw him closer than the water tower."],
  next:"e7_talk"},
e7_t4:{ep:7, place:"Transmitter shed", time:"Sat 17:21", lines:[
  "NILA: Naan night-la veliya poradha avan Corbin kitta sonnaan. Enakku theriyum. Avan mela kovapadaadha. Corbin Tess vaazhkaiya azhichiruppaan. || He told Corbin I went out at night. I know. Don't be angry with him. Corbin would have destroyed Tess's life."],
  next:"e7_talk"},
e7_gift:{ep:7, place:"Transmitter shed", time:"Sat 17:25", lines:[
  "~You pull a gift-wrapped box out of your soaked duffel. The bow is crushed.",
  "MANI: Happy Deepavali. Oru naal munnaadiye. || Happy Deepavali. A day early.",
  "~She unwraps it. A new handheld ham radio. She laughs through tears.",
  "NILA: Oru crime scene vazhiya naalu mani neram drive panni enakku radio kondu vandhiya? || You drove four hours through a crime scene to bring me a radio?",
  "MANI: Sweets-um dhaan. Konjam nanaanjiduchu. || And sweets. They got a bit wet."],
  fx:{flag:"giftGiven"}, next:"e7_plan"},

e7_plan:{ep:7, place:"Transmitter shed", time:"Sat 19:00", lines:[
  "~The four of you around the camp stove, the proof spread on the concrete floor.",
  "~Jonah nudges the crate of water bottles with his boot.",
  "JONAH: Where'd these come from? I never brought you water.",
  "NILA: They were here when I came. I thought you left them.",
  "~Jonah frowns. Then the plan takes over, and nobody mentions it again.",
  "NILA: There's no cell signal on Pike Point. If we drive out to call the police, Corbin's on every road. If we call 911 from town, it routes through Corbin's dispatch.",
  "JONAH: So you don't call. You broadcast.",
  "NILA: At 23:00. On 94.1, to every radio in the county. On 7.185 for the ham operators. And Jonah patches it onto the provincial police band. (beat) They can bury a phone call. They can't bury a whole town hearing it.",
  "~The transmitter powers on. But the feed line up the tower is dead. A length of coax is missing."],
  choices:[
    {t:"Use Nila's cut cable from the flat", to:"e7_antenna", req:{flags:["cableKept"]}, lock:"You didn't keep the cable", fx:{flag:"strongSignal"}},
    {t:"Use Jonah's short spare", to:"e7_antenna", fx:{toast:"The spare works, but the signal will be weaker."}}
  ]},
e7_antenna:{ep:7, place:"Pike Point tower, first platform", time:"Sat 19:30", lines:[
  "~You climb to the first platform with the cable over your shoulder. Nila talks you through it on her new radio. You fit the coax. Now the dish has to face the town.",
  "NILA (ON RADIO): Turn it slowly. Watch the meter. Greyhaven's somewhere south-southwest."],
  puzzle:{type:"tune", title:"Align the antenna", prompt:"Turn the dish until the signal meter peaks.", min:150, max:260, step:1, startAt:150, target:208, tol:4, unit:"°", decimals:0, hints:["South-southwest is a little past 200°.","Try around 205° to 210°."], giveUp:4, answerText:"208°. The meter jumps to green.", to:"e7_eli"}},
e7_eli:{ep:7, place:"Outside the transmitter shed", time:"Sat 22:20", lines:[
  "~The signal meter glows green. Forty minutes to 23:00.",
  "~Eli arrives up the trail, out of breath, carrying a rifle from his father's closet.",
  "ELI: Tess is safe. She's with Father Tom at the church. I came to help.",
  "~Nila hugs him. You don't.",
  "~Ten minutes later you step outside to check the trip wires and hear Eli around the side of the shed, low, into a handheld radio.",
  "ELI (ON RADIO): …Pike Point. Now. (beat) I'm sorry.",
  "~You round the corner. Eli turns, guilty, the radio still in his hand.",
  "~Across the lake, an orange glow rises over the trees: the mill is burning. On the lake road below Pike Point, a line of headlights stops at the foot of the trail.",
  "~The new radio on Nila's belt crackles. A man's voice, warm, amused.",
  "VICTOR (ON RADIO): Nila. Mani. And Ruth, I assume, with Harold's shotgun. (beat) Let's talk about this like adults."],
  next:"e7_end"},
e7_end:{ep:7, place:"Pike Point", time:"Sat 22:31", lines:["~End of Episode 7."], epEnd:true}
});
