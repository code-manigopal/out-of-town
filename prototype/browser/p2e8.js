/* Part 2 · Episode 8 · The Hades Mansion */
(function(){
const explored = s => ["m1","m2","m3","m4","m5"].filter(k => s.flags["once_" + k]).length;
Object.assign(window.OTT_PARTS.p2.scenes, {
p2e8_open:{ep:8, card:true, place:"Frozen private lake", time:"Day 12, 18:00", lines:[
  "~Night. Minus thirty-five. You and Preethi cross the lake on foot in the hunters' whites, low and fast. The mansion grows ahead: stone walls, glass wings glowing green and gold, steam rising from copper vents. A thick pipe runs from the house up the slope of the Smoke.",
  "NILA (ON RADIO, A WHISPER): He heats it from the volcano. That's how his animals survive up here. (beat) Anna. Anni. Whatever's in that house, it's alive and it's hungry. Go slow.",
  "~Three ways in."],
  fx:{heal:80, restock:true},
  choices:[
    {t:"The kennels: wolf-dogs and two guards", to:"p2e8_kennels"},
    {t:"The boathouse roof, to a balcony", to:"p2e8_roof"},
    {t:"Grenade the generator shed and go in loud", to:"p2e8_loud", req:s => s.grenades.mani + s.grenades.preethi > 0, lock:"No grenades left"}
  ]},
p2e8_kennels:{ep:8, place:"Gatehouse and kennels", time:"Day 12, 18:20", lines:["~Wolf-dog hybrids pace a heated run. Two guards in the gatehouse with a thermos and a card game. Preethi crushes her sedatives into a hunk of the dogs' own meat."],
  combat:{id:"kennels", title:"The kennels", stealthBonus:.05, intro:"The dogs are eating. The guards are arguing about cards.", enemies:[{n:"Gate guard",hp:50},{n:"Gate guard",hp:50}], to:"p2e8_hall"}},
p2e8_roof:{ep:8, place:"Boathouse roof", time:"Day 12, 18:20", lines:["~The boathouse roof is coated in ice. Three metres of it to the balcony rail, with a twenty-metre drop to the frozen lake."],
  timer:{secs:5, to:"p2e8_roof_slip"},
  choices:[{t:"Crawl on your stomach, spreading your weight", to:"p2e8_hall"},{t:"Walk it quickly", to:"p2e8_roof_slip"}]},
p2e8_roof_slip:{ep:8, place:"Boathouse roof", time:"Day 12, 18:22", lines:["~Your boot slides. Preethi grabs your parka hood and hauls. You lie on the ice together, breathing, then crawl the rest."], fx:{hp:{mani:-10}}, next:"p2e8_hall"},
p2e8_loud:{ep:8, place:"Generator shed", time:"Day 12, 18:20", lines:["~The grenade blows the generator shed apart. Every light dies for thirty seconds, then flickers back on the geothermal backup. Guards run toward the noise."],
  fx:s => { if(s.grenades.mani > 0) s.grenades.mani--; else s.grenades.preethi--; return null; },
  combat:{id:"loud", title:"Front lawn", startAlert:true, intro:"Three guards running toward the fire.", enemies:[{n:"Guard",hp:50},{n:"Guard",hp:50},{n:"Guard",hp:55}], to:"p2e8_hall"}},

p2e8_hall:{ep:8, place:"Inside the Hades Mansion", time:"Day 12, 18:40", lines:s => [
  explored(s) === 0 ? "~Inside. Warm air, stone floors, the smell of wet earth and something like a zoo. Corridors lead off in every direction." : (explored(s) >= 3 ? "~A wide staircase leads up to a study with firelight under the door. You could keep exploring, or go up." : "~Back in the central hall. Corridors in every direction."),
  "NILA (ON RADIO): He's in the study, upstairs. He's waiting. But the vault codes, the layout, anything you learn first, it all helps."],
  choices:[
    {t:"The courtyard enclosure", to:"p2e8_tiger", once:"m1"},
    {t:"The glass conservatory", to:"p2e8_cons", once:"m2"},
    {t:"The indoor pool", to:"p2e8_pool", once:"m3"},
    {t:"The trophy hall", to:"p2e8_trophy", once:"m4"},
    {t:"The radio room", to:"p2e8_radio", once:"m5"},
    {t:"Go up to the study", to:"p2e8_study", req:s => explored(s) >= 3, lock:"Explore at least three wings first"}
  ]},
p2e8_tiger:{ep:8, place:"Courtyard enclosure", time:"Day 12, 18:50", lines:[
  "~A heated glass yard. A Siberian tiger lies on a warm rock, watching you with complete calm. Two guards patrol the corridor on the far side of the glass. Two gates: the inner gate into the yard, the outer gate into the guards' corridor. A lever for each.",
  "PREETHI: He keeps a tiger. Of course he keeps a tiger."],
  puzzle:{type:"pick", title:"The tiger", prompt:"You need the guards gone. Never fight the tiger.", to:"p2e8_hall", options:[
    {t:"Open the inner gate and walk through the yard", why:"The tiger stands up. You step back very, very slowly and close the gate. Try something else."},
    {t:"Open the outer gate as the guards pass, and let the tiger out to them", correct:true},
    {t:"Shoot the tiger", why:"No. Absolutely not. Preethi puts her hand on your gun."}
  ], okMsg:"The outer gate slides open. The guards see the tiger, and the tiger sees the guards. Everyone leaves the corridor very fast, in different directions."}},
p2e8_cons:{ep:8, place:"Glass conservatory", time:"Day 12, 19:00", lines:[
  "~A jungle under glass, hot and dripping. Free-roaming golden lanceheads among the roots. A black mamba draped along the rafters. Poison dart frogs on the leaves like sweets.",
  "~Move slowly. Light every step. Don't touch the leaves."],
  timer:{secs:7, to:"p2e8_cons_bite"},
  choices:[
    {t:"Slowly, flashlight on the path, step only on bare stone", to:"p2e8_cons_ok"},
    {t:"Push through the leaves to save time", to:"p2e8_cons_bite"}
  ]},
p2e8_cons_bite:{ep:8, place:"Glass conservatory", time:"Day 12, 19:02", lines:s => s.clues.includes("antivenom") ? [
  "~A gold blur from the roots. Preethi cries out. Two punctures in her ankle above the boot.",
  "~Her hands are shaking but steady enough. She draws the antivenom from the Hayden Deep fridge and injects herself in the thigh. You hold her through the worst of it.",
  "PREETHI: (through her teeth) Good thing I'm a pharmacist."] : [
  "~A gold blur from the roots. Preethi cries out. Two punctures in her ankle above the boot.",
  "~No antivenom. She ties a pressure bandage, white-faced, and keeps going. \"It was a small one. I think it was dry. I think.\""],
  fx:s => s.clues.includes("antivenom") ? {hp:{preethi:-15}} : {hp:{preethi:-35}}, next:"p2e8_cons_ok"},
p2e8_cons_ok:{ep:8, place:"Glass conservatory", time:"Day 12, 19:05", lines:["~At the far end of the conservatory, a service corridor and a ring of keys on a hook: the household keys, labelled. One says VAULT — MH."], fx:{flag:"vaultKey"}, next:"p2e8_hall"},
p2e8_pool:{ep:8, place:"Indoor pool", time:"Day 12, 19:10", lines:[
  "~A dark, warm saltwater pool. Things move under the surface: saltwater crocodiles. A catwalk crosses above, and a guard walks it back and forth."],
  timer:{secs:6, to:"p2e8_pool_bad"},
  choices:[
    {t:"Cross behind him as he turns away", to:"p2e8_pool_ok"},
    {t:"Cross toward him and take him down", to:"p2e8_pool_bad"}
  ]},
p2e8_pool_bad:{ep:8, place:"Indoor pool", time:"Day 12, 19:11", lines:["~The guard turns. A shot cracks off the tiles. You hit him before he fires again and he goes over the rail. You don't look at the water. Neither does Preethi."], fx:{hp:{mani:-15}, danger:1}, next:"p2e8_hall"},
p2e8_pool_ok:{ep:8, place:"Indoor pool", time:"Day 12, 19:11", lines:["~You cross in his shadow, step for step. He never turns. Below you, something large rolls lazily in the dark water."], next:"p2e8_hall"},
p2e8_trophy:{ep:8, place:"Trophy hall", time:"Day 12, 19:15", lines:[
  "~Stuffed animals from every continent, glass eyes catching the light. A portrait gallery.",
  "~Robert Hayden in a long dark coat, 1978, beside the Merrow dam. A boy with a jar of snakes on a windowsill. A young man at a university lab bench. A plaque: \"Hayden Family Trust — est. 1934.\"",
  "MANI: The coat. It's the same coat.",
  "NILA (ON RADIO): Father and son. (beat) Anna. Which one have we been listening to?"],
  fx:{clue:"portraits"}, next:"p2e8_hall"},
p2e8_radio:{ep:8, place:"The radio room", time:"Day 12, 19:20", lines:[
  "~Floor-to-ceiling equipment. Racks of recordings labelled by date: every one of Nila's broadcasts from Greyhaven, and her new show in Windsor. A wall of photos of Nila taken from a distance: at Pike Point, at the Windsor studio, asleep in hospital.",
  "~Nila, listening through your radio, hears her own voice playing on a loop in his room.",
  "NILA (ON RADIO): …Anna. Burn it. All of it."],
  choices:[
    {t:"Burn it: a flare into the tape racks", to:"p2e8_hall", fx:{flag:"burned", danger:1, toast:"Alarms ring through the house."}},
    {t:"Take one tape and leave quietly", to:"p2e8_hall"}
  ]},

p2e8_study:{ep:8, place:"Hades's study", time:"Day 12, 19:30", lines:[
  "~A wood-panelled study. A fire. Tea in a china pot on a low table. A golden lancehead coiled on the desk like a sleeping cat. Behind the desk, for the first time, his face.",
  "~Mark Hayden, fifty-eight, silver-haired, soft-voiced, the long dark coat over a cashmere sweater.",
  "HADES: Shoes. (You don't move.) Fine. (He pours three cups.) Preethi, the pharmacist. Mani, the analyst. And Nila. I assume you're listening, Lighthouse.",
  "NILA (ON RADIO): I'm listening, Mark.",
  "~He smiles, pleased, like a man hearing a favourite song.",
  "HADES: Your sister is the most interesting person I've ever listened to. A hundred nights of a voice in the dark, telling the truth to people who don't want it.",
  "HADES: Victor talked too much, so I stopped him. My father always said, never let the help speak at the table.",
  "MANI: Why her?",
  "HADES: She was the perfect subject: young, healthy, isolated, curious. She cost me Greyhaven. And I knew you'd come. (He looks at you.) Brothers always come."],
  next:"p2e8_offer"},
p2e8_offer:{ep:8, place:"Hades's study", time:"Day 12, 19:45", lines:[
  "~He sets three identical glass vials on the desk, each with a white cap. A, B, C.",
  "HADES: One of these is HX-7C, the cure. The other two are HX-7, concentrated. One dose of that and she dies by morning. (beat) Give me the file, and choose. I'll let you take whichever one you pick. I want to see if you can save her.",
  "PREETHI: You'll just let us walk out.",
  "HADES: I'm a collector, Preethi. I collect moments.",
  "~Preethi asks for one minute and opens her pharmacy kit on his desk. He nods, delighted.",
  "~From the Hayden Deep files, she knows what HX-7C should do: a faint blue colour reaction, needle-shaped crystals, and slightly basic, around pH 7.6. She runs three tests on each vial.",
  "~Vial A: stays clear. Flat plate crystals. pH 6.8.",
  "~Vial B: faint blue. Needle crystals. pH 7.6.",
  "~Vial C: stays clear. Needle crystals. pH 7.4."],
  puzzle:{type:"pick", title:"The three vials", prompt:"Which vial is the cure?", to:"p2e8_usb", options:[
    {t:"Vial A", why:"NILA (on radio): Anni, A failed the colour test and the crystals are wrong. Check again."},
    {t:"Vial B", correct:true},
    {t:"Vial C", why:"NILA (on radio): Anni, C has the right crystals, but no blue, and the pH is low. He made it to fool you. Check again."}
  ], okMsg:"Vial B passes all three."}},
p2e8_usb:{ep:8, place:"Hades's study", time:"Day 12, 19:50", lines:[
  "HADES: (applauding softly) Oh, she's good. She's very good.",
  "~You hand over the USB. He plugs it into his laptop. Blank. Wiped.",
  "NILA (ON RADIO): I erased it remotely this morning, Mark. You never needed it. You just wanted us here.",
  "~Hades looks at the empty screen for a long moment. Then he laughs, genuinely.",
  "HADES: I'm going to miss you, Lighthouse.",
  "~Outside, across the lake, a green flare climbs into the sky. Daniel. Then, far off, the thud of helicopter rotors.",
  "~Hades sighs and presses a button under the desk. Deep below the house, valves open. The pipes scream. Steam explodes from vents in every wing. Glass shatters in the conservatory. The animals are loose."],
  fx:{clue:"cure"}, next:"p2e8_escape"},
p2e8_escape:{ep:8, place:"The mansion · eruption", time:"Day 12, 20:00", lines:["~Steam, falling glass, alarms. Guards between you and the back terrace, where Hades is disappearing up the slope of the Smoke."],
  combat:s => ({id:"escape", title:"The eruption", startAlert:true, intro:"Through the burning conservatory. Lanceheads on the floor. Guards in the steam.", enemies:s.flags.burned ? [{n:"Guard",hp:50},{n:"Guard",hp:50},{n:"Guard",hp:50},{n:"Head of house security",hp:70,boss:true}] : [{n:"Guard",hp:50},{n:"Guard",hp:50},{n:"Head of house security",hp:65,boss:true}], to:"p2e8_smoke", winMsg:"Past the open courtyard, the tiger, now free, walks past you and away into the trees without a glance."}),
  fx:{heal:65}},
p2e8_smoke:{ep:8, place:"The Smoke", time:"Day 12, 20:20", lines:[
  "~The black cone above you, hot under your boots despite the snow. Steam everywhere. Hades on a ledge, the golden lancehead around his arm, the coat whipping in the hot wind.",
  "HADES: You know what my father will say? That I played with my food. (beat) He's right.",
  "~The ground cracks between you. A column of scalding steam erupts from the fissure with a roar. When it clears, the ledge is empty. A golden lancehead slides away over the rocks. The coat is gone. No body.",
  "~Neither of you fired. The Smoke took him."],
  next:"p2e8_heli"},
p2e8_heli:{ep:8, place:"Frozen private lake", time:"Day 12, 20:40", lines:[
  "~An OPP helicopter lands on the ice, rotor wash blasting snow. Dunn jumps out, then two paramedics carrying Daniel on a stretcher, grinning, leg splinted.",
  "DUNN: Your journalist sent the lab files to every newspaper in the country an hour ago. The judge in Kenora stopped golfing. (beat) Get in.",
  "~Preethi holds the vial in both hands inside her parka, against her heart, the whole flight."],
  next:"p2e8_hosp"},
p2e8_hosp:{ep:8, place:"Hospital, Windsor", time:"Two days later", lines:[
  "~Dr. Singh. Dr. Marchetti on a video call from Red Lake. Preethi with three pages of notes. The first dose.",
  "~A long, silent wait. Amma praying under her breath. Appa holding Nila's hand. Ortiz asleep in a plastic chair in the corridor.",
  "~Nila's eyes open.",
  "NILA: Anna… Anni… neenga romba late. || You two are very late.",
  "PREETHI: (crying and laughing) Traffic."],
  fx:{setHealth:100}, next:"p2e8_pongal"},
p2e8_pongal:{ep:8, place:"Mani and Preethi's apartment, Windsor", time:"January · Pongal", lines:[
  "~Appa said it a year ago: \"Come home for Pongal.\" The pongal pot boils over on the stove for luck and everyone shouts \"Pongalo pongal!\" A kolam at the door. Sugarcane in the corner. Amma and Appa in person this time.",
  "~Ortiz, Ruth and Jonah on a video call from Greyhaven. Daniel, Ivy and Dunn on another from Red Lake. Daniel's leg is in a cast covered in signatures.",
  "~Nila, thinner, hair short, laughing, back on her feet.",
  "NILA: Appa, poana varusham nee sonna, Pongal-ku veetuku vaanu. (beat) Naan vandhutten. || Appa, last year you said come home for Pongal. (beat) I came."],
  next:"p2e8_hook"},
p2e8_hook:{ep:8, place:"Later that night", time:"January", lines:[
  "~Preethi sits on the edge of the bed, holding something behind her back. She shows you a pregnancy test. Positive.",
  "~You stare at it. Then at her. Joy, so big it's quiet.",
  "~In the living room, Nila's old radio, switched off on the shelf, clicks to static on its own. An old man's voice, slow and amused:",
  "OLD MAN (ON RADIO): Congratulations, Anni.",
  "~Silence. Nobody hears it."],
  next:"p2_end"},
p2_end:{ep:8, ending:"p2end", title:"End of Part 2", kicker:"Out of Town: Red Lake", place:"Somewhere else", time:"—", lines:[
  "~A stone house somewhere you have never seen. Snow at the windows.",
  "~A very old man in a long dark coat, Robert Hayden, sits beside a hospital bed.",
  "~In the bed, burned and bandaged, Mark Hayden opens his eyes.",
  "~\"You played with your food, Mark,\" the old man says. \"Now we do it properly.\"",
  "~OUT OF TOWN WILL RETURN."]}
});
})();
