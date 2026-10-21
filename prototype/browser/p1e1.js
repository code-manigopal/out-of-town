/* Part 1 · Episode 1 · County Roads */
Object.assign(window.OTT_PARTS.p1.scenes, {
e1_open:{ep:1, card:true, radio:true, place:"Black screen", time:"Sunday 23:52", lines:[
  "~Radio static. A phone voicemail, timestamped Sunday, 23:52.",
  "NILA (V.O.): Anna, naan dhaan. Station-ku call pannadha, okay? Plan panna maadhiri Tuesday vandhudu. || Anna, it's me. Don't call the station, okay? Just come Tuesday like we planned.",
  "NILA (V.O.): Naan oru vishayam kandupidichiruken. Phone-la solla mudiyaadhu. Inga vandhappo edhavadhu weird-aa irundha, Ruth kitta mattum pesu. || I found something. I can't say it on the phone. If anything feels weird when you get here, talk only to Ruth.",
  "NILA (V.O.): Anna, yaara venaalum nambu, aana andha— || Anna, trust anyone, but don't trust the—",
  "~The message cuts. Silence."],
  fx:{clue:"voicemail"}, next:"e1_apt"},

e1_apt:{ep:1, place:"Mani's apartment, Windsor", time:"Tue 09:05", lines:[
  "~A small one-bedroom near the river. A whiteboard of job applications, half of them crossed out. A graduation photo from the University of Windsor. On the counter: a box of laddu and mysore pak, a packet of clay diyas, and a gift-wrapped ham radio with a crooked bow.",
  "~You play the voicemail again. You call Nila. Straight to voicemail. Again.",
  "~Before you leave, you look around the flat one more time."],
  puzzle:{type:"search", title:"Pack for Greyhaven", prompt:"Look around. Pack what you need.", need:3, doneLabel:"Zip the duffel", to:"e1_call", spots:[
    {t:"The sweets box", text:"Laddu and mysore pak from the Indian sweet shop on Tecumseh Road. Nila's favourite is the mysore pak. She'll pretend she's on a diet and eat four."},
    {t:"The clay diyas", text:"Twelve little oil lamps. Amma made you promise to light them with Nila on Diwali night, \"even if it's only the two of you\"."},
    {t:"The gift radio", text:"A new handheld ham radio. Nila's old one is held together with tape. You spent more than you should have. You don't care."},
    {t:"The whiteboard", text:"\"Data Analytics Engineer — 2nd round Thurs.\" Six years leading a team at Auragle, a master's degree, and still you check your email every morning with your stomach tight."},
    {t:"Photo of Nila", text:"Nila at her first broadcast in Greyhaven, headphones crooked, grinning. She studied criminology for four years, then chose radio. Appa didn't speak to her for a week. Then he listened to every show."}
  ]}},

e1_thought_pack1:{ep:1, place:"Mani's apartment, Windsor", time:"Tue 09:12", lines:[
  "MANI (THOUGHT): Nila enna solla vandhaa? Oru vela edhavadhu prachanaiya? || What was Nila trying to tell me? Is something wrong?"],
  next:"e1_apt"},

e1_call:{ep:1, place:"Mani's apartment, Windsor", time:"Tue 09:30", lines:[
  "~Your laptop rings. A video call from Vellore. Amma and Appa, 7 pm their time, Appa still in his shop shirt from Sri Valli Leathers.",
  "AMMA: Kanna, saaptiya? Moonji ellam ilachu pochu. || Kanna, did you eat? Your face has gone so thin.",
  "MANI: Saapten, Amma. || I ate, Amma.",
  "APPA: Company-la irundhu edhavadhu news? Andha Thursday interview? || Any news from the company? That Thursday interview?",
  "MANI: Second round, Appa. Thursday dhaan. || Second round, Appa. On Thursday.",
  "AMMA: Nila enga? Moonu naala phone edukkala. En mela kovama irukkaala? || And Nila? Three days she hasn't picked up. Is she angry with me?"],
  choices:[
    {t:"\"Avalukku work busy, Amma.\"", sub:"She's busy with work, Amma. (Reassure them.)", to:"e1_call2", fx:{set:{call1:"reassure"}}},
    {t:"\"Inniki avala paakka poren, ippo dhaan kilambaren.\"", sub:"I'm going to see her today, I'm leaving now. (A half-truth.)", to:"e1_call2", fx:{flag:"honest1", set:{call1:"half"}}}
  ]},
e1_call2:{ep:1, place:"Mani's apartment, Windsor", time:"Tue 09:34", lines:[
  "APPA: Sweets eduthutu po. Kadai nalla poguthu, kavala padaadhenu Appa sonnaarnu sollu. Pongal-ku veetuku vara sollu. || Take her the sweets. Tell her Appa says the shop is doing fine, she should stop worrying. Tell her to come home for Pongal.",
  "AMMA: Innoru vishayam, Kanna. Preethi-nu oru ponnu, Windsor-la dhaan irukkaa. Pharmacist. Photo anupparen, paaru. || One more thing, Kanna. There's a girl called Preethi, she lives in Windsor too. A pharmacist. I'm sending her photo, have a look.",
  "MANI: Amma! Ippo venaam! || Amma! Not now!",
  "~Amma laughs. Appa shakes his head. The call ends. Your phone buzzes: a photo from Amma. You don't open it. You pick up the gift radio and look at it for a long moment."],
  next:"e1_road"},

e1_road:{ep:1, place:"County Road 20, Essex County", time:"Tue 10:10", lines:[
  "~You head east along Lake Erie. Greenhouses glitter outside Leamington. Flat farmland, grain silos, a hawk on a fence post. The radio plays a country station you'd never admit to liking.",
  "~At a red light you text Nila's flatmate, a name she's mentioned a hundred times.",
  "MANI (TEXT): Hi Tess, it's Mani, Nila's brother. Is she around? Coming up today.",
  "~No reply. The light goes green. Your stomach says coffee."],
  next:"e1_tp1"},

e1_tp1:{ep:1, place:"Tom Portons, County Road 20", time:"Tue 10:55", lines:[
  "~A busy coffee-and-donut shop. Red-and-cream decor, a hockey rerun on the TV, the smell of burnt sugar. You order a coffee and an apple fritter.",
  "~At the counter, an old man in a flat cap slaps a receipt down.",
  "HAROLD: Third day running! I order a double-double and somebody gives me decaf! I've been coming here since 1974!",
  "~The young cashier, Priya, looks helpless. Your coffee is still brewing. You have nothing better to do."],
  choices:[{t:"Help sort it out", to:"e1_tp1p"},{t:"Stay out of it", to:"e1_tp1skip"}]},
e1_tp1skip:{ep:1, place:"Tom Portons, County Road 20", time:"Tue 10:58", lines:[
  "~You try. You really do. But Harold is now shouting at the menu board, and Priya looks like she might cry, and you are a person who cannot leave a broken thing alone.",
  "MANI: Can I see the receipts?"], next:"e1_tp1p"},
e1_tp1p:{ep:1, place:"Tom Portons, County Road 20", time:"Tue 11:00", lines:[
  "~Small mystery: The Decaf Problem."],
  puzzle:{type:"search", title:"The Decaf Problem", prompt:"Examine everything. Then decide who's behind it.", need:4, doneLabel:"I know who did it", to:"e1_tp1acc", spots:[
    {t:"Harold's three receipts", text:"Each order was rung up correctly: medium double-double, regular. Not decaf."},
    {t:"The drive-thru screen behind the counter", text:"Every morning at 9:28, two minutes before Harold walks in, a phone-app order for \"Harold\" comes through. Medium, decaf. Marked for counter pickup."},
    {t:"The app account picture", text:"Priya turns the screen: the account's profile picture is a fat orange cat in a Christmas sweater."},
    {t:"Harold's table", text:"His newspaper, his reading glasses, and a phone in a case printed with a fat orange cat in a Christmas sweater. It isn't his phone. His is in his shirt pocket."},
    {t:"The woman by the window", text:"Harold's wife, June. Very, very interested in her crossword. She hasn't turned a page in five minutes."}
  ]}},
e1_tp1acc:{ep:1, place:"Tom Portons, County Road 20", time:"Tue 11:04", lines:["~So who's switching Harold's coffee?"],
  puzzle:{type:"pick", title:"Who did it?", prompt:"Point at the culprit.", to:"e1_tp1done", options:[
    {t:"Priya, the cashier", why:"Priya rings up exactly what's ordered. The app order isn't hers."},
    {t:"A stranger using Harold's name", why:"A stranger wouldn't know when Harold arrives, or own the cat phone case."},
    {t:"June, his wife", correct:true},
    {t:"Harold, pretending for attention", why:"His receipts are real. He's genuinely furious."}
  ]}},
e1_tp1done:{ep:1, place:"Tom Portons, County Road 20", time:"Tue 11:06", lines:[
  "JUNE: The doctor said no caffeine after his heart thing, and he's a stubborn old goat!",
  "HAROLD: June! Fifty-two years and you're sabotaging my coffee?",
  "JUNE: Fifty-two years and I'd like fifty-three, thank you.",
  "~They bicker. Then they laugh. Then Harold, grumbling, drinks the decaf. Priya slides your fritter across the counter for free.",
  "PRIYA: You should be a detective.",
  "MANI: I'm a data guy. It's just logs."],
  next:"e1_shoulder"},

e1_shoulder:{ep:1, place:"County road north of Chatham", time:"Tue 12:10", lines:[
  "~Farmland turns to forest. The sky goes the colour of wet concrete. Your phone buzzes. Tess.",
  "TESS (TEXT): haven't seen her since sunday night. thought she was with u?? her phone is here at the flat",
  "~You pull onto the gravel shoulder. You call Nila. Voicemail. You call again. Voicemail.",
  "~A truck blows past and rocks the car. You realise you're gripping the wheel hard enough to hurt.",
  "MANI: Okay. Okay. Drive."],
  next:"e1_tp2"},

e1_tp2:{ep:1, place:"Tom Portons, Highway 21 truck stop", time:"Tue 14:20", lines:[
  "~A quieter Tom Portons beside a gas station. Rain on the windows. A refrigerated box truck outside: MERROW PALLETS & SUPPLY.",
  "~Inside, a burly man in a diner apron under his jacket is arguing with a teenage employee.",
  "GUS: I left the cooler on the seat for two minutes. Two minutes!",
  "~At the window table, a well-dressed man in a tailored wool coat and a silver watch sips black coffee and watches with mild amusement."],
  fx:{flag:"met_gus"},
  puzzle:{type:"search", title:"The Missing Cooler", prompt:"The man's blue cooler vanished from his unlocked truck. Find it.", need:3, doneLabel:"Check the staff room", to:"e1_tp2b", spots:[
    {t:"The truck cab", text:"Unlocked. Rain on the seat where the cooler was. Wet sneaker prints lead away, toward the back of the restaurant."},
    {t:"The back corridor", text:"The sneaker prints get fainter on the tile. They stop at a door marked STAFF ONLY, which is ajar. Giggling inside."},
    {t:"The staff room door", text:"Two teens on break. One has a backpack soaking wet and bulging at the seams. He sees you looking and goes very still."},
    {t:"The man in the wool coat", text:"He hasn't moved. But when you looked at the truck, he looked at the truck. When you looked at the staff room, he was already looking there."}
  ]}},
e1_tp2b:{ep:1, place:"Tom Portons, staff room", time:"Tue 14:26", lines:[
  "~As you reach the staff room, the man in the wool coat is suddenly beside you, as if this were a game you were playing together.",
  "VICTOR: Kids think every cooler is full of beer. Shall we?",
  "~The cooler is in the wet backpack. He gets to it first and lifts the lid an inch. You glimpse a heat pack and a ventilated plastic box with something coiled inside. He shuts it.",
  "VICTOR: Bait. Gus fishes. Don't you, Gus?",
  "GUS: Yeah. Bait.",
  "~Gus takes the cooler without meeting your eyes and leaves fast. The truck pulls out into the rain."],
  fx:{clue:"cooler"}, next:"e1_victor"},
e1_victor:{ep:1, place:"Tom Portons, Highway 21", time:"Tue 14:30", lines:[
  "VICTOR: Sharp eyes. What do you do?",
  "MANI: Software. Data. Between jobs.",
  "VICTOR: Ah. The most dangerous kind of person. Someone who notices patterns. Where are you headed?"],
  choices:[
    {t:"\"Greyhaven. Visiting my sister for Diwali.\"", to:"e1_victor2", fx:{flag:"toldVictor"}},
    {t:"\"North. Visiting family.\"", to:"e1_victor2"}
  ]},
e1_victor2:{ep:1, place:"Tom Portons, Highway 21", time:"Tue 14:32", lines:[
  "~His eyes go to your car through the window. The sweets box on the passenger seat.",
  "VICTOR: Diwali. Festival of lights. Good triumphs over evil, isn't it? I've always liked that story.",
  s => s.flags.toldVictor ? "VICTOR: Greyhaven's a strange little town. Fog, a lake, a priest who rings a bell for nobody. Lovely." : "VICTOR: If north means the lake country, try Greyhaven. Fog, a lake, a priest who rings a bell for nobody. Lovely.",
  "~His phone buzzes. He turns half away.",
  "VICTOR (ON PHONE): Mark. Yes, I'm on the road. Tonight. It'll be clean.",
  "~He hangs up, drops a twenty on the counter for both your coffees, and slides a card across the table: KESSLER RESTRUCTURING — Victor Kessler, Principal.",
  "VICTOR: If you ever want work, I hire people who notice things. Drive safe, Mani. The county roads get dark early this time of year.",
  "~Only when he's gone do you realise you never told him your name. It was written on your coffee cup.",
  "~At the far gas pump, a black car with tinted windows. A man in a long dark coat stands beside it, not pumping gas, facing the restaurant. When you walk out, the car is gone."],
  fx:{clue:"victorCard"}, next:"e1_main"},

e1_main:{ep:1, place:"Main Street, Greyhaven", time:"Tue 17:40", lines:[
  "~Fog sits on Lake Merrow like something waiting. Three streetlights, sodium orange. A shuttered hardware store. The Merrow Diner, lit and almost empty. St. Brendan's church bell rings six times, though there is no service.",
  "~A bronze plaque at the lakeside: OLD MERROW, 1842–1978. A village given to the water so the valley could prosper.",
  "~Through the diner window, a young woman in an apron sees your car's Windsor plates and waves at you to wait. Across the street, a small brick building with a dark sign: LAKE MERROW 94.1 FM."],
  choices:[
    {t:"Go to the Lakeview Motel, where Nila lives", to:"e1_ruth"},
    {t:"Look at the radio station first", to:"e1_station", once:"e1st"}
  ]},
e1_station:{ep:1, place:"Lake Merrow 94.1 FM", time:"Tue 17:46", lines:[
  "~The station is locked. Through the glass door: gold records on the wall, a dark studio, a red ON AIR bulb, unlit. Taped inside the door, a printed notice.",
  "~\"AFTER HOURS with Nila is suspended until further notice. — Brian Holt, Station Manager.\"",
  "~Nila never told you her show was suspended."],
  next:"e1_ruth"},

e1_ruth:{ep:1, place:"Lakeview Motel office", time:"Tue 18:00", lines:[
  "~The Lakeview's neon sign has two dead letters. Behind the desk, a woman in her sixties, reading glasses on a chain, a police scanner murmuring, a shotgun leaning within easy reach.",
  "RUTH: Rooms are forty a night.",
  "MANI: I'm Nila's brother. Mani. She lives upstairs.",
  "~She looks up slowly. Studies your face like she's checking it against one she knows."],
  fx:{flag:"met_ruth"},
  choices:[
    {t:"\"She told me to talk to you and nobody else.\"", sub:"The truth.", to:"e1_ruth2", fx:{trust:{ruth:2}}},
    {t:"\"I'm here for Diwali. Is she around?\"", sub:"Casual.", to:"e1_ruth2", fx:{trust:{ruth:1}}},
    {t:"\"Has the sheriff been asking about her?\"", sub:"Too direct.", to:"e1_ruth2b"}
  ]},
e1_ruth2:{ep:1, place:"Lakeview Motel office", time:"Tue 18:03", lines:[
  "RUTH: You've got her eyes.",
  "~She takes off her glasses.",
  "RUTH: She hasn't been home since Sunday. Her car's in the lot. I called Corbin Monday. Sheriff Corbin. He said she's a grown woman and probably ran off with somebody.",
  "~She slides a key across the counter.",
  "RUTH: Flat's up the back stairs. Tess has the other key. And Mani. I sleep light, and I keep this on all night.",
  "~She taps the scanner."], next:"e1_flat"},
e1_ruth2b:{ep:1, place:"Lakeview Motel office", time:"Tue 18:03", lines:[
  "~Her face closes like a door.",
  "RUTH: I don't talk about the sheriff to strangers.",
  "MANI: I'm not a stranger. I'm her brother.",
  "~A long pause. She slides a key across the counter without looking at you.",
  "RUTH: Flat's up the back stairs. She hasn't been home since Sunday. That's all I know."], next:"e1_flat"},

e1_flat:{ep:1, place:"Nila's flat, above the motel", time:"Tue 18:30", lines:[
  "~A small two-bedroom. Fairy lights half-strung along the window. A rangoli of coloured chalk on the floor by the door, half-finished, a muddy footprint smudged through it. Posters of old radio stations. A cork board covered in notes.",
  "~The door bangs open behind you. The young woman from the diner, breathless, still in her apron.",
  "TESS: You're Mani. She talks about you, like, constantly. \"Anna would know what to do.\"",
  "TESS: She left Sunday night with her radio bag. She said she'd be back by two. She wasn't."],
  fx:{flag:"met_tess", trust:{tess:1}},
  puzzle:{type:"search", title:"Nila's flat", prompt:"Look around while Tess talks.", need:3, doneLabel:"Talk to Tess", to:"e1_tess", spots:[
    {t:"Nila's phone on the table", text:"Dead. You plug it in. It lights up: locked. Her lock screen is a photo of you and her at the Windsor riverfront, making faces."},
    {t:"The cork board", text:"Sticky notes from listeners. \"My dog drank lake water and died.\" \"Trucks on the mill road at 2am again.\" \"Rash on my kid's arms, doctor says eczema.\" \"Saw a GOLD snake on Marsh dock??\"", clue:"corkboard"},
    {t:"The printout in the middle of the board", text:"AFTER HOURS — SUSPENDED UNTIL FURTHER NOTICE. Brian Holt, Station Manager. Nila has circled \"further notice\" in red pen and written: \"cowards\"."},
    {t:"The half-finished rangoli", text:"Nila's careful lotus pattern, half done, the chalk box open beside it. Smudged through the middle: a muddy boot print. Big. Size 11, maybe. You photograph it.", clue:"bootprint"}
  ]}},
e1_tess:{ep:1, place:"Nila's flat", time:"Tue 18:45", lines:[
  "TESS: They pulled her show two weeks ago. Brian said \"sponsor complaints\". The mill's the sponsor. There's a mill? It's been closed my whole life.",
  "TESS: She got weird after that. Out every night with that radio bag. She said she was \"finishing a story\". She said, \"Tess, if my brother comes, give him the spare key and tell him I'm sorry about Diwali.\"",
  "~Tess has to go back for the end of her shift. At the door she hesitates.",
  "TESS: Lock this. Please."],
  choices:[
    {t:"\"I will. Thank you, Tess.\"", to:"e1_cliff", fx:{trust:{tess:1}}},
    {t:"\"Who do you think came in here?\"", to:"e1_tess2"}
  ]},
e1_tess2:{ep:1, place:"Nila's flat", time:"Tue 18:47", lines:[
  "~Tess looks at the boot print. Something passes across her face and is gone.",
  "TESS: Lots of guys in this town wear size eleven.",
  "~She leaves fast."], next:"e1_cliff"},

e1_cliff:{ep:1, radio:true, place:"Your car, motel lot", time:"Tue 22:58", lines:[
  "~You sit in the car to warm up, the gift radio in its wrapping on the passenger seat. Out of habit, you tune the car radio to 94.1, Nila's station. Dead air. A faint hiss.",
  "~The dashboard clock turns 23:00.",
  "~The hiss shifts. A voice, live, close, tired.",
  "NILA (ON AIR): This is After Hours. If anyone's still listening—",
  "NILA (ON AIR): Anna, parking-la irukkiradhu nee dhaana? Ennai thedi varaadha. Veetuku po. Please. || Anna, is that you in the lot? Don't come looking for me. Go home. Please.",
  "MANI: Nila? NILA!",
  "~Silence. Then a second voice on the same frequency. A man. Calm, unhurried, almost kind.",
  "MAN'S VOICE (ON AIR): He's already here, Nila.",
  "~The signal dies. Far out on the fogged lake, a single red light blinks twice, then goes dark."],
  next:"e1_end"},
e1_end:{ep:1, place:"Greyhaven", time:"Tue 23:01", lines:["~End of Episode 1."], epEnd:true}
});
