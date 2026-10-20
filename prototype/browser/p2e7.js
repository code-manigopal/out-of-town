/* Part 2 · Episode 7 · The Burn */
Object.assign(window.OTT_PARTS.p2.scenes, {
p2e7_open:{ep:7, card:true, place:"Frozen lake, the Burn", time:"Day 12, 08:45", lines:[
  "~The Norseman lies on its skis on the ice, one wing crumpled, the propeller bent. Steam from the engine. You pull yourself out of the cockpit. Preethi is already beside Daniel, whose leg is bent the wrong way below the knee.",
  "PREETHI: Broken. Closed fracture. (To Daniel.) This will hurt very much.",
  "DANIEL: You're a pharmacist, not a— AHH."],
  fx:{hp:{mani:-15, preethi:-10}},
  puzzle:{type:"order", title:"Splint the leg", prompt:"Preethi talks you through it. Put the steps in order.", to:"p2e7_daniel", items:["Check the foot for pulse and feeling","Gently straighten the leg into line","Pad around the leg with a jacket","Brace it with the seat strut, above and below the break","Tie it firm with paracord, not tight","Check the foot again"], hints:["Check before and after.","Line, pad, brace, tie."], giveUp:3, answerText:"Check, align, pad, brace, tie, check again."}},
p2e7_daniel:{ep:7, place:"Frozen lake, the Burn", time:"Day 12, 09:10", lines:[
  "DANIEL: (grey, sweating) Go. I'll fix the radio and keep the flare gun warm. When you're done, fire a green flare and I'll call it in. (beat) If you're not back by dark, I'm eating your sambar rice.",
  "NILA (ON RADIO, FAINT): …Anna… I'm here. I'm listening to them. I'm in their radio."],
  fx:{setHealth:15}, next:"p2e7_shore"},
p2e7_shore:{ep:7, place:"Lake shore · Area 1", time:"Day 12, 09:30", lines:["~The tree line. Snowmobile engines somewhere. Two hunters in white camouflage working the shore, rifles slung. They don't know the plane came down this far west."],
  combat:{id:"shore", title:"The shore", intro:"Two hunters, unaware. Take one alive enough to take his clothes.", note:"A clean stealth takedown here gets you a disguise.", enemies:[{n:"Hunter",hp:45},{n:"Hunter",hp:45}], to:"p2e7_disguise", winMsg:"Two hunters down in the snow."}},
p2e7_disguise:{ep:7, place:"Lake shore", time:"Day 12, 09:45", lines:[
  "~You take the first hunter's white parka, his toque and his radio. In the whites, from fifty metres, you're one of them.",
  "~Preethi looks you up and down. \"You look like a marshmallow with a gun.\""],
  fx:{flag:"disguise"}, next:"p2e7_ridge"},
p2e7_ridge:{ep:7, place:"The burned ridge · Area 2", time:"Day 12, 10:30", lines:[
  "~A ridge of black, dead trunks from the old fire, new pines thick below. A glint on the crest.",
  "PREETHI: Sniper. The same one who shot the plane.",
  "~You spot for her with the binoculars: \"Three hundred. Wind left.\""],
  combat:{id:"ridge", title:"The sniper on the ridge", solo:"preethi", startAlert:true, noStealth:true, intro:"Breath fog on the crest. Mani calls the distance.", enemies:[{n:"Ridge sniper",hp:75,boss:true}], to:"p2e7_ridge2", winMsg:"The glint on the crest goes dark."}},
p2e7_ridge2:{ep:7, place:"Sniper's nest", time:"Day 12, 10:50", lines:["~In the sniper's nest: another NSB grenade case, and a map of the hunters' patrol routes. A camp on the north trail. An ammo cabin in the ravine. A fire lookout tower where the routes meet.","MANI: We split. Meet at the fire lookout.","PREETHI: I hate this plan.","MANI: Nila made it.","PREETHI: I hate it less."], fx:{trunk:6, restock:true, heal:70}, next:"p2e7_camp"},
p2e7_camp:{ep:7, place:"The north trail · Mani", time:"Day 12, 11:30", lines:["~A hunters' camp: tents, a fire, four men, two dogs. In the white parka you could walk right through it. Or bait the wolves you've heard all morning toward the meat rack."],
  combat:{id:"camp", title:"The hunters' camp", solo:"mani", stealthBonus:.08, intro:"Four men around a fire. The dogs haven't caught your scent.", note:"Your disguise lets you walk past them.", enemies:[{n:"Hunter",hp:45},{n:"Hunter",hp:45},{n:"Hunter",hp:45},{n:"Camp boss",hp:60}], to:"p2e7_cabin"}},
p2e7_cabin:{ep:7, place:"The ravine · Preethi", time:"Day 12, 11:45", lines:["~A frozen creek and an old trapper's cabin, now an ammo dump. Three guards inside. Preethi can go under the cabin through the crawlspace, or through the front door with the shotgun."],
  combat:{id:"cabin", title:"The trapper's cabin", solo:"preethi", intro:"Three guards in the cabin. Nobody's watching the crawlspace.", enemies:[{n:"Guard",hp:45},{n:"Guard",hp:45},{n:"Guard",hp:50}], to:"p2e7_meet"}},
p2e7_meet:{ep:7, place:"Foot of the fire lookout", time:"Day 12, 12:30", lines:["~You reach the old steel fire lookout tower at the same moment, from opposite sides. Preethi has a cut on her cheek and a stolen box of shells under her arm. You hold each other for exactly three seconds."], fx:{ammo:{shells:8, rifle:20}}, next:"p2e7_ice"},
p2e7_ice:{ep:7, place:"The south lake · Area 4", time:"Day 12, 13:00", lines:[
  "~Beyond the lookout, a long lake to cross. Too many snowmobiles. Kane's voice on the hunters' channel, organising them.",
  "NILA (ON RADIO, A RASP): Anna… give me the hunter's radio.",
  "~You hold the captured radio against your own. Nila, in Windsor, listens for a full minute. Then she speaks on Kane's channel in Kane's clipped, flat voice.",
  "NILA (AS KANE): All units. Targets on the south lake. Intercept. Now.",
  "~Engines roar. Eight snowmobiles race out onto the south lake, where the current keeps the ice thin.",
  s => s.flags.restraint ? "PREETHI: Mani. We said only to survive. Warn them." : "~Preethi looks at you. She doesn't say anything."],
  choices:[
    {t:"Warn them on their channel", sub:"They turn back. You lose your head start.", to:"p2e7_ice_warn", fx:{flag:"warned"}},
    {t:"Let it happen", sub:"The way to the lookout is clear.", to:"p2e7_ice_let"}
  ]},
p2e7_ice_warn:{ep:7, place:"The south lake", time:"Day 12, 13:02", lines:[
  "MANI (INTO RADIO): Thin ice! South lake is thin ice! Turn back!",
  "~The snowmobiles skid, turn, scatter. Every one of them makes it back to shore. Now they know exactly where you are.",
  "NILA (ON RADIO): …You were right. I'm glad you were right."],
  fx:{danger:1}, next:"p2e7_kane1"},
p2e7_ice_let:{ep:7, place:"The south lake", time:"Day 12, 13:02", lines:[
  "~The ice opens. The lake takes machines and men. Then it's quiet, except for the wind.",
  "~Preethi doesn't say anything for a long time.",
  "NILA (ON RADIO): …Anna, I'm sorry. I'm sorry I made you do that."],
  next:"p2e7_kane1"},
p2e7_kane1:{ep:7, place:"The fire lookout", time:"Day 12, 15:00", lines:s => [
  "~Kane, shoulder bandaged from Starratt-Olsen, waits at the top of the lookout with a heavy rifle" + (s.flags.warned ? ", and his surviving men have rallied to him." : "."),
  "KANE: (shouting down) He said you'd come! He said you'd both come! He's got a bet on which of you dies first!"],
  combat:s => ({id:"kane1", title:"Kane · the approach", startAlert:true, intro:"Kane snipes from the tower. Close in tree by tree.", enemies:s.flags.warned ? [{n:"Kane (tower)",hp:70,boss:true},{n:"Hunter",hp:45},{n:"Hunter",hp:45},{n:"Hunter",hp:45}] : [{n:"Kane (tower)",hp:70,boss:true},{n:"Hunter",hp:45}], to:"p2e7_kane2", winMsg:"Kane falls back up the tower stairs."})},
p2e7_kane2:{ep:7, place:"The lookout stairwell", time:"Day 12, 15:10", lines:["~Close quarters on the switchback stairs. Two of Kane's men between you and the top."],
  combat:{id:"kane2", title:"Kane · the stairwell", startAlert:true, noStealth:true, intro:"Shotgun range.", enemies:[{n:"Bodyguard",hp:55},{n:"Bodyguard",hp:55}], to:"p2e7_kane3"}, fx:{heal:55}},
p2e7_kane3:{ep:7, place:"The lookout platform", time:"Day 12, 15:20", lines:[
  "~Wind. Kane grabs Preethi as she comes up through the hatch and holds her out over the rail. You have one grenade and one magazine left.",
  "KANE: Drop it, or she flies."],
  timer:{secs:6, to:"p2e7_kane_bad"},
  choices:[
    {t:"Throw the grenade off the far side of the platform", to:"p2e7_kane_end"},
    {t:"Drop your gun", to:"p2e7_kane_bad"},
    {t:"Shoot at Kane", to:"p2e7_kane_bad"}
  ]},
p2e7_kane_bad:{ep:7, place:"The lookout platform", time:"Day 12, 15:21", lines:["~Kane laughs and leans Preethi further out. Her boots scrape at nothing. No. Not like this.","~Think. The grenade."], next:"p2e7_kane3"},
p2e7_kane_end:{ep:7, place:"The lookout platform", time:"Day 12, 15:21", lines:[
  "~The grenade sails off the far side and bursts in the trees below. Kane's head snaps toward the blast. Preethi drives her elbow into his wounded shoulder and twists free. Kane staggers back against the rail, which gives way.",
  "~He hangs from the edge by one hand. You reach him.",
  "KANE: He'll give you the cure. (A thin laugh.) He wants you to watch him choose which one.",
  "~His grip fails. He falls into the trees."],
  fx:{grenades:{mani:-1}}, next:"p2e7_cliff"},
p2e7_cliff:{ep:7, radio:true, place:"Lookout platform", time:"Day 12, 16:30", lines:[
  "~From the top of the tower, everything is visible. The frozen private lake below. On its far shore, the Hades Mansion, every window lit gold, steam pouring from vents on its roofs. Behind it, the Smoke breathes a white column into the violet sky.",
  "~In a glass-walled courtyard, something large and striped paces.",
  "~Preethi loads her last shells. You count the grenades.",
  "~The radio clicks onto your private channel. A calm voice, warm and pleased.",
  "HADES (ON RADIO): Come in. Shoes off, please. I've made tea."],
  fx:{setHealth:12}, next:"p2e7_end"},
p2e7_end:{ep:7, place:"The Burn", time:"Day 12", lines:["~End of Episode 7."], epEnd:true}
});
