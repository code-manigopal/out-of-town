/* Out of Town: Red Lake — part definition. Scenes are added by p2e*.js */
window.OTT_PARTS = window.OTT_PARTS || {};
window.OTT_PARTS.p2 = {
  id:"p2", title:"Red Lake", name:"Out of Town: Red Lake", weather:"snow", hasCombat:true, hasHealth:true,
  blurb:"Eleven months later, Nila is dying of a cancer Hades gave her. Mani and his wife Preethi drive five days north to Red Lake to take the cure from him, with Nila guiding them by radio.",
  episodes:[
    {title:"Lighthouse", start:"p2e1_open", blurb:"The diagnosis, the guns, the road north."},
    {title:"Highway 17", start:"p2e2_open", blurb:"White River, Thunder Bay, an ambush in the snow."},
    {title:"Gold Country", start:"p2e3_open", blurb:"Red Lake. The hospital, the museum, Level 9."},
    {title:"The Ice Road", start:"p2e4_open", blurb:"McKenzie Island and the man who dug it."},
    {title:"Hayden Deep", start:"p2e5_open", blurb:"Into the mine."},
    {title:"Starratt-Olsen", start:"p2e6_open", blurb:"Amma on the radio. A ghost town at midnight."},
    {title:"The Burn", start:"p2e7_open", blurb:"Hades's forest. Kane."},
    {title:"The Hades Mansion", start:"p2e8_open", blurb:"Three vials. One cure."}
  ],
  people:{ivy:"Ivy Laurent", dunn:"Const. Dunn", daniel:"Daniel Keeper", bev:"Bev Arsenault", sully:"Sully O'Rourke", marchetti:"Dr. Marchetti"},
  peopleShow:(k, S) => S.flags["met_" + k],
  dangerNotes:["Nobody up here knows your names.","Someone noticed the couple from Windsor.","Northstar is watching you.","Kane is looking for you.","Kane's hunters are on your trail.","Hades knows exactly where you are."],
  clues:{
    panel:{name:"Nila's blood panel", desc:"One unnamed compound the lab called an artefact. Preethi says it isn't."},
    jonahWater:{name:"Jonah's answer", desc:"\"I never brought you water.\" Someone else left those bottles at Pike Point."},
    label:{name:"Northstar shipping label", desc:"NORTHSTAR BIOLOGICS — HX-7 — HAYDEN DEEP, RED LAKE, ON. From Victor's fireproof safe."},
    delivery:{name:"GH-01 delivery note", desc:"\"24 × spring water, 1 L. Pike Point. Attn: GH-01.\" The week Nila hid there."},
    guns:{name:"Rocco's guns", desc:"Pump shotgun, M4, two Desert Eagles. Illegal. Bought under the Ambassador Bridge."},
    ivyMap:{name:"Ivy's surface map", desc:"Gatehouse, office, loading dock, and a freight elevator that goes deeper than the mine maps say."},
    profile:{name:"Dr. Okafor's profile", desc:"A collector who needs control. A voyeur who needs an audience. \"He'll want you in the room.\""},
    dunnName:{name:"Constable Rachel Dunn", desc:"OPP, Red Lake. \"Honest. Too honest for her own good.\""},
    convoy:{name:"Thursday convoy", desc:"Northstar trucks run up Highway 105 every Thursday night. Fuel stop at Ear Falls."},
    gift:{name:"Welcome gift", desc:"A shed lancehead skin and a photo of Nila asleep, taken inside her hospital room. \"Welcome to my town.\""},
    panels5:{name:"Five blood panels", desc:"Nila and four dead Northstar workers share one peptide. Nila is about three weeks behind the last man.", proof:true},
    hayden:{name:"The Hayden family", desc:"Prospectors in 1934. Hayden Deep, 1946–1991. Engineer R. Hayden went south in 1974. Mark Hayden came home in 2015."},
    robert:{name:"\"Old Robert\"", desc:"Mark's father. \"Must be ninety if he's a day.\" Some say he lives out past the Burn with his son."},
    level9:{name:"\"Level 9\"", desc:"A gold specimen with a hidden second tag. Public mine maps show only six levels."},
    sullyMap:{name:"Sully's 1974 map", desc:"Levels 6 to 9, and a forgotten ventilation raise that comes up in the bush near Madsen."},
    farm:{name:"Venom farm photos", desc:"Hundreds of golden lanceheads in heated tanks on Level 9. Robotic arms milking venom.", proof:true},
    gh01:{name:"Subject GH-01 file", desc:"Nila. \"Route: drinking water. Pike Point.\" In Hades's hand: \"Keep her alive until the brother comes. — M.H.\"", proof:true},
    rl:{name:"Subjects RL-01 to RL-04", desc:"The four dead Red Lake workers. Joe Keeper was RL-03.", proof:true},
    cure:{name:"HX-7C", desc:"The antidote. \"Three doses. Stored at the house vault. Access: M.H. only.\""},
    thermal:{name:"Thermal image", desc:"One heat source in 400 km² north-west of the Burn: a house. Behind it, something very hot."},
    portraits:{name:"The portrait gallery", desc:"Robert Hayden in a long coat beside the Merrow dam, 1978. A boy with a jar of snakes."},
    antivenom:{name:"Antivenom", desc:"One dose, taken from the Hayden Deep lab fridge by Preethi."}
  },
  init(S){ S.health = 100; S.big = {mani:"M4", preethi:"Shotgun"}; },
  defaultsFor(S, ep){
    const add = c => { if(!S.clues.includes(c)) S.clues.push(c); };
    if(ep >= 2){ ["panel","jonahWater","label","delivery","guns","ivyMap"].forEach(add); S.ammo = {rifle:120, shells:30, pistol:42}; S.medkits = 3; S.flags.met_ivy = true; S.health = 80; }
    if(ep >= 3){ ["profile","dunnName","convoy","gift"].forEach(add); S.trunk = 2; S.grenades = {mani:2, preethi:2}; S.flags.met_bev = true; S.health = 70; }
    if(ep >= 4){ ["panels5","hayden","robert","level9"].forEach(add); S.flags.met_marchetti = S.flags.met_dunn = S.flags.met_daniel = true; S.health = 40; }
    if(ep >= 5){ ["sullyMap"].forEach(add); S.flags.met_sully = true; S.health = 38; }
    if(ep >= 6){ ["farm","gh01","rl","cure","antivenom"].forEach(add); S.trunk = 6; S.health = 30; }
    if(ep >= 7){ ["thermal"].forEach(add); S.health = 18; S.trunk = 6; }
    if(ep >= 8){ S.flags.disguise = true; S.health = 14; }
  }
};
window.OTT_PARTS.p2.scenes = {};
