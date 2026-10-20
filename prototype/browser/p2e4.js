/* Part 2 · Episode 4 · The Ice Road */
Object.assign(window.OTT_PARTS.p2.scenes, {
p2e4_open:{ep:4, card:true, radio:true, place:"Room 7", time:"Day 7, 04:10", lines:[
  "~You and Preethi sit on the floor by the radio, coats still on. You've packed the car to drive back to Windsor. Static for six hours.",
  "~Then a click.",
  "NILA (ON RADIO, A WHISPER): …Anna. Anni. Naan inga dhaan irukken. || I'm still here. (beat) They gave me oxygen. Ortiz yelled at a doctor. It was very funny.",
  "~Preethi puts her face in her hands and cries.",
  "NILA (ON RADIO): Unpack the car. (beat) Find the man who dug Level 9."],
  fx:{setHealth:40}, next:"p2e4_bar"},
p2e4_bar:{ep:4, place:"Bar and general store, Cochenour", time:"Day 7, 15:00", lines:[
  "~A low wooden bar with a store at the back. Trophy fish on the walls. Miners on shift break, steam rising off their jackets."],
  puzzle:{type:"search", title:"Asking around", prompt:"Ask the locals about the Hayden Deep.", need:3, doneLabel:"Buy a bottle of rye", to:"p2e4_ice", spots:[
    {t:"A young driller", text:"\"Nobody at Northstar talks. They fly crews in from Winnipeg. Two weeks on, two off. They don't drink here.\""},
    {t:"The bartender", text:"\"Old-timers say there's levels down there that never got mapped. Ghost stories, probably.\""},
    {t:"A woman buying ammunition", text:"\"Ask Sully. He's on McKenzie Island. He'll talk your ear off if you bring rye.\""},
    {t:"A man at the end of the bar who won't look at you", text:"You ask him about Northstar. He finishes his beer in one swallow and leaves fast. Through the window, you see him make a phone call.", fx:{danger:1}}
  ]}},
p2e4_ice:{ep:4, place:"Ice road to McKenzie Island", time:"Day 7, 19:00", lines:[
  "~The summer ferry is gone. A ploughed road of ice crosses the dark lake, marked by small evergreen trees stuck in the snow. Thin near the shore, where the current runs.",
  "~Halfway across: headlights behind you. Three snowmobiles, fast."],
  timer:{secs:6, to:"p2e4_ice2"},
  choices:[
    {t:"Stay on the marked road", sub:"Safer. Slower.", to:"p2e4_ice2"},
    {t:"Cut across the open ice", sub:"Faster. The ice booms.", to:"p2e4_ice2", fx:{flag:"blackIce", toast:"The ice booms and cracks under the tyres."}}
  ]},
p2e4_ice2:{ep:4, place:"Ice road", time:"Day 7, 19:02", lines:s => [
  s.flags.blackIce ? "~You gain fifty metres. A crack races beside you like a living thing." : "~The snowmobiles close in on both sides.",
  "~Preethi rolls down her window. Wind and snow pour in. She braces the shotgun on the door."],
  combat:{id:"iceroad", title:"Ice road chase", solo:"preethi", startAlert:true, intro:"Preethi leans out of the window. Two riders close in.", note:"Only Preethi can shoot from the car.", enemies:[{n:"Lead rider",hp:45},{n:"Second rider",hp:45}], to:"p2e4_ice3", winMsg:"The lead machine spins out. The second rider brakes hard and turns back."}},
p2e4_ice3:{ep:4, place:"Ice road, island shore", time:"Day 7, 19:05", lines:["~The third snowmobile is still on you as the island shore rushes up."],
  timer:{secs:5, to:"p2e4_ice_end"},
  choices:[{t:"Brake hard at the shore", to:"p2e4_ice_end", fx:{flag:"overshoot"}},{t:"Keep your speed", to:"p2e4_ice_end"}]},
p2e4_ice_end:{ep:4, place:"McKenzie Island", time:"Day 7, 19:06", lines:s => s.flags.overshoot ? [
  "~You stand on the brakes. The last snowmobile overshoots you onto thin ice by the shore. A sound like a gunshot. The ice opens. The machine goes through.",
  "~Its rider claws his way out onto solid ice, soaked, and runs."] : [
  "~You hit the shore road at speed and fishtail into a snowbank. The snowmobile roars past and away into the dark."],
  next:"p2e4_sully"},
p2e4_sully:{ep:4, place:"Sully's cabin, McKenzie Island", time:"Day 7, 20:00", lines:[
  "~A cabin crammed with mining junk, a wood stove, and a black cat named Nugget. \"Sully\" O'Rourke, seventy-eight, takes the rye before he takes your names.",
  "SULLY: Hayden Deep. (He pours.) I dug Level Nine in seventy-four. Old Robert Hayden wanted a level nobody would ever see on a map. Said it was for \"cold storage\". I've dug gold for fifty years; you don't keep anything cold that far down. You keep it secret."],
  fx:{flag:"met_sully", trust:{sully:1}}, next:"p2e4_stories"},
p2e4_stories:{ep:4, place:"Sully's cabin", time:"Day 7, 20:15", lines:s => [
  ["s1","s2","s3"].filter(k => s.flags["once_" + k]).length >= 2 ? "~Sully gets up and goes to an old calendar on the wall." : "~Sully refills his glass. \"Ask me something.\""],
  choices:[
    {t:"\"Tell me about the dig.\"", to:"p2e4_s1", once:"s1"},
    {t:"\"Did the miners get sick?\"", to:"p2e4_s2", once:"s2"},
    {t:"\"What was Mark like as a boy?\"", to:"p2e4_s3", once:"s3"},
    {t:"Watch what he's doing", to:"p2e4_map", show:s => ["s1","s2","s3"].filter(k => s.flags["once_" + k]).length >= 2}
  ]},
p2e4_s1:{ep:4, place:"Sully's cabin", time:"Day 7, 20:20", lines:["SULLY: Six of us. Nine months. Paid triple and told to forget it. We cut a vent raise up to the bush by Madsen so we could breathe down there. Nobody ever filled it in. I'd bet my cat on it."], next:"p2e4_stories"},
p2e4_s2:{ep:4, place:"Sully's cabin", time:"Day 7, 20:25", lines:["SULLY: In the eighties. Three of the six of us. Lungs. Same as everybody else on that road. Company paid for the funerals. Very generous. Very quiet."], next:"p2e4_stories"},
p2e4_s3:{ep:4, place:"Sully's cabin", time:"Day 7, 20:30", lines:["SULLY: Cold little thing. Used to catch garter snakes and keep them in jars on his windowsill. Watched them. Just watched them, for hours. Never let them go."], next:"p2e4_stories"},
p2e4_map:{ep:4, place:"Sully's cabin", time:"Day 7, 20:40", lines:[
  "~Sully turns over a calendar from 1974. On the back, in pencil: a hand-drawn map. Levels 6 to 9, the shafts, and a ventilation raise that comes up in the bush near Madsen.",
  "SULLY: Only map there is. Take it. (beat) And son. The old man never died, you know. They say he lives out there with the boy."],
  fx:{clue:"sullyMap", trust:{sully:1}}, next:"p2e4_mapp"},
p2e4_mapp:{ep:4, place:"Sully's cabin", time:"Day 7, 20:50", lines:["~You lay Sully's map over Ivy's surface sketch and the \"Level 9\" clue."],
  puzzle:{type:"pick", title:"The way in", prompt:"Ivy's map shows a guarded freight elevator. Sully's map shows the 1974 vent raise. Which way in is never on any modern plan?", to:"p2e4_back", options:[
    {t:"The freight elevator", why:"It's on Ivy's map, and it's guarded."},
    {t:"The main shaft", why:"Cameras and a gatehouse."},
    {t:"The 1974 ventilation raise near Madsen", correct:true},
    {t:"The loading dock", why:"That gets you in at the surface, not to Level 9."}
  ]}},
p2e4_back:{ep:4, place:"Ice road, return", time:"Day 7, 22:00", lines:[
  "NILA (ON RADIO): A side door nobody remembers. Every case has one. Good work, Anna.",
  "~You cross back on the marked road, slowly. Where the snowmobile went through, the ice is already freezing over. Preethi is silent.",
  "PREETHI: That man could have drowned.",
  "MANI: He was shooting at us.",
  "PREETHI: I know. (beat) I still want to remember that he could have drowned."],
  next:"p2e4_cliff"},
p2e4_cliff:{ep:4, radio:true, place:"Northern Star Motel office", time:"Day 7, 22:30", lines:[
  "~The office door is open. Bev is duct-taped to her desk chair, a bruise on her cheek, furious.",
  "BEV: (as Preethi cuts the tape) Three of them. One with a scar. They wanted the Toronto girl.",
  "MANI: Ivy's in Dryden—",
  "BEV: She came back tonight. Two hours ago. Room four.",
  "~Room four: the door kicked in, the bed overturned, Ivy's laptop smashed. A drop of blood on the snow outside. Drag marks to where a vehicle waited.",
  "~Your radio clicks onto your channel.",
  "KANE (ON RADIO): The journalist talks a lot when she's cold. (beat) Thursday, Mani. Bring the file. You can have whatever's left of her."],
  fx:{danger:1, trust:{bev:1}}, next:"p2e4_end"},
p2e4_end:{ep:4, place:"Red Lake", time:"Day 7", lines:["~End of Episode 4."], epEnd:true}
});
