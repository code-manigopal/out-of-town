/* Out of Town: Greyhaven — part definition. Scenes are added by p1e*.js */
window.OTT_PARTS = window.OTT_PARTS || {};
window.OTT_PARTS.p1 = {
  id:"p1", title:"Greyhaven", name:"Out of Town: Greyhaven", weather:"fog",
  blurb:"Mani drives from Windsor to the lake town of Greyhaven to spend Diwali with his sister Nila. She's gone. The town is hiding a drug lab, a smuggling ring, and the man who listens.",
  episodes:[
    {title:"County Roads", start:"e1_open", blurb:"Windsor to Greyhaven. Nila is missing."},
    {title:"Dead Air", start:"e2_open", blurb:"The flat, the sheriff, the tape."},
    {title:"Low Water", start:"e3_open", blurb:"The Marsh family and the drowned village."},
    {title:"The Mill", start:"e4_open", blurb:"Inside the closed paper mill."},
    {title:"The Badge", start:"e5_open", blurb:"The doctor, the deputy, the sheriff's drawer."},
    {title:"Old Merrow", start:"e6_open", blurb:"Diwali eve. The dive."},
    {title:"Pike Point", start:"e7_open", blurb:"The tower. Nila."},
    {title:"Daybreak", start:"e8_open", blurb:"The siege, the broadcast, the way home."}
  ],
  people:{ruth:"Ruth Vane", tess:"Tess Marsh", eli:"Eli Marsh", walter:"Walter Marsh", gus:"Gus Pell", corbin:"Sheriff Corbin", ortiz:"Deputy Ortiz", rao:"Dr. Rao"},
  peopleShow:(k, S) => S.flags["met_" + k],
  dangerNotes:["Nobody in town has noticed you.","Someone noticed the man from Windsor.","People are talking about you.","Corbin is looking for you.","Victor's men are hunting you.","They know exactly where you are."],
  endings:[
    {id:"daybreak", name:"Daybreak"},
    {id:"fog", name:"Out of the Fog"},
    {id:"wrong", name:"Wrong Hands"},
    {id:"silent", name:"Silent Water"},
    {id:"lamplight", name:"Lamplight"}
  ],
  clues:{
    voicemail:{name:"Nila's voicemail", desc:"Sunday 23:52. \"Talk only to Ruth… trust anyone, but don't trust the—\""},
    victorCard:{name:"Victor Kessler's card", desc:"KESSLER RESTRUCTURING — Victor Kessler, Principal. He paid for your coffee and knew your name."},
    cooler:{name:"Gus's \"bait\" cooler", desc:"A heat pack and a ventilated box with something coiled inside. Gus said it was bait."},
    corkboard:{name:"Nila's caller board", desc:"\"Dog drank lake water and died.\" \"Trucks on the mill road at 2am.\" \"Gold snake on Marsh dock??\""},
    bootprint:{name:"Boot print in the rangoli", desc:"Size 11, lake mud, right through Nila's half-finished rangoli."},
    radiolog:{name:"Radio log page", desc:"Every night since Oct 21: 23:00, 7.185 MHz, \"PP\". \"If I'm not here, I'm there.\""},
    cable:{name:"Cut antenna cable", desc:"Four metres of coax, sliced clean. Someone wanted her off the air. You kept it."},
    mirror:{name:"MILL", desc:"Written in the steam on Nila's bathroom mirror."},
    scale:{name:"Gold snake scale", desc:"Fingernail-sized, gold and brown, caught in the carpet where her radio bag used to be."},
    callers:{name:"Callers spreadsheet", desc:"46 listener reports. Plotted on a map, nearly all sit on the lakeshore or the mill road.", proof:true},
    email:{name:"Nila's unsent email", desc:"To a Toronto journalist: \"Not just dumping. Something alive is moving through this town.\""},
    tape:{name:"The Oct 20 tape", desc:"An old man's call: barrels in '77, barrels again now, crates of live animals at night."},
    sponsor:{name:"Kessler sponsorship", desc:"Victor Kessler paid 94.1 two years in advance, five minutes after Nila's show was cut."},
    memo:{name:"Nila's voice memo", desc:"\"Eli knows. Ask about the dock.\" And: the man in the coat listens every night."},
    lancehead:{name:"Golden lancehead", desc:"Bothrops insularis. Only lives on Snake Island, Brazil. Critically endangered, deadly, worth tens of thousands."},
    map:{name:"Nila's map of Old Merrow", desc:"X on the drowned church: \"barrels — dive here\". Pier 3: \"boats Tue/Fri 02:00\". Pike Point: \"PP. Jonah. Safe.\""},
    manifest:{name:"Crate manifest", desc:"MANIFEST 0412 — CONSIGNEE: M. HAYDEN, WINDSOR, ON."},
    hadesName:{name:"\"Hades\"", desc:"Victor on the pier: \"Tell Hades it'll be clean by Friday.\""},
    knifephoto:{name:"Photo of Tess", desc:"Pinned to the Marsh dock with a fishing knife. On the back: \"Bait.\""},
    notebooks:{name:"Ruth's notebooks", desc:"Fourteen years of mill trucks, dates, times and plates. Every Tuesday and Friday."},
    lab:{name:"Lab photos", desc:"Pill presses stamping blue M30 tablets in the mill's pulping hall. Barrels of chemical sludge.", proof:true},
    pills:{name:"Bag of pills", desc:"A sealed bag of counterfeit M30 tablets. Physical evidence."},
    ledger:{name:"Victor's ledger (USB)", desc:"D.C. $4,000/month. G.P. $1,200 per run. B.H. sponsorship. Venom sales. H. — 60%.", proof:true},
    hadesFile:{name:"Hades_contacts.enc", desc:"An encrypted file copied from Victor's laptop. Unreadable. For now."},
    payroll:{name:"Corbin's payroll envelope", desc:"Cash marked \"Nov — V.\" and four death certificates signed \"cardiac arrest\"."},
    medical:{name:"Dr. Rao's records", desc:"Illness clustered on Lakeshore and Mill Road. Four 2026 \"cardiac\" deaths that were fentanyl.", proof:true},
    revolver:{name:"Revolver from Ortiz", desc:"Six rounds. Confiscated from a poacher. \"It's not in any system. I didn't give you this.\""},
    photo1978:{name:"1978 dam photo", desc:"\"R. Hayden, Merrow Dam Authority.\" At the edge of the crowd, a figure in a long coat."},
    dumping:{name:"Dumping photos", desc:"Old Merrow underwater: 1977 barrels, new blue barrels leaking, a cage of dead tortoises.", proof:true},
    footage:{name:"Nila's dive footage", desc:"Victor and Corbin, side by side, dumping crates. \"The ones Hades won't pay for.\"", proof:true},
    jonahTapes:{name:"Jonah's recordings", desc:"A second voice answering Nila every night. \"Victor, you're sloppy.\""}
  },
  init(S){ S.vars.rounds = 6; },
  defaultsFor(S, ep){
    // sensible defaults when starting a later episode without having played earlier ones
    const f = S.flags;
    const add = c => { if(!S.clues.includes(c)) S.clues.push(c); };
    if(ep >= 2){ ["voicemail","victorCard","corkboard","bootprint"].forEach(add); f.met_ruth = f.met_tess = f.met_gus = true; S.trust.ruth = Math.max(S.trust.ruth, 2); }
    if(ep >= 3){ ["radiolog","cable","mirror","callers","tape","sponsor","memo"].forEach(add); f.met_corbin = true; }
    if(ep >= 4){ ["lancehead","map","manifest","hadesName","knifephoto"].forEach(add); f.met_eli = f.met_walter = true; f.protectTess = true; S.trust.eli = 1; }
    if(ep >= 5){ ["notebooks","lab","ledger","hadesFile"].forEach(add); }
    if(ep >= 6){ ["payroll","medical","revolver"].forEach(add); f.met_ortiz = f.met_rao = true; S.trust.ortiz = 2; S.trust.rao = 2; }
    if(ep >= 7){ ["photo1978","dumping"].forEach(add); f.forgaveWalter = true; }
    if(ep >= 8){ ["footage","jonahTapes"].forEach(add); }
  }
};
window.OTT_PARTS.p1.scenes = {};
