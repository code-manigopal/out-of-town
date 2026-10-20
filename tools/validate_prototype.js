const fs=require('fs'), vm=require('vm'), path=require('path');
const dir=require('path').join(__dirname,'..','prototype','browser');
const ctx={window:{}}; vm.createContext(ctx);
const files=['part1.js',...[1,2,3,4,5,6,7,8].map(i=>`p1e${i}.js`),'part2.js',...[1,2,3,4,5,6,7,8].map(i=>`p2e${i}.js`)];
for(const f of files) vm.runInContext(fs.readFileSync(path.join(dir,f),'utf8'),ctx,{filename:f});
const PARTS=ctx.window.OTT_PARTS; let errs=0, words=0, scenes=0;
function mkState(pid, variant){
  const P=PARTS[pid]; const S={part:pid,scene:null,ep:1,flags:{},vars:{rounds:6,price:26,brian:2,rao:2,cb:0,interview:2,bites:0,chase:0,trips:0,dunnScore:2,failAt:"e8_offer"},trust:{},danger:0,clues:Object.keys(P.clues),hp:{mani:100,preethi:100},ammo:{rifle:100,shells:30,pistol:40},grenades:{mani:2,preethi:2},trunk:4,medkits:2,big:{mani:"M4",preethi:"Shotgun"},hold:{mani:"big",preethi:"big"},health:50,active:"mani"};
  Object.keys(P.people).forEach(k=>S.trust[k]=variant?3:-1);
  if(variant){ ["protectTess","eliBelieved","forgaveWalter","honest6","strongSignal","cableKept","tylerFlipped","warned","restraint","quietSurface","burned","flareTripped","corbinKnowsPP","bitten","missedDrawer","interviewGood","ortizCame","overshoot","blackIce"].forEach(f=>S.flags[f]=true); }
  else { S.clues=S.clues.slice(0,3); S.flags.jamLost=true; }
  return S;
}
const val=(v,S)=>typeof v==='function'?v(S):v;
for(const pid of Object.keys(PARTS)){
  const P=PARTS[pid]; const ids=new Set(Object.keys(P.scenes));
  P.episodes.forEach(e=>{ if(!ids.has(e.start)){console.log(pid,'missing ep start',e.start);errs++;} });
  const reach=new Set();
  for(const [id,sc] of Object.entries(P.scenes)){
    scenes++;
    for(const variant of [true,false]){
      const S=mkState(pid,variant);
      const targets=[];
      try{
        const lines=val(sc.lines,S)||[]; lines.forEach(l=>{const t=val(l,S); if(typeof t==='string') words+= variant? t.split(/\s+/).length:0; else if(t!=null) {console.log(pid,id,'bad line',t);errs++;}});
        if(sc.next) targets.push(val(sc.next,S));
        (val(sc.choices,S)||[]).forEach(c=>{ targets.push(val(c.to,S)); if(c.req) val(c.req,S); if(c.fx) val(c.fx,S); });
        if(sc.timer) { targets.push(val(sc.timer.to,S)); val(sc.timer.secs,S); }
        const pz=val(sc.puzzle,S); if(pz){ targets.push(val(pz.to,S)); if(pz.type==='order'&&!(pz.items&&pz.items.length)){console.log(pid,id,'empty order');errs++;} if(pz.type==='search') pz.spots.forEach(sp=>val(sp.text,S)); }
        const cb=val(sc.combat,S); if(cb){ targets.push(cb.to); if(cb.cleanTo) targets.push(cb.cleanTo); }
        if(sc.fx) val(sc.fx,S);
        if(!sc.next && !sc.choices && !sc.puzzle && !sc.combat && !sc.epEnd && !sc.ending){console.log(pid,id,'dead end');errs++;}
      }catch(e){ console.log(pid,id,'ERROR',e.message); errs++; }
      targets.forEach(t=>{ if(!ids.has(t)){console.log(pid,id,'-> missing',t);errs++;} else reach.add(t); });
    }
  }
  P.episodes.forEach(e=>reach.add(e.start));
  const unreached=[...ids].filter(i=>!reach.has(i));
  if(unreached.length) console.log(pid,'unreached:',unreached.join(', '));
}
console.log('scenes',scenes,'approx words',words,'errors',errs); process.exit(errs?1:0);
