/* Part 1 · Episode 8 · Daybreak — and the five endings */
(function(){
const SIX = ["callers","medical","lab","dumping","ledger","footage"];
const six = s => SIX.filter(c => s.clues.includes(c)).length;
const LABEL = {callers:"The callers' map: what the town has been suffering", medical:"Dr. Rao's records: the illness, and four \"cardiac\" deaths that were fentanyl", lab:"The lab photos: where the fentanyl comes from", dumping:"The Old Merrow photos: where the waste goes", ledger:"Victor's ledger: who was paid", footage:"Nila's footage: Victor and Corbin, on camera, together"};
function endingFor(s){
  const f = s.flags;
  if(f.jamLost) return "silent";
  if(!f.protectTess && !f.eliBelieved) return "wrong";
  if(!(f.strongSignal && six(s) >= 4)) return "fog";
  if(f.protectTess && f.eliBelieved && f.forgaveWalter && s.trust.ortiz >= 2 && s.trust.rao >= 2 && six(s) === 6 && f.honest6) return "lamplight";
  return "daybreak";
}
const ortizComes = s => s.trust.ortiz >= 2 || s.flags.eliBelieved;

Object.assign(window.OTT_PARTS.p1.scenes, {
e8_open:{ep:8, card:true, place:"Outside the transmitter shed", time:"Sat 22:31", lines:[
  "~You grab Eli by the collar and slam him against the shed wall.",
  "MANI: Who was that?",
  "ELI: Ortiz! It was Ortiz! (He holds up the radio. The channel tag reads GPS-2, the deputy's private channel.) I told him to come to Pike Point with everyone he trusts.",
  "ELI: I said sorry because… because I'm the reason they knew where Nila slept. I've been saying sorry to everyone all week."],
  choices:[
    {t:"Believe him", sub:"Eli fights beside you.", to:"e8_who", fx:{flag:"eliBelieved", trust:{eli:2}}},
    {t:"Take the rifle away from him", sub:"Eli waits in the shed.", to:"e8_who", fx:{trust:{eli:-1}}}
  ]},
e8_who:{ep:8, place:"Outside the transmitter shed", time:"Sat 22:34", lines:s => [
  "~Nila looks down at the headlights on the lake road.",
  "NILA: Then who brought them?",
  s.flags.flareTripped ? "JONAH: (holding up a tin can on a string) Somebody tripped a flare on my trail this afternoon. And Victor has a man on that water tower who sees everything." : (s.flags.corbinKnowsPP ? "RUTH: Corbin's been asking about Pike Point for a week. He didn't need a map." : "JONAH: Victor has a man on that water tower who sees everything. He's been watching this headland for days.")],
  next:"e8_offer"},

e8_offer:{ep:8, place:"Pike Point trail, below the tower", time:"Sat 22:40", lines:[
  "~Victor walks up the trail alone, a flashlight in one hand, both hands visible, his coat immaculate even in the mud. Below him, four men with rifles spread into the trees. Corbin stays by the cars.",
  "VICTOR: Mani! I brought no snakes, I promise.",
  "VICTOR: Let's be practical. The mill's gone. Burned tonight, very sad, old wiring. There's no lab, no animals, no evidence. Just a camera, some photographs, and a very tired young woman.",
  "VICTOR: Two hundred thousand dollars. Enough to bring your parents over. Enough to never write another job application."],
  choices:[{t:"Refuse", to:"e8_offer2"},{t:"Take the money", to:"e8_fail", fx:{set:{failAt:"e8_offer"}}}]},
e8_offer2:{ep:8, place:"Pike Point trail", time:"Sat 22:42", lines:[
  "VICTOR: No? Then something you can't buy. Corbin's video of the Marsh girl at the till goes away forever. Eli's family keeps the dock. Everyone goes home."],
  choices:[{t:"Refuse", to:"e8_offer3"},{t:"Accept, for Tess", to:"e8_fail", fx:{set:{failAt:"e8_offer"}}}]},
e8_offer3:{ep:8, place:"Pike Point trail", time:"Sat 22:44", lines:[
  "~Victor's smile thins.",
  "VICTOR: I'm not the one you should be afraid of, Mani. My partner doesn't negotiate. If you broadcast, he'll come to Windsor himself. To your little apartment. To your parents' shop in Ranipet."],
  choices:[{t:"Refuse", to:"e8_refuse"},{t:"Back down", to:"e8_fail", fx:{set:{failAt:"e8_offer"}}}]},
e8_fail:{ep:8, place:"Pike Point", time:"—", lines:[
  "~You hear yourself say yes. Victor smiles, warm as a fireplace. Behind you, Nila makes a sound you will hear for the rest of your life.",
  "~By morning the transmitter is smashed, the camera is at the bottom of the lake, and Nila won't look at you.",
  "~No. Not like this. Try again."],
  choices:[{t:"Go back", to:s => s.vars.failAt || "e8_offer"}]},
e8_refuse:{ep:8, place:"Pike Point trail", time:"Sat 22:45", lines:[
  "MANI: You know what my father said to me when I left India? \"Look after her.\" That's the whole job, Victor. That's all I came here to do.",
  "~Victor's smile is gone.",
  "VICTOR: Then you'll do it in the dark.",
  "~He raises a hand. The floodlights on the trucks below snap on."],
  next:"e8_w1"},

e8_w1:{ep:8, place:"Pike Point · the siege", time:"Sat 22:47", lines:s => [
  "~You have the revolver: six rounds. Ruth has the shotgun. Jonah has a flare gun. " + (s.flags.eliBelieved ? "Eli has his father's rifle." : "Eli is locked in the shed with Nila.") + " Nila is inside warming up the transmitter for 23:00.",
  "~Wave one: two men moving up through the pines toward the tree line."],
  fx:{set:{rounds:6}},
  timer:{secs:7, to:"e8_w1b"},
  choices:[
    {t:"Let Ruth's shotgun pin them; hold your fire", to:"e8_w1a"},
    {t:"Empty the revolver into the trees", to:"e8_w1b"}
  ]},
e8_w1a:{ep:8, place:"Pike Point · the siege", time:"Sat 22:48", lines:s => [
  "~Ruth fires twice. Bark explodes beside the first man and both of them drop flat behind a log." + (s.flags.eliBelieved ? " Eli's rifle cracks from the shed roof and one of them crawls away clutching his leg." : ""),
  "~You fire once, carefully, when one of them raises his head. You miss. He stays down. Five rounds left."],
  fx:{add:{rounds:-1}}, next:"e8_w2"},
e8_w1b:{ep:8, place:"Pike Point · the siege", time:"Sat 22:48", lines:[
  "~You fire three times into the dark. Two shots hit trees. The third hits a man in the leg and he goes down screaming. A rifle round sparks off the shed doorframe beside your head.",
  "~Three rounds left. Your hands won't stop shaking."],
  fx:{add:{rounds:-3}, danger:1}, next:"e8_w2"},
e8_w2:{ep:8, place:"Pike Point · the siege", time:"Sat 22:53", lines:[
  "~Wave two: a man behind the shed with bolt cutters at the transmitter's power cable. At the same moment, a rifle round hits the doorframe and Jonah goes down, splinters in his arm."],
  timer:{secs:6, to:"e8_w2b"},
  choices:[
    {t:"Protect the cable", to:"e8_w2a"},
    {t:"Run to Jonah", to:"e8_w2b"}
  ]},
e8_w2a:{ep:8, place:"Pike Point · the siege", time:"Sat 22:54", lines:[
  "~You round the shed. The man has the bolt cutters on the cable. You shout. He turns, and you fire. He drops the cutters and runs into the trees, holding his shoulder.",
  "~Ruth is already kneeling beside Jonah, tying her scarf around his arm. He swears at her inventively. He'll live."],
  fx:{add:{rounds:-1}}, next:"e8_w3"},
e8_w2b:{ep:8, place:"Pike Point · the siege", time:"Sat 22:54", lines:[
  "~You drag Jonah behind the doorframe. Behind the shed, a heavy clunk. The lights inside flicker. Nila shouts.",
  "~You get there in time to see the man running, the cable half cut. Nila splices it with tape and swearing. It holds. Barely."],
  fx:{danger:1, add:{rounds:-1}}, next:"e8_w3"},
e8_w3:{ep:8, place:"Pike Point · the tower", time:"Sat 22:57", lines:[
  "~Wave three: a man is climbing the tower ladder to cut the antenna feed. You go up after him.",
  "~On the first platform, wind howling, he swings a wrench at your head."],
  timer:{secs:5, to:"e8_w3b"},
  choices:[{t:"Duck and drive your shoulder into him", to:"e8_w3a"},{t:"Raise the revolver", to:"e8_w3b"}]},
e8_w3a:{ep:8, place:"Pike Point · the tower", time:"Sat 22:58", lines:["~The wrench whistles over your head. You hit him low. He goes over the rail and crashes into the bushes below, groaning. Alive."], next:"e8_ortiz"},
e8_w3b:{ep:8, place:"Pike Point · the tower", time:"Sat 22:58", lines:["~The wrench catches your forearm and the revolver nearly goes over the edge. You hold on to it. You hit him with your whole body and he goes over the rail into the bushes below. Your arm screams."], fx:{danger:1}, next:"e8_ortiz"},
e8_ortiz:{ep:8, place:"Pike Point", time:"Sat 22:59", lines:s => ortizComes(s) ? [
  "~Then, sirens. Not provincial police yet. One cruiser, lights flashing, tearing up the lake road. Ortiz.",
  "~He pulls in behind Corbin's car, sidearm drawn.",
  "ORTIZ (MEGAPHONE): Sheriff Corbin. Hands on the hood. Please don't make me say it twice.",
  "~Corbin, stunned, puts his hands on the hood. Victor's remaining men hesitate, then run for the trees.",
  "~You check the revolver. One round left. Somehow, it's always going to be one."] : [
  "~No sirens come. Corbin stays by the cars, smoking, waiting. Victor's men pull back into the trees to regroup.",
  "~Ruth reloads with steady hands. \"They'll come again,\" she says. \"Do your thing, girl. Fast.\"",
  "~You check the revolver. One round left."],
  fx:s => ortizComes(s) ? {flag:"ortizCame", set:{rounds:1}} : {set:{rounds:1}}, next:"e8_air"},

e8_air:{ep:8, radio:true, place:"Transmitter shed", time:"Sat 23:00", lines:s => [
  "~The signal meter glows green" + (s.flags.strongSignal ? "." : ", but only just. Jonah's spare cable is short and the needle trembles.") + " Nila pulls on her headphones. Her hands are steady now.",
  "NILA (ON AIR): Good evening, Greyhaven. This is After Hours on 94.1. I'm Nila. I'm back. (beat) And tonight I'm going to tell you everything.",
  six(s) >= 2 ? "~She looks at you. You have to hand her the proof in an order a listener, and a police officer, can follow." : "~You don't have much. She tells them what she can."],
  puzzle:s => {
    const have = SIX.filter(c => s.clues.includes(c));
    if(have.length < 2) return {type:"pick", title:"The broadcast", prompt:"You have almost nothing to hand her. She'll have to talk from memory.", to:"e8_jam", options:[{t:"\"Tell them anyway.\"", correct:true}]};
    return {type:"order", title:"The broadcast", prompt:"Put the proof in order: from what the town suffered, to the cause, to who did it.", items:have.map(c => LABEL[c]), to:"e8_jam", hints:["Start with the people: the callers, then the medical records.","Then the cause (lab, dumping). The ledger and the footage name names, so they come last."], giveUp:3, answerText:"Suffering, cause, names."};
  }},
e8_jam:{ep:8, radio:true, place:"Transmitter shed", time:"Sat 23:14", lines:[
  "~Halfway through the ledger, the signal meter crashes to red. Nila's headphones fill with her own voice, slowed down, a few seconds behind, distorted.",
  "JAMMING VOICE (ON AIR): …If anyone's on seven-one-eight-five… I found it… aana andha— || …If anyone's on seven-one-eight-five… I found it… but don't trust the—",
  "~Her private voicemail to you. Only someone tapping her phone could have that.",
  "JONAH: (clutching his bleeding arm, squinting at a scope) Somebody's flooding 94.1 from the north. The water tower. Big transmitter. That's not Victor's gear.",
  "JONAH: Ruth. Your notebooks. Fourteen years of scanner channels. Find me one the provincial police listen to overnight, that he isn't covering."],
  puzzle:{type:"tune", title:"Beat the jamming", prompt:"Ruth reads from her 2019 notebook: \"OPP overnight dispatch, northern relay: one-five-five point four-six.\" Tune the transmitter to it.", min:150, max:160, step:0.01, startAt:150, target:155.46, tol:0.04, decimals:2, unit:"MHz", hints:["Ruth's note: 155.46 MHz.","Slide slowly near 155.5 and watch the meter."], giveUp:4, giveUpLabel:"We can't find it", answerText:"The jamming wins. The broadcast dies.", giveUpFx:{flag:"jamLost"}, to:"e8_jam_after"}},
e8_jam_after:{ep:8, radio:true, place:"Transmitter shed", time:"Sat 23:30", lines:s => s.flags.jamLost ? [
  "~The meter stays red. The jamming voice goes on and on, Nila's own words looping back at her like a taunt. She pulls the headphones off and puts her face in her hands.",
  "NILA: Nobody heard it, Anna. Nobody heard any of it."] : [
  "~The meter climbs back to green on the new channel. Nila finishes it all: the ledger, the footage, her own whisper from the bottom of the lake. She ends it the way she ended every show.",
  "NILA (ON AIR): This was After Hours. Lock your doors, Greyhaven. And thank you for listening."],
  next:s => (!s.flags.protectTess && !s.flags.eliBelieved && !s.flags.jamLost) ? "e8_wrong" : "e8_platform"},

e8_platform:{ep:8, place:"Tower platform, thirty metres up", time:"Sat 23:40", lines:[
  "~Nila steps outside for air. A hand clamps over her mouth. Victor, mud on his coat now, a pistol in his hand, drags her up the tower ladder to the first platform.",
  "VICTOR: MANI!",
  "~You climb. On the platform, wind howling, Victor holds Nila at the rail with the pistol to her head. You raise the revolver. One round. Your hands shake.",
  "VICTOR: One bullet. I counted. (He laughs, breathing hard.) You're not a killer, Mani. You're a nice boy with a spreadsheet.",
  "MANI: Let her go. It's over.",
  "VICTOR: Over? You think I'm the top? I'm middle management. You think he'll let me sit in a courtroom?",
  "~He looks north, toward the water tower, and for the first time, he looks afraid.",
  "VICTOR: He's listening right now. He's always listening. His name is—",
  "~A single rifle crack across the water from the north.",
  "~Victor jerks. He looks down at his chest, surprised. The pistol slips from his fingers.",
  "VICTOR: …Hades doesn't… leave…",
  "~He falls. Thirty metres into the dark pines.",
  "~Nila crumples into your arms. You're still holding the revolver. You never fired. On the water tower across the lake, a tiny red light blinks twice and goes dark."],
  next:s => "e8_route"},
e8_wrong:{ep:8, place:"Foot of the tower", time:"Sat 23:35", lines:[
  "~Headlights at the foot of the trail. Corbin's cruiser. In the back seat, a pale face against the glass. Tess.",
  "~Victor's voice on the radio, very calm.",
  "VICTOR (ON RADIO): The Marsh girl for the little USB stick in your pocket, Mani. The encrypted one. Bring it down. Alone.",
  "~You never promised to protect her. Nobody was watching her. You walk down the trail with the USB in your hand.",
  "~At the bottom, Victor holds Tess by the arm. You hold out the stick. He takes it. He lets her go. She runs to you.",
  "VICTOR: Pleasure doing business—",
  "~A rifle crack from the north. Victor drops where he stands. The USB stick skitters into the dark and is gone. On the water tower, a red light blinks twice."],
  fx:{flag:"lostFile"}, next:"e8_route"},
e8_route:{ep:8, place:"Pike Point", time:"Sat 23:45", lines:["~The night goes very quiet."],
  next:s => ({daybreak:"e8_dawn", lamplight:"e8_dawn", fog:"e8_fog", wrong:"e8_wrong2", silent:"e8_silent"})[endingFor(s)]},

/* ---- Daybreak / Lamplight ---- */
e8_dawn:{ep:8, place:"Greyhaven", time:"Sun 05:00", lines:s => [
  "~Dawn comes up grey and gold. Provincial police cruisers block the mill road. A helicopter circles the lake. The mill is a smoking shell, but the pill presses were steel and survived the fire.",
  s.flags.ortizCame ? "~Corbin is led out of his own station in handcuffs. Ortiz holds the door." : "~Corbin is arrested at the county line at six in the morning, still in uniform, a suitcase of cash on the back seat.",
  s.flags.gusInformant ? "~Gus walks into the police command post in his apron and says, \"I drove the truck. And I'll tell you everything.\"" : "~Gus is arrested at the diner. He doesn't resist.",
  "~Brian Holt is quietly escorted out of the radio station.",
  "~In the trunk of Victor's car, officers find a heated travel case holding Midas and the last five golden lanceheads. A wildlife officer from Toronto says they will be sent home to Brazil.",
  "~Victor's body is recovered from the pines. One rifle round, fired from more than six hundred metres, from the direction of the water tower. The tower is empty. One spent casing on the platform. Nothing else.",
  "~On Victor's phone, the last incoming call: a blocked number, at 23:39. One minute before the shot."],
  next:"e8_bye"},
e8_bye:{ep:8, place:"Greyhaven, daylight", time:"Sun 09:00", lines:["~For the first time, you walk through Greyhaven in daylight. Say goodbye."],
  puzzle:{type:"search", title:"Goodbyes", prompt:"Say goodbye to the people who helped you.", need:4, doneLabel:"Get in the car", to:"e8_drive", spots:[
    {t:"Ruth, on the motel porch", text:"She's already sweeping up the glass. \"Fourteen years of notebooks. Somebody finally read them.\" She hugs Nila hard, then you, briefly, like it embarrasses her."},
    {t:"Dr. Rao, outside the clinic", text: s => s.trust.rao >= 2 ? "\"I'm testifying. All four of them. I'm putting their real names on the record.\"" : "She nods at you from the doorway. Later you'll read that she gave a statement. A short one."},
    {t:"Ortiz, at the station", text: s => s.flags.ortizCame ? "He's wearing a sheriff's jacket two sizes too big. \"Acting sheriff. Until they find somebody qualified.\"" : "\"I should have come up that hill,\" he says. \"I'll be better.\" He means it."},
    {t:"Walter and Eli, on the burned dock", text: s => s.flags.forgaveWalter ? "Walter: \"We'll build another boat. Call it Nila.\" Eli, beside him, can't speak. He just holds out his hand, and you take it." : "Walter won't look at you. Eli walks you to the road. \"He'll come round,\" he says. \"Maybe.\""},
    {t:"Tess, at the bus stop", text: s => s.flags.protectTess ? "A backpack and a bus ticket to Toronto, paid for by Ruth. \"You kept your promise,\" she says. \"Now I'm finally waiting for the right bus.\"" : "She's at the bus stop with a backpack. She waves, once."},
    {t:"Jonah, in his cabin", text:"Arm in a sling, a radio in his lap. \"Whoever was on that water tower, he's still out there. Keep your radio on, Anna.\""},
    {t:"Father Reid, at St. Brendan's", text:"He rings the bell one last time, nine o'clock, and lets the rope go. \"I think they can rest now.\""}
  ]}},
e8_drive:{ep:8, place:"County roads, southbound", time:"Sun 10:00", lines:s => [
  "~Nila's blue hatchback, you driving, windows down despite the cold. Nila has her feet on the dashboard and the new radio in her lap. You argue about music. You laugh until your stomach hurts.",
  "~Your phone buzzes. An email.",
  s.flags.interviewGood ? "~\"We'd love to offer you the Data Analytics Engineer position. Your answer about the 46 reports stuck with the whole panel.\" Nila reads it over your shoulder and screams \"ANNA!\" loud enough to scare a cow." : "~\"Thank you for your time. We'd like to invite you to a third interview next week.\" Nila punches your arm. \"Third time's lucky. You'll get it.\"",
  "~You stop at the first Tom Portons on County Road 20. Harold and June are at the window table. Harold has a double-double. June pretends not to see.",
  "~Back on the road, it goes quiet. Nila watches the fields.",
  "NILA: En voicemail. \"Aana andha—\" Naan solla vandhadhu, badhil sollura andha kurala nambaadhannu. || My voicemail. \"But don't trust the—\" I was going to say, don't trust the voice that answers.",
  "NILA: Naan broadcast panna ovvoru raathiriyum avan badhil sonnaan. Victor avan illa, Anna. Victor-ukke avana paathu bayam. || Every night I broadcast, he answered. Victor wasn't him, Anna. Victor himself was scared of him.",
  "MANI: Ellam mudinjiduchu, Nila. || It's all over, Nila.",
  "~Nila doesn't answer. She turns the radio off."],
  next:"e8_hades"},
e8_hades:{ep:8, place:"Greyhaven water tower", time:"Sun 10:00", lines:[
  "~The camera rises from the county road, back over the hill, to the old water tower above Greyhaven. On the platform stands a figure in a long dark coat, only a silhouette against the morning sun. A rifle case at his feet. A handheld radio in his gloved hand.",
  "~He watches a small blue car crest the hill and disappear south.",
  "HADES (ON RADIO): Victor talked too much. It's handled. (beat) The siblings? (He watches the empty road.) No. Let them go home. Let them light their lamps.",
  "~He lowers the radio.",
  "HADES: I know where home is."],
  next:s => endingFor(s) === "lamplight" ? "e8_lamp" : "end_daybreak"},
e8_lamp:{ep:8, place:"Jonah's cabin, Pike Point", time:"Sun 14:00", lines:[
  "~That afternoon, alone in his cabin, Jonah plugs in a copy of the encrypted file Mani left him. \"Hades_contacts.enc.\" He's been running it through an old decryption rig since dawn.",
  "~One word in the file's header decodes. Just one. He reads it twice, then picks up his radio.",
  "JONAH (ON RADIO): Anna. It's Jonah. Got one word out of that file. (beat) R-E-D-L-A-K-E.",
  "~He doesn't know yet what it means. Neither do you."],
  next:"end_lamplight"},
end_daybreak:{ep:8, ending:"daybreak", nextPart:"p2", place:"Windsor", time:"Diwali night", lines:s => [
  "~Your small apartment in Windsor glows with clay diyas on every surface. The slightly water-damaged laddus on a steel plate. The laptop open on a video call to Vellore: Amma, Appa, oil lamps behind them, fireworks crackling in their street.",
  s.flags.honest6 ? "~Amma weeps openly and keeps touching the screen where Nila's face is. Appa says nothing for a long time. Then: \"Nee ava-va paathukitta.\" (You looked after her.)" : "~Nila tells them everything herself, gently. Amma scolds you for hiding it, then thanks you, then scolds you again.",
  s.flags.interviewGood ? "NILA: Amma, Anna-ku job kedachiduchu! || Amma, Anna got the job!" : "NILA: Amma, Anna-ku third interview! Adhu kooda kedaichudum. || Amma, Anna has a third interview! He'll get it too.",
  "~Later. The call has ended. Nila is asleep on the couch under a blanket. You stand on the balcony, the Detroit skyline across the river, fireworks over both cities.",
  "~Inside, on the shelf, Nila's old handheld radio, the one she carried all week, switched off. Its display flickers on by itself. One second of static. Then silence.",
  "~Nobody sees it.",
  "~OUT OF TOWN WILL RETURN."]},
end_lamplight:{ep:8, ending:"lamplight", nextPart:"p2", kicker:"Hidden ending · Out of Town: Greyhaven", place:"Windsor", time:"Diwali night", lines:[
  "~Diwali night. Clay diyas on every surface. Amma and Appa on the video call from Vellore, crying and laughing at once.",
  "~Appa: \"Nee ava-va paathukitta.\" (You looked after her.)",
  "~Everyone you met in Greyhaven is safe. Every proof was heard. You told your parents the truth when it was hardest.",
  "~Later, on the balcony, you write one word on the back of your hand so you won't forget it: REDLAKE.",
  "~Inside, Nila's old radio flickers to static for one second. Nobody sees it.",
  "~OUT OF TOWN WILL RETURN."]},

/* ---- Out of the Fog ---- */
e8_fog:{ep:8, place:"Pike Point", time:"Sun 00:10", lines:s => [
  "~Somebody heard. Not enough people. Not fast enough. The signal was too weak, the proof too thin. No police come up the lake road.",
  "~Victor's men regroup in the trees. Corbin is shouting into his radio.",
  "RUTH: Down to the water. Now.",
  "~Ruth's skiff is pulled up in the reeds below the point. You, Nila, Ruth and Jonah slide down the wet slope and push off into the black water, engine off, oars only. Behind you, flashlights sweep the empty shed.",
  "~By sunrise you are on the highway in Nila's blue hatchback, Greyhaven a grey smudge in the mirror."],
  next:"e8_fog2"},
e8_fog2:{ep:8, place:"County roads, southbound", time:"Sun 07:00", lines:[
  "~Weeks later, a Toronto paper runs Nila's footage. Corbin is arrested at his kitchen table. Gus confesses. The mill is sealed.",
  "~But it took weeks. And for weeks, every time it rained, Nila checked the news for Greyhaven.",
  "NILA: Victor wasn't him, Anna. Victor was scared of him.",
  "~On the water tower above Greyhaven, a silhouette in a long coat watched your car go. \"I know where home is,\" he said, to nobody."],
  next:"end_fog"},
end_fog:{ep:8, ending:"fog", nextPart:"p2", place:"Windsor", time:"Diwali night", lines:[
  "~Diwali in Windsor. Lamps lit, a little late. Amma and Appa on the screen. Nila thinner, quieter, alive.",
  "~You tell yourself that's what matters. Nila is alive.",
  "~On the shelf, her old radio clicks to static for one second. Nobody sees it.",
  "~OUT OF TOWN WILL RETURN."]},

/* ---- Wrong Hands ---- */
e8_wrong2:{ep:8, place:"Pike Point", time:"Sun 00:00", lines:[
  "~Tess shakes in your arms. Down the trail, Corbin is already in his cruiser, reversing hard. He's gone before anyone can stop him.",
  "~The broadcast went out. Police come at dawn. Corbin is caught two days later in Sault Ste. Marie.",
  "~But the encrypted file is gone, picked up from the dark by someone you never saw.",
  "TESS: Why didn't you watch out for me? (beat) Never mind. You came.",
  "~On the water tower, a silhouette in a long coat turns a small USB stick over in his gloved fingers. \"I know where home is,\" he says."],
  next:"end_wrong"},
end_wrong:{ep:8, ending:"wrong", nextPart:"p2", place:"Windsor", time:"Diwali night", lines:[
  "~Diwali in Windsor. Nila beside you, alive. Amma and Appa on the screen.",
  "~You keep thinking about the stick sliding into the dark. About what was on it. About whose hand picked it up.",
  "~Nila's old radio flickers to static. Nobody sees it.",
  "~OUT OF TOWN WILL RETURN."]},

/* ---- Silent Water ---- */
e8_silent:{ep:8, place:"Pike Point", time:"Sun 00:00", lines:[
  "~Nobody heard. The jamming swallowed every word. No police come.",
  "~Ruth gets you to the water. You row in the dark with the proof in a dry bag between your knees: the camera, the ledger, the photos.",
  "~Three days later, in a café in Toronto, Nila hands everything to a journalist called Ivy Laurent, the one she emailed from Greyhaven months ago. Ivy goes pale reading the ledger.",
  "IVY: I know this company. I used to work for one of its suppliers. (beat) Leave it with me.",
  "~Greyhaven never says a word. Corbin keeps his badge for another month. Then a newspaper story runs, and he doesn't.",
  "~On the water tower, a silhouette in a long coat says, \"I know where home is.\""],
  next:"end_silent"},
end_silent:{ep:8, ending:"silent", nextPart:"p2", place:"Windsor", time:"Diwali night", lines:[
  "~Diwali in Windsor. The lamps are lit. Nila sits close to you on the couch and doesn't say much.",
  "~The town you saved never thanked you. Maybe it never will.",
  "~Nila's old radio flickers to static for one second. Nobody sees it.",
  "~OUT OF TOWN WILL RETURN."]}
});
})();
