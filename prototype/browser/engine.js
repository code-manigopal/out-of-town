/* Out of Town — story engine
   Parts register themselves on window.OTT_PARTS before this file loads. */
(function(){
"use strict";
const PARTS = window.OTT_PARTS || {};
const $ = s => document.querySelector(s);
const root = $("#root");
const LS = {
  get(k){ try{ const v = localStorage.getItem(k); return v ? JSON.parse(v) : null; }catch(e){ return null; } },
  set(k,v){ try{ localStorage.setItem(k, JSON.stringify(v)); }catch(e){} },
  del(k){ try{ localStorage.removeItem(k); }catch(e){} }
};
const PROG_KEY = "ott.progress.v1", SET_KEY = "ott.settings.v1";
let PROG = LS.get(PROG_KEY) || {};
let SETTINGS = Object.assign({subs:"all", speed:"normal", unlockAll:false}, LS.get(SET_KEY) || {});
function prog(pid){ PROG[pid] = PROG[pid] || {done:[], endings:[]}; return PROG[pid]; }
function saveProg(){ LS.set(PROG_KEY, PROG); }
function saveSettings(){ LS.set(SET_KEY, SETTINGS); }

let P = null;            // current part definition
let S = null;            // current state
let screen = "title";
let typing = null, timerRAF = null, keyHandler = null;
let flashJournal = false, dangerJump = false;
const val = v => (typeof v === "function" ? v(S) : v);
const esc = s => String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
const fmt = s => esc(s).replace(/\*([^*]+)\*/g, "<em>$1</em>");
const rnd = (a,b) => a + Math.floor(Math.random()*(b-a+1));
const clamp = (v,a,b) => Math.max(a, Math.min(b, v));

/* ---------- state ---------- */
function freshState(pid){
  const part = PARTS[pid];
  const base = {part:pid, scene:null, ep:1, flags:{}, vars:{}, trust:{}, danger:0, clues:[],
    hp:{mani:100, preethi:100}, ammo:{rifle:0, shells:0, pistol:0}, grenades:{mani:0, preethi:0},
    trunk:0, medkits:0, big:{mani:"M4", preethi:"Shotgun"}, hold:{mani:"big", preethi:"big"},
    health:100, active:"mani"};
  Object.keys(part.people || {}).forEach(k => base.trust[k] = 0);
  if(part.init) part.init(base);
  return base;
}
const saveKey = pid => "ott.save." + pid;
function persist(){ if(S && S.scene) LS.set(saveKey(S.part), S); }

/* ---------- effects ---------- */
function applyFx(fx){
  if(!fx) return;
  fx = val(fx);
  if(!fx) return;
  [].concat(fx.flag || []).forEach(f => S.flags[f] = true);
  [].concat(fx.unflag || []).forEach(f => delete S.flags[f]);
  [].concat(fx.clue || []).forEach(c => {
    if(!S.clues.includes(c)){
      S.clues.push(c);
      const cd = P.clues[c];
      toast((cd && cd.proof ? "Proof added: " : "In journal: ") + (cd ? cd.name : c));
      flashJournal = true;
    }
  });
  if(fx.trust) for(const k in fx.trust){ S.trust[k] = clamp((S.trust[k]||0) + fx.trust[k], -3, 3); }
  if(fx.danger){ S.danger = clamp(S.danger + fx.danger, 0, 5); if(fx.danger > 0) dangerJump = true; }
  if(fx.health){ S.health = clamp(S.health + fx.health, 3, 100); }
  if(fx.setHealth != null){ S.health = fx.setHealth; }
  if(fx.hp) for(const k in fx.hp){ S.hp[k] = clamp(S.hp[k] + fx.hp[k], 1, 100); }
  if(fx.heal){ S.hp.mani = Math.max(S.hp.mani, fx.heal); S.hp.preethi = Math.max(S.hp.preethi, fx.heal); }
  if(fx.ammo) for(const k in fx.ammo){ S.ammo[k] = Math.max(0, (S.ammo[k]||0) + fx.ammo[k]); }
  if(fx.grenades) for(const k in fx.grenades){ S.grenades[k] = Math.max(0, S.grenades[k] + fx.grenades[k]); }
  if(fx.trunk){ S.trunk += fx.trunk; toast("Grenade case: +" + fx.trunk + " grenades in the car trunk"); }
  if(fx.restock){ restock(); }
  if(fx.medkits){ S.medkits = Math.max(0, S.medkits + fx.medkits); }
  if(fx.set) Object.assign(S.vars, fx.set);
  if(fx.add) for(const k in fx.add){ S.vars[k] = (S.vars[k]||0) + fx.add[k]; }
  if(fx.toast) toast(fx.toast);
  if(fx.sound && Sound[fx.sound]) Sound[fx.sound]();
}
function restock(){
  // each character carries up to 3 grenades, refilled from the trunk
  ["mani","preethi"].forEach(c => {
    while(S.grenades[c] < 3 && S.trunk > 0){ S.grenades[c]++; S.trunk--; }
  });
}
function reqMet(r){
  if(!r) return true;
  if(typeof r === "function") return !!r(S);
  if(r.flags && !r.flags.every(f => S.flags[f])) return false;
  if(r.notFlags && r.notFlags.some(f => S.flags[f])) return false;
  if(r.clues && !r.clues.every(c => S.clues.includes(c))) return false;
  if(r.proofs && proofCount() < r.proofs) return false;
  if(r.fn && !r.fn(S)) return false;
  return true;
}
function proofCount(){ return S.clues.filter(c => P.clues[c] && P.clues[c].proof).length; }

/* ---------- navigation ---------- */
function go(target, fx){
  stopAll();
  applyFx(fx);
  const id = val(target);
  const sc = P.scenes[id];
  if(!sc){ root.innerHTML = `<div class="err">Missing scene: ${esc(id)}</div>`; return; }
  S.scene = id;
  if(sc.ep) S.ep = sc.ep;
  if(sc.ep && P.episodes[sc.ep-1] && P.episodes[sc.ep-1].start === id){ S.vars._epStart = clone(S); delete S.vars._epStart.vars._epStart; }
  applyFx(sc.fx);
  render(true);
  persist();
}
const clone = o => JSON.parse(JSON.stringify(o));

/* ---------- rendering ---------- */
function setPart(pid){
  P = PARTS[pid];
  document.documentElement.setAttribute("data-part", pid);
  $("#partTag").textContent = P ? P.title : "";
  Weather.mode(P ? P.weather : "fog");
}
function render(animate){
  const sc = P.scenes[S.scene];
  if(sc.ending) return renderEnding(sc);
  screen = "game";
  $("#clock").textContent = val(sc.time) || "";
  if(sc.radio) Sound.burst();
  root.innerHTML = `<div class="game">
    <section class="story">
      <div class="place"><span>${esc(P.episodes[S.ep-1] ? "Ep " + S.ep + " · " + P.episodes[S.ep-1].title : "")}</span><span>${esc(val(sc.place)||"")}</span><span class="t">${esc(val(sc.time)||"")}</span></div>
      <div class="text" id="text" aria-live="polite"></div>
      <div class="timerbox" id="timerBox" hidden><div class="timer-label">Decide now</div><div class="timer"><i id="timerBar"></i></div></div>
      <div id="act"></div>
    </section>
    <aside class="journal" id="journal">${journalHTML()}</aside>
  </div>`;
  if(flashJournal){ $("#journal").classList.add("flash"); flashJournal = false; }
  if(dangerJump){ const l = $("#lamps"); if(l) l.classList.add("shake"); dangerJump = false; Sound.thud(); }
  if(sc.card && animate) showCard(sc);
  const lines = val(sc.lines) || [];
  typeOut(lines, animate && !sc.card, () => showAct(sc));
  if(sc.card && animate) setTimeout(() => {}, 0);
}
function showCard(sc){
  const ep = P.episodes[S.ep-1];
  const d = document.createElement("div");
  d.className = "card-ov";
  d.innerHTML = `<div class="k">${esc(P.name)} · Episode ${S.ep}</div><div class="t">${esc(ep ? ep.title : "")}</div>`;
  document.body.appendChild(d);
  Sound.burst();
  setTimeout(() => d.remove(), 3300);
}

function parseLine(raw){
  if(typeof raw !== "string") return {kind:"narr", text:String(raw)};
  if(raw.startsWith("~")) return {kind:"narr", text:raw.slice(1).trim()};
  const m = raw.match(/^([A-Z][A-Z0-9 .'\-]*(?:\([A-Z0-9 ,.'\-]+\))?):\s([\s\S]*)$/);
  if(!m) return {kind:"narr", text:raw};
  let who = m[1].trim(), rest = m[2];
  const tm = who.match(/\(([^)]+)\)/);
  const TAGS = {"ON RADIO":"radio","ON AIR":"on air","V.O.":"voicemail","ON PHONE":"phone","PA":"loudspeaker","ON TAPE":"tape","VOICE MEMO":"voice memo","TEXT":"text","MEGAPHONE":"megaphone","ON CB":"CB radio","AS KANE":"as Kane","ON FOOTAGE":"footage","INTO RADIO":"radio"};
  let radio = tm ? (TAGS[tm[1]] || "") : "";
  let say = rest, sub = null;
  const idx = rest.indexOf(" || ");
  if(idx >= 0){ say = rest.slice(0, idx); sub = rest.slice(idx + 4); }
  return {kind:"line", who, radio, say, sub};
}
function lineHTML(L, partial){
  if(L.kind === "narr") return `<p class="narr">${partial != null ? fmt(L.text.slice(0, partial)) : fmt(L.text)}</p>`;
  const sayText = partial != null ? L.say.slice(0, partial) : L.say;
  let subHTML = "";
  const done = partial == null || partial >= L.say.length;
  if(done){
    if(L.sub && SETTINGS.subs !== "off") subHTML = `<span class="sub">${fmt(L.sub)}</span>`;
    else if(!L.sub && SETTINGS.subs === "all") subHTML = `<span class="sub">${fmt(L.say)}</span>`;
  }
  return `<div class="line${L.sub ? " ta" : ""}"><span class="who">${esc(L.who.replace(/\s*\(.*\)/, ""))}${L.radio ? `<span class="tag"> · ${esc(L.radio)}</span>` : ""}</span><span class="say">${fmt(sayText)}</span>${subHTML}</div>`;
}
function typeOut(raw, animate, done){
  const box = $("#text");
  const items = raw.map(r => val(r)).filter(r => r != null && r !== "").map(parseLine);
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const full = () => items.map(L => lineHTML(L)).join("");
  if(!animate || reduce || SETTINGS.speed === "instant" || !items.length){ box.innerHTML = full(); done(); return; }
  const len = L => (L.kind === "narr" ? L.text.length : L.say.length);
  let li = 0, ci = 0;
  const step = SETTINGS.speed === "fast" ? 7 : 3;
  const finish = () => { clearInterval(typing); typing = null; box.innerHTML = full(); box.onclick = null; document.removeEventListener("keydown", skipKey); done(); };
  const skipKey = e => { if(e.key === " " || e.key === "Enter"){ e.preventDefault(); finish(); } };
  box.onclick = finish; document.addEventListener("keydown", skipKey);
  typing = setInterval(() => {
    ci += step;
    while(li < items.length && ci > len(items[li])){ ci -= len(items[li]); li++; }
    if(li >= items.length){ finish(); return; }
    let h = "";
    for(let i = 0; i < li; i++) h += lineHTML(items[i]);
    h += lineHTML(items[li], ci).replace(/(<\/p>|<\/span><\/div>)$/, '<span class="caret"></span>$1');
    h += `<p class="skip">click or press space to skip</p>`;
    box.innerHTML = h;
  }, 16);
}

/* ---------- actions under the text ---------- */
function showAct(sc){
  const act = $("#act");
  keyHandler = null;
  if(sc.puzzle) return Puzzle.render(act, sc.puzzle);
  if(sc.combat) return Combat.start(act, sc.combat);
  if(sc.epEnd) return renderEpEnd(act, sc);
  let list = (val(sc.choices) || []).filter(c => (!c.show || c.show(S)) && !(c.once && S.flags["once_" + c.once]));
  if(!list.length && sc.next) list = [{t:"Continue", to:sc.next, cont:true}];
  const wrap = document.createElement("div");
  wrap.className = "choices";
  list.forEach((c, i) => {
    const ok = reqMet(c.req);
    const b = document.createElement("button");
    b.className = "choice" + (c.cont ? " cont" : "");
    b.style.animationDelay = (i * 60) + "ms";
    b.disabled = !ok; b.id = "choice-" + i;
    b.innerHTML = c.cont ? esc(c.t) : `<span class="k">${i+1}</span><span>${fmt(val(c.t))}${c.sub ? `<small>${fmt(c.sub)}</small>` : ""}${ok ? "" : `<small>Locked · ${esc(c.lock || "not yet")}</small>`}</span>`;
    b.onclick = () => { Sound.click(); if(c.once) S.flags["once_" + c.once] = true; go(c.to, c.fx); };
    wrap.appendChild(b);
  });
  act.appendChild(wrap);
  keyHandler = e => { const n = parseInt(e.key, 10); if(n >= 1 && n <= list.length){ const b = $("#choice-" + (n-1)); if(b && !b.disabled) b.click(); } if((e.key === "Enter") && list.length === 1){ const b = $("#choice-0"); if(b && !b.disabled) b.click(); } };
  if(sc.timer) startTimer(sc.timer);
}
document.addEventListener("keydown", e => { if(screen === "game" && !typing && keyHandler && !(e.target && e.target.tagName === "INPUT")) keyHandler(e); });

function startTimer(t){
  const secs = val(t.secs);
  $("#timerBox").hidden = false;
  const end = performance.now() + secs * 1000;
  let lastBeat = 0;
  const tick = now => {
    const left = Math.max(0, end - now);
    const bar = $("#timerBar"); if(bar) bar.style.transform = `scaleX(${left / (secs * 1000)})`;
    if(now - lastBeat > (left < 3000 ? 420 : 800)){ Sound.beat(); lastBeat = now; }
    if(left <= 0){ timerRAF = null; go(t.to, t.fx); return; }
    timerRAF = requestAnimationFrame(tick);
  };
  timerRAF = requestAnimationFrame(tick);
}
function stopAll(){ if(timerRAF) cancelAnimationFrame(timerRAF); timerRAF = null; if(typing){ clearInterval(typing); typing = null; } keyHandler = null; }

/* ---------- journal ---------- */
function journalHTML(){
  let h = "";
  if(P.hasHealth){
    h += `<div><h3>Nila · Lighthouse</h3><div class="health"><i style="width:${S.health}%"></i></div><div class="dnote">${healthNote(S.health)}</div></div>`;
  }
  const lamps = Array.from({length:5}, (_, i) => `<span class="${i < S.danger ? "on" : ""}"></span>`).join("");
  const notes = P.dangerNotes || ["Nobody's looking at you yet.","Someone noticed you.","People are talking about you.","They're looking for you.","You are being hunted.","They know exactly where you are."];
  h += `<div><h3>Danger</h3><div class="lamps" id="lamps">${lamps}</div><div class="dnote">${notes[S.danger]}</div></div>`;
  if(P.hasCombat){
    const g = c => `${c === "mani" ? "Mani" : "Preethi"}: <b>${S.hold[c] === "big" ? S.big[c] : "Desert Eagle"}</b> · HP ${S.hp[c]} · grenades ${S.grenades[c]}`;
    h += `<div><h3>Gear</h3><div class="inv">${g("mani")}<br>${g("preethi")}<br>Rifle ${S.ammo.rifle} · Shells ${S.ammo.shells} · Pistol ${S.ammo.pistol}<br>Medkits ${S.medkits} · Trunk grenades ${S.trunk}</div></div>`;
  }
  const ppl = Object.keys(P.people || {}).filter(k => !P.peopleShow || P.peopleShow(k, S)).map(k => {
    const v = S.trust[k] || 0, w = Math.abs(v) / 3 * 50;
    const st = v >= 0 ? `left:50%;width:${w}%;background:var(--accent)` : `left:${50-w}%;width:${w}%;background:var(--blood)`;
    return `<div class="person"><span class="nm">${esc(P.people[k])}</span><div class="meter" role="img" aria-label="${esc(P.people[k])} trust ${v}"><i style="${st}"></i></div></div>`;
  }).join("");
  if(ppl) h += `<div><h3>Trust</h3><div class="people">${ppl}</div></div>`;
  const cl = S.clues.length ? S.clues.slice().reverse().map(c => { const d = P.clues[c] || {name:c, desc:""}; return `<li class="${d.proof ? "pf" : ""}"><b>${esc(d.name)}${d.proof ? " · proof" : ""}</b><span>${fmt(d.desc)}</span></li>`; }).join("") : `<li class="empty">Nothing yet. Look closely at everything.</li>`;
  h += `<div><h3>Journal · ${proofCount()} proof</h3><ul class="clues">${cl}</ul></div>`;
  return h;
}
function healthNote(v){
  if(v > 80) return "Talking, joking, giving orders.";
  if(v > 60) return "Tired. Coughing between sentences.";
  if(v > 40) return "Weak. Her voice drops in and out.";
  if(v > 20) return "Very weak. Every word costs her.";
  return "Barely conscious.";
}
function refreshJournal(){ const j = $("#journal"); if(j) j.innerHTML = journalHTML(); }

/* ---------- puzzles ---------- */
const Puzzle = {
  render(act, pz){
    pz = val(pz);
    const box = document.createElement("div");
    box.className = "puzzle";
    box.innerHTML = `<h4>${esc(pz.title || "Puzzle")}</h4><p class="prompt">${fmt(pz.prompt || "")}</p><div class="pbody"></div><div class="msg" id="pmsg"></div>`;
    act.appendChild(box);
    const body = box.querySelector(".pbody"), msg = box.querySelector("#pmsg");
    const say = (t, cls) => { msg.textContent = t; msg.className = "msg " + (cls || ""); };
    const win = () => { Sound.good(); say(pz.okMsg || "Solved.", "ok"); setTimeout(() => go(pz.to, pz.fx), 650); };
    let tries = 0;
    const fail = () => {
      tries++; Sound.bad();
      if(pz.hints && pz.hints[tries-1]) say("Hint: " + pz.hints[tries-1], "bad");
      else say(pz.badMsg || "That's not it.", "bad");
      if(pz.giveUp && tries >= pz.giveUp){ addGiveUp(); }
    };
    const addGiveUp = () => {
      if(box.querySelector(".giveup")) return;
      const g = document.createElement("button"); g.className = "pbtn ghost giveup"; g.textContent = pz.giveUpLabel || "Show me the answer";
      g.onclick = () => { say(pz.answerText || "Moving on.", "ok"); setTimeout(() => go(pz.to, pz.giveUpFx || pz.fx), 900); };
      box.appendChild(g);
    };
    if(pz.type === "code"){
      body.innerHTML = `<div class="row"><input type="text" id="pin" autocomplete="off" spellcheck="false" placeholder="${esc(pz.placeholder || "Type your answer")}"><button class="pbtn" id="pgo">Try</button></div>`;
      const inp = body.querySelector("#pin");
      const norm = s => s.toLowerCase().replace(/[^a-z0-9]/g, "");
      const tryIt = () => { const v = norm(inp.value); if(!v) return; if([].concat(pz.answer).some(a => norm(a) === v)) win(); else fail(); };
      body.querySelector("#pgo").onclick = tryIt;
      inp.addEventListener("keydown", e => { if(e.key === "Enter") tryIt(); });
      setTimeout(() => inp.focus(), 50);
    }
    else if(pz.type === "pick"){
      const row = document.createElement("div"); row.className = "row"; row.style.flexDirection = "column";
      pz.options.forEach((o, i) => {
        const b = document.createElement("button"); b.className = "chip"; b.innerHTML = `<span class="n">${i+1}</span>${fmt(o.t)}`;
        b.onclick = () => { if(o.correct){ win(); } else { fail(); if(o.why) say(o.why, "bad"); b.classList.add("done"); } };
        row.appendChild(b);
      });
      body.appendChild(row);
    }
    else if(pz.type === "multi"){
      const sel = new Set();
      const row = document.createElement("div"); row.className = "row"; row.style.flexDirection = "column";
      pz.options.forEach((o, i) => {
        const b = document.createElement("button"); b.className = "chip"; b.innerHTML = `<span class="n">${i+1}</span>${fmt(o.t)}`;
        b.onclick = () => { if(sel.has(i)){ sel.delete(i); b.classList.remove("on"); } else { sel.add(i); b.classList.add("on"); } };
        row.appendChild(b);
      });
      const go_ = document.createElement("button"); go_.className = "pbtn"; go_.textContent = pz.submit || "Confirm";
      go_.onclick = () => {
        const want = new Set(pz.options.map((o, i) => o.correct ? i : -1).filter(i => i >= 0));
        const ok = want.size === sel.size && [...want].every(i => sel.has(i));
        if(ok) win(); else fail();
      };
      body.appendChild(row); body.appendChild(go_);
    }
    else if(pz.type === "order"){
      const shuffled = pz.items.map((t, i) => ({t, i})).sort(() => Math.random() - .5);
      const seq = [];
      const pool = document.createElement("div"); pool.className = "row"; pool.style.flexDirection = "column";
      const out = document.createElement("div"); out.className = "seq";
      const draw = () => {
        pool.innerHTML = ""; out.innerHTML = seq.length ? "" : `<span class="msg">Click items in order. Click a placed item to remove it.</span>`;
        shuffled.forEach(o => {
          if(seq.includes(o)) return;
          const b = document.createElement("button"); b.className = "chip"; b.innerHTML = fmt(o.t);
          b.onclick = () => { seq.push(o); draw(); };
          pool.appendChild(b);
        });
        seq.forEach((o, k) => {
          const b = document.createElement("button"); b.className = "chip on"; b.innerHTML = `<span class="n">${k+1}</span>${fmt(o.t)}`;
          b.onclick = () => { seq.splice(k, 1); draw(); };
          out.appendChild(b);
        });
        chk.disabled = seq.length !== pz.items.length;
      };
      const chk = document.createElement("button"); chk.className = "pbtn"; chk.textContent = pz.submit || "Check order";
      chk.onclick = () => { if(seq.every((o, k) => o.i === k)) win(); else { fail(); } };
      body.appendChild(out); body.appendChild(pool); body.appendChild(chk);
      draw();
    }
    else if(pz.type === "search"){
      const found = new Set();
      const need = pz.need || pz.spots.length;
      const row = document.createElement("div"); row.className = "row"; row.style.flexDirection = "column";
      const reveal = document.createElement("div");
      const cont = document.createElement("button"); cont.className = "pbtn"; cont.textContent = pz.doneLabel || "Done searching";
      const upd = () => { cont.disabled = found.size < need; say(`${found.size} of ${pz.spots.length} examined${need < pz.spots.length ? ` · ${need} needed` : ""}`); };
      pz.spots.forEach((sp, i) => {
        const b = document.createElement("button"); b.className = "chip"; b.innerHTML = `<span class="n">${i+1}</span>${fmt(sp.t)}`;
        b.onclick = () => {
          reveal.innerHTML = `<p class="spot-text">${fmt(val(sp.text))}</p>`;
          if(!found.has(i)){ found.add(i); b.classList.add("done"); applyFx(sp.fx); if(sp.clue) applyFx({clue:sp.clue}); refreshJournal(); Sound.click(); }
          upd();
        };
        row.appendChild(b);
      });
      cont.onclick = () => go(pz.to, pz.fx);
      body.appendChild(row); body.appendChild(reveal); body.appendChild(cont);
      upd();
    }
    else if(pz.type === "tune"){
      const min = pz.min, max = pz.max, stepv = pz.step || 0.005;
      body.innerHTML = `<div class="dial"><div class="freq" id="fq"></div><input type="range" id="fr" min="${min}" max="${max}" step="${stepv}" value="${pz.startAt != null ? pz.startAt : min}"><div class="meterbar"><i id="fm"></i></div></div><div class="row"><button class="pbtn" id="lock">Lock frequency</button></div>`;
      const fr = body.querySelector("#fr"), fq = body.querySelector("#fq"), fm = body.querySelector("#fm");
      const upd = () => { const v = parseFloat(fr.value); fq.textContent = v.toFixed(pz.decimals != null ? pz.decimals : 3) + " " + (pz.unit || "MHz"); const d = Math.abs(v - pz.target); const s = clamp(1 - d / ((max - min) * 0.25), 0, 1); fm.style.width = (s * 100) + "%"; Sound.hiss(s); };
      fr.addEventListener("input", upd); upd();
      body.querySelector("#lock").onclick = () => { if(Math.abs(parseFloat(fr.value) - pz.target) <= (pz.tol || 0.01)) win(); else fail(); };
    }
    if(pz.giveUp === 0) addGiveUp();
  }
};

/* ---------- combat (Part 2) ---------- */
const WEAPONS = {
  "M4":{ammo:"rifle", use:3, acc:.82, dmg:[22,34], label:"M4 (burst)"},
  "Shotgun":{ammo:"shells", use:1, acc:.74, dmg:[34,52], label:"Shotgun"},
  "Desert Eagle":{ammo:"pistol", use:1, acc:.68, dmg:[24,36], label:"Desert Eagle"}
};
const Combat = {
  C:null, snap:null,
  start(act, cfg){
    cfg = val(cfg);
    this.snap = clone(S);
    restock();
    const C = this.C = {cfg, foes: cfg.enemies.map((e, i) => ({id:i, n:e.n, hp:e.hp || 50, max:e.hp || 50, boss:!!e.boss, alert:!!cfg.startAlert || !!e.alert, down:false})),
      mode: cfg.startAlert || cfg.noStealth ? "loud" : "stealth", noise:0, cover:false, distract:0, sel:null, log:[], everAlert:!!cfg.startAlert, round:1};
    if(cfg.solo){ S.active = cfg.solo; }
    if(S.hp[S.active] <= 0) S.active = S.active === "mani" ? "preethi" : "mani";
    this.act = act;
    this.log(cfg.intro || "Contact.");
    this.draw();
  },
  log(t){ this.C.log.unshift(t); this.C.log = this.C.log.slice(0, 30); },
  alive(){ return this.C.foes.filter(f => !f.down); },
  pcs(){ const c = this.C.cfg.solo; return c ? [c] : ["mani","preethi"]; },
  draw(){
    const C = this.C, cfg = C.cfg;
    const foes = C.foes.map(f => `<button class="foe ${f.down ? "down" : ""} ${C.sel === f.id ? "sel" : ""}" data-f="${f.id}" ${f.down ? "disabled" : ""}>
      <span>${esc(f.n)}${f.boss ? " ★" : ""}</span><span class="st ${f.alert ? "alert" : "unaware"}">${f.down ? "down" : f.alert ? "alert" : "unaware"}</span><span class="hpbar"><i style="width:${Math.max(0, f.hp) / f.max * 100}%"></i></span></button>`).join("");
    const pcs = this.pcs().map(c => `<button class="pc ${S.active === c ? "on" : ""} ${S.hp[c] <= 0 ? "down" : ""}" data-pc="${c}">
      <span class="nm">${c === "mani" ? "Mani" : "Preethi"}</span><span class="hpbar"><i style="width:${Math.max(0, S.hp[c])}%"></i></span>
      <span class="gear">${S.hold[c] === "big" ? S.big[c] : "Desert Eagle"} · HP ${Math.max(0, S.hp[c])} · grenades ${S.grenades[c]}</span></button>`).join("");
    const dots = Array.from({length:5}, (_, i) => `<span class="${i < C.noise ? "on" : ""}"></span>`).join("");
    const w = this.weapon();
    const anyUnaware = this.alive().some(f => !f.alert);
    const stealth = C.mode === "stealth";
    const actsStealth = `
      <button data-a="takedown" ${anyUnaware ? "" : "disabled"}>Silent takedown</button>
      <button data-a="distract">Distract</button>
      <button data-a="hide">Hide and wait</button>
      ${S.flags.disguise ? `<button data-a="disguise" ${anyUnaware ? "" : "disabled"}>Walk past in disguise</button>` : ""}`;
    const actsLoud = `
      <button data-a="fire" ${S.ammo[w.ammo] >= w.use ? "" : "disabled"}>Fire ${esc(w.label)} (${S.ammo[w.ammo]})</button>
      <button data-a="grenade" ${S.grenades[S.active] > 0 ? "" : "disabled"}>Grenade (${S.grenades[S.active]})</button>
      <button data-a="cover">Take cover</button>
      <button data-a="treat" ${(S.medkits > 0 || S.active === "preethi") ? "" : "disabled"}>Treat wounds${S.active === "preethi" ? "" : ` (${S.medkits})`}</button>`;
    this.act.innerHTML = `<div class="combat">
      <div class="cb-head"><h4>${esc(cfg.title || "Encounter")}</h4>
        <div class="mode"><button data-m="stealth" class="${stealth ? "on" : ""}" ${C.everAlert && !anyUnaware ? "disabled" : ""}>Stealth</button><button data-m="loud" class="${stealth ? "" : "on"}">Aggressive</button></div></div>
      ${cfg.note ? `<div class="msg">${fmt(cfg.note)}</div>` : ""}
      <div class="foes">${foes}</div>
      <div class="noise">Noise <span class="dots">${dots}</span>${C.cover ? " · in cover" : ""}</div>
      <div class="party">${pcs}</div>
      <div class="acts">${stealth ? actsStealth : actsLoud}
        ${this.pcs().length > 1 ? `<button data-a="switch">Switch to ${S.active === "mani" ? "Preethi" : "Mani"}</button>` : ""}
        <button data-a="swap">${S.hold[S.active] === "big" ? "Draw Desert Eagle" : "Draw " + S.big[S.active]}</button>
        ${this.pcs().length > 1 ? `<button data-a="trade">Trade big guns</button>` : ""}
      </div>
      <div class="cblog">${C.log.map(l => `<div>${fmt(l)}</div>`).join("")}</div>
    </div>`;
    this.act.querySelectorAll("[data-f]").forEach(b => b.onclick = () => { C.sel = +b.dataset.f; this.draw(); });
    this.act.querySelectorAll("[data-pc]").forEach(b => b.onclick = () => { if(S.hp[b.dataset.pc] > 0){ S.active = b.dataset.pc; this.draw(); } });
    this.act.querySelectorAll("[data-m]").forEach(b => b.onclick = () => { C.mode = b.dataset.m; this.draw(); });
    this.act.querySelectorAll("[data-a]").forEach(b => b.onclick = () => this.action(b.dataset.a));
    refreshJournal();
  },
  weapon(){ const c = S.active; return WEAPONS[S.hold[c] === "big" ? S.big[c] : "Desert Eagle"]; },
  target(){ const C = this.C; let t = C.foes.find(f => f.id === C.sel && !f.down); if(!t){ t = this.alive()[0]; C.sel = t ? t.id : null; } return t; },
  name(){ return S.active === "mani" ? "Mani" : "Preethi"; },
  action(a){
    const C = this.C; const who = this.name();
    let free = false;
    if(a === "switch"){ const o = S.active === "mani" ? "preethi" : "mani"; if(S.hp[o] > 0){ S.active = o; } free = true; }
    else if(a === "swap"){ S.hold[S.active] = S.hold[S.active] === "big" ? "pistol" : "big"; this.log(`${who} switches weapons.`); free = true; }
    else if(a === "trade"){ const t = S.big.mani; S.big.mani = S.big.preethi; S.big.preethi = t; this.log(`They trade big guns. Mani: ${S.big.mani}. Preethi: ${S.big.preethi}.`); free = true; }
    else if(a === "takedown"){
      const t = (() => { const s = C.foes.find(f => f.id === C.sel && !f.down && !f.alert); return s || this.alive().find(f => !f.alert); })();
      if(t){
        let p = (t.boss ? .45 : .82) - C.noise * .1 + C.distract * .15 + (S.flags.disguise ? .08 : 0) + (C.cfg.stealthBonus || 0);
        C.distract = 0;
        if(Math.random() < p){ t.down = true; t.hp = 0; this.log(`${who} takes down ${t.n} without a sound.`); Sound.thud(); }
        else { t.alert = true; C.noise = clamp(C.noise + 2, 0, 5); this.log(`${t.n} turns at the last second. Alert!`); Sound.bad(); }
      }
    }
    else if(a === "distract"){ C.noise = clamp(C.noise - 1, 0, 5); C.distract = 1; this.log(`${who} throws something into the dark. Heads turn the other way.`); }
    else if(a === "hide"){ C.noise = clamp(C.noise - 2, 0, 5); this.log(`${who} stays still and lets the patrol pass.`); }
    else if(a === "disguise"){
      const t = this.alive().find(f => !f.alert);
      if(Math.random() < .7 - C.noise * .08){ t.down = true; t.hp = 0; this.log(`In the hunter's whites, ${who} walks right up to ${t.n} and puts him down.`); }
      else { t.alert = true; C.noise = clamp(C.noise + 2, 0, 5); this.log(`${t.n} looks too closely at the disguise. Alert!`); }
    }
    else if(a === "fire"){
      const w = this.weapon(), t = this.target();
      if(t){
        S.ammo[w.ammo] -= w.use;
        this.alertAll(`The shot rings out.`);
        let acc = w.acc - (t.boss ? .1 : 0) + (C.cover ? -.05 : 0);
        if(Math.random() < acc){ const d = rnd(w.dmg[0], w.dmg[1]); t.hp -= d; this.log(`${who} hits ${t.n} with the ${w.label} (${d}).`); if(t.hp <= 0){ t.down = true; this.log(`${t.n} goes down.`); } Sound.shot(); }
        else { this.log(`${who} misses ${t.n}.`); Sound.shot(); }
      }
      C.cover = false;
    }
    else if(a === "grenade"){
      S.grenades[S.active]--;
      this.alertAll(`${who} pulls the pin.`);
      this.alive().forEach(f => { const d = f.boss ? rnd(22,32) : rnd(38,60); f.hp -= d; if(f.hp <= 0) f.down = true; });
      this.log(`The grenade blows. ${this.alive().length ? "Some of them are still standing." : "Silence after."}`);
      Sound.boom(); C.cover = false;
    }
    else if(a === "cover"){ C.cover = true; this.log(`${who} gets behind cover.`); }
    else if(a === "treat"){
      const target = this.pcs().filter(c => S.hp[c] > 0).sort((x, y) => S.hp[x] - S.hp[y])[0];
      const amt = S.active === "preethi" ? 32 : 24;
      if(S.active !== "preethi") S.medkits--;
      S.hp[target] = clamp(S.hp[target] + amt, 0, 100);
      this.log(`${who} patches up ${target === "mani" ? "Mani" : "Preethi"} (+${amt}).`);
    }
    if(this.checkEnd()) return;
    if(!free) this.enemyTurn();
    if(this.checkEnd()) return;
    this.draw();
  },
  alertAll(msg){ const C = this.C; if(this.alive().some(f => !f.alert)){ this.log(msg + " Everyone knows they're here now."); } this.alive().forEach(f => f.alert = true); C.everAlert = true; C.mode = "loud"; C.noise = 5; },
  enemyTurn(){
    const C = this.C;
    const alive = this.alive();
    // unaware enemies may notice
    let noticed = false;
    alive.filter(f => !f.alert).forEach(f => { if(Math.random() < .08 + C.noise * .11){ f.alert = true; noticed = true; this.log(`${f.n} spots movement.`); } });
    if(noticed){ this.alertAll(`A shout goes up.`); }
    alive.filter(f => f.alert).forEach(f => {
      const targets = this.pcs().filter(c => S.hp[c] > 0);
      if(!targets.length) return;
      const c = targets[Math.floor(Math.random() * targets.length)];
      const p = C.cover && c === S.active ? .22 : .44;
      if(Math.random() < p){ const d = f.boss ? rnd(14,24) : rnd(7,14); S.hp[c] = Math.max(0, S.hp[c] - d); this.log(`${f.n} hits ${c === "mani" ? "Mani" : "Preethi"} (${d}).`); }
      else this.log(`${f.n} fires and misses.`);
    });
    if(!C.everAlert && C.noise > 0 && Math.random() < .3) C.noise--;
    if(S.hp[S.active] <= 0){ const o = this.pcs().find(c => S.hp[c] > 0); if(o){ S.active = o; this.log(`${o === "mani" ? "Mani" : "Preethi"} keeps fighting alone.`); } }
    C.round++;
  },
  checkEnd(){
    const C = this.C, cfg = C.cfg;
    if(!this.alive().length){
      const clean = !C.everAlert;
      this.pcs().forEach(c => { S.hp[c] = Math.max(S.hp[c], 35); });
      if(clean){ S.ammo.rifle += 12; S.ammo.pistol += 6; S.ammo.shells += 3; S.flags["clean_" + (cfg.id || S.scene)] = true; }
      const out = clean ? (cfg.cleanMsg || "Clean. Nobody ever knew you were there.") : (cfg.winMsg || "It's over. For now.");
      this.act.innerHTML = `<div class="combat"><div class="cb-head"><h4>${esc(cfg.title || "Encounter")} · cleared</h4></div><p style="margin:0">${fmt(out)}${clean ? " <span class='msg ok'>Stealth bonus: extra ammunition.</span>" : ""}</p><div class="choices"><button class="choice cont" id="choice-0">Continue</button></div></div>`;
      Sound.good();
      $("#choice-0").onclick = () => go(clean && cfg.cleanTo ? cfg.cleanTo : cfg.to, cfg.fx);
      keyHandler = e => { if(e.key === "Enter" || e.key === "1") $("#choice-0").click(); };
      refreshJournal(); persist();
      return true;
    }
    if(this.pcs().every(c => S.hp[c] <= 0)){
      this.act.innerHTML = `<div class="combat"><div class="cb-head"><h4>Down</h4></div><p style="margin:0">${fmt(cfg.loseMsg || "Everything goes white and cold. Not like this.")}</p><div class="choices"><button class="choice cont" id="choice-0">Try again</button></div></div>`;
      Sound.bad();
      $("#choice-0").onclick = () => { S = clone(this.snap); persist(); render(false); };
      keyHandler = e => { if(e.key === "Enter" || e.key === "1") $("#choice-0").click(); };
      return true;
    }
    return false;
  }
};

/* ---------- episode end, endings ---------- */
function renderEpEnd(act, sc){
  const pr = prog(P.id);
  if(!pr.done.includes(S.ep)) pr.done.push(S.ep);
  saveProg();
  const next = P.episodes[S.ep];
  const wrap = document.createElement("div");
  wrap.className = "choices";
  wrap.innerHTML = `<div class="kicker" style="margin:10px 0 4px">Episode ${S.ep} complete</div>` +
    (next ? `<button class="choice cont" id="choice-0">Episode ${S.ep+1} · ${esc(next.title)}</button>` : "") +
    `<button class="choice cont" id="choice-1">Episode select</button>`;
  act.appendChild(wrap);
  if(next) $("#choice-0").onclick = () => go(next.start);
  $("#choice-1").onclick = () => episodeScreen(P.id);
  keyHandler = e => { if((e.key === "Enter" || e.key === "1") && next) $("#choice-0").click(); };
}
function renderEnding(sc){
  screen = "end";
  const pr = prog(P.id);
  const e = P.endings ? P.endings.find(x => x.id === sc.ending) : {id:sc.ending, name:sc.title || "The End"};
  if(e && !pr.endings.includes(e.id)) pr.endings.push(e.id);
  if(!pr.done.includes(S.ep)) pr.done.push(S.ep);
  saveProg();
  $("#clock").textContent = val(sc.time) || "";
  if(sc.radio) Sound.burst();
  root.innerHTML = `<section class="screen">
    <div class="kicker">${esc(sc.kicker || (P.endings ? `Ending · ${P.name}` : P.name))}</div>
    <h2>${esc(e ? e.name : "The End")}</h2>
    <div class="text" id="text" style="max-width:42rem"></div>
    <div id="after" hidden>
      ${P.endings ? `<ul class="endlist">${P.endings.map(x => `<li class="${x.id === e.id ? "now" : pr.endings.includes(x.id) ? "got" : ""}">${pr.endings.includes(x.id) ? esc(x.name) : "? ? ?"}</li>`).join("")}</ul>` : ""}
      <div class="row" style="display:flex;gap:10px;flex-wrap:wrap;margin-top:24px">
        ${sc.nextPart && PARTS[sc.nextPart] ? `<button class="big" id="nextPart">Play ${esc(PARTS[sc.nextPart].name)}</button>` : ""}
        <button class="big ghost" id="toEps">Episode select</button>
        <button class="big ghost" id="toTitle">Title screen</button>
      </div>
      ${P.endings ? `<p class="howto">${pr.endings.length} of ${P.endings.length} endings found. Earlier choices decide which one you reach: who you trust, what proof you keep, who you protect, and how honest you are.</p>` : ""}
    </div>
  </section>`;
  typeOut(val(sc.lines) || [], true, () => {
    $("#after").hidden = false;
    $("#toEps").onclick = () => episodeScreen(P.id);
    $("#toTitle").onclick = titleScreen;
    const np = $("#nextPart"); if(np) np.onclick = () => startPart(sc.nextPart, true);
  });
}

/* ---------- screens ---------- */
function titleScreen(){
  stopAll(); screen = "title";
  setPart(null); document.documentElement.removeAttribute("data-part"); Weather.mode("fog");
  $("#partTag").textContent = ""; $("#clock").textContent = "";
  const card = pid => {
    const p = PARTS[pid]; if(!p) return "";
    const pr = prog(pid), sv = LS.get(saveKey(pid));
    return `<div class="partcard ${pid}">
      <span class="pn">Part ${pid === "p1" ? "1" : "2"} · ${p.episodes.length} episodes</span>
      <h3>${esc(p.title)}</h3>
      <p>${esc(p.blurb)}</p>
      <p class="msg">${pr.done.length} of ${p.episodes.length} episodes complete${p.endings ? ` · ${pr.endings.length}/${p.endings.length} endings` : ""}</p>
      <div class="row">${sv && sv.scene ? `<button class="big" data-cont="${pid}">Continue</button>` : `<button class="big" data-new="${pid}">Begin</button>`}
      <button class="big ghost" data-eps="${pid}">Episodes</button></div>
    </div>`;
  };
  root.innerHTML = `<section class="screen">
    <div class="kicker">A story-choice thriller in Ontario</div>
    <h1>Out of Town</h1>
    <p class="lede">Mani and Nila came from Vellore to start new lives in Canada. Every time they leave town, something is waiting for them.</p>
    <div class="parts">${card("p1")}${card("p2")}</div>
    <p class="howto">Click a choice or press 1–4. Click the text or press space to skip typing. A red bar means a timed decision.<br>
    Family conversations are in Tanglish with English subtitles. Use "Subs" in the top bar to change subtitles.<br>
    Clues and proof collect in your journal and unlock new paths. Your progress saves in this browser.</p>
  </section>`;
  root.querySelectorAll("[data-new]").forEach(b => b.onclick = () => startPart(b.dataset.new, true));
  root.querySelectorAll("[data-cont]").forEach(b => b.onclick = () => startPart(b.dataset.cont, false));
  root.querySelectorAll("[data-eps]").forEach(b => b.onclick = () => episodeScreen(b.dataset.eps));
}
function startPart(pid, fresh){
  setPart(pid);
  if(fresh){ S = freshState(pid); go(P.episodes[0].start); }
  else { S = LS.get(saveKey(pid)); if(!S || !S.scene){ S = freshState(pid); go(P.episodes[0].start); } else render(false); }
}
function episodeScreen(pid){
  stopAll(); screen = "eps";
  setPart(pid);
  const pr = prog(pid);
  $("#clock").textContent = "";
  root.innerHTML = `<section class="screen">
    <div class="kicker">${esc(P.name)}</div>
    <h2>Episodes</h2>
    <p class="lede">${esc(P.blurb)}</p>
    <ul class="eplist">${P.episodes.map((e, i) => {
      const open = SETTINGS.unlockAll || i === 0 || pr.done.includes(i) || pr.done.includes(i+1);
      return `<li><button data-ep="${i}" ${open ? "" : "disabled"}><span class="en">Episode ${i+1}${pr.done.includes(i+1) ? " · complete" : ""}</span><span class="et">${esc(e.title)}</span><span class="es">${esc(e.blurb || "")}</span></button></li>`;
    }).join("")}</ul>
    <div style="display:flex;gap:10px;flex-wrap:wrap;margin-top:24px"><button class="big ghost" id="back">Title screen</button></div>
    <p class="howto">Starting an episode from here uses your choices from your last run of this part. If you never played the earlier episodes, sensible defaults are used.</p>
  </section>`;
  root.querySelectorAll("[data-ep]").forEach(b => b.onclick = () => {
    const i = +b.dataset.ep;
    const sv = LS.get(saveKey(pid));
    S = sv && sv.vars && sv.vars._epStart && sv.vars._epStart.ep === i+1 ? clone(sv.vars._epStart) : (sv ? clone(sv) : freshState(pid));
    if(!sv && P.defaultsFor) P.defaultsFor(S, i+1);
    else if(sv && P.defaultsFor && (sv.ep||1) < i+1) P.defaultsFor(S, i+1);
    S.part = pid;
    go(P.episodes[i].start);
  });
  $("#back").onclick = titleScreen;
}
function menuScreen(){
  stopAll(); screen = "menu";
  root.innerHTML = `<section class="screen">
    <div class="kicker">Menu</div>
    <h2>Settings</h2>
    <div class="settings">
      <label>Subtitles <select id="sSub"><option value="all">All lines</option><option value="tanglish">Tanglish lines only</option><option value="off">Off</option></select></label>
      <label>Text speed <select id="sSpeed"><option value="normal">Normal</option><option value="fast">Fast</option><option value="instant">Instant</option></select></label>
      <label>Unlock all episodes <input type="checkbox" id="sUnlock"></label>
    </div>
    <div style="display:flex;gap:10px;flex-wrap:wrap;margin-top:24px">
      ${S && S.scene && P ? `<button class="big" id="resume">Resume</button>` : ""}
      <button class="big ghost" id="title">Title screen</button>
      <button class="big ghost" id="reset">Erase saves</button>
    </div>
    <p class="msg" id="rmsg"></p>
  </section>`;
  $("#sSub").value = SETTINGS.subs; $("#sSpeed").value = SETTINGS.speed; $("#sUnlock").checked = SETTINGS.unlockAll;
  $("#sSub").onchange = e => { SETTINGS.subs = e.target.value; saveSettings(); syncSubBtn(); };
  $("#sSpeed").onchange = e => { SETTINGS.speed = e.target.value; saveSettings(); };
  $("#sUnlock").onchange = e => { SETTINGS.unlockAll = e.target.checked; saveSettings(); };
  const r = $("#resume"); if(r) r.onclick = () => { setPart(S.part); render(false); };
  $("#title").onclick = titleScreen;
  let armed = false;
  $("#reset").onclick = () => {
    if(!armed){ armed = true; $("#rmsg").textContent = "Click again to erase all saves and progress."; return; }
    ["p1","p2"].forEach(p => LS.del(saveKey(p))); PROG = {}; saveProg(); S = null; $("#rmsg").textContent = "Saves erased.";
  };
}
function syncSubBtn(){ const b = $("#subBtn"); b.textContent = "Subs: " + (SETTINGS.subs === "all" ? "all" : SETTINGS.subs === "off" ? "off" : "Tanglish"); b.setAttribute("aria-pressed", SETTINGS.subs !== "off"); }
$("#subBtn").onclick = () => { SETTINGS.subs = SETTINGS.subs === "all" ? "tanglish" : SETTINGS.subs === "tanglish" ? "off" : "all"; saveSettings(); syncSubBtn(); if(screen === "game"){ const sc = P.scenes[S.scene]; $("#text").innerHTML = (val(sc.lines) || []).map(r => val(r)).filter(r => r != null && r !== "").map(parseLine).map(L => lineHTML(L)).join(""); } };
$("#menuBtn").onclick = menuScreen;
$("#brandBtn").onclick = titleScreen;
let toastT;
function toast(msg){ const t = $("#toast"); t.textContent = msg; t.hidden = false; t.style.opacity = 1; clearTimeout(toastT); toastT = setTimeout(() => { t.style.opacity = 0; setTimeout(() => t.hidden = true, 400); }, 2400); }

/* ---------- sound (generated) ---------- */
const Sound = (() => {
  let ctx = null, master = null, on = false, noiseBuf = null, hissG = null;
  function init(){
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    master = ctx.createGain(); master.gain.value = 0; master.connect(ctx.destination);
    noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
    const d = noiseBuf.getChannelData(0); for(let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    const lp = ctx.createBiquadFilter(); lp.type = "lowpass"; lp.frequency.value = 220; lp.connect(master);
    [55, 55.6, 82.4].forEach((f, i) => { const o = ctx.createOscillator(); o.type = i === 2 ? "sine" : "sawtooth"; o.frequency.value = f; const g = ctx.createGain(); g.gain.value = i === 2 ? .05 : .06; o.connect(g); g.connect(lp); o.start(); });
    const lfo = ctx.createOscillator(); lfo.frequency.value = .07; const lg = ctx.createGain(); lg.gain.value = 90; lfo.connect(lg); lg.connect(lp.frequency); lfo.start();
    const n = ctx.createBufferSource(); n.buffer = noiseBuf; n.loop = true;
    const bp = ctx.createBiquadFilter(); bp.type = "bandpass"; bp.frequency.value = 500; bp.Q.value = .6;
    const wg = ctx.createGain(); wg.gain.value = .035; n.connect(bp); bp.connect(wg); wg.connect(master); n.start();
    const wl = ctx.createOscillator(); wl.frequency.value = .11; const wlg = ctx.createGain(); wlg.gain.value = 260; wl.connect(wlg); wlg.connect(bp.frequency); wl.start();
    const hn = ctx.createBufferSource(); hn.buffer = noiseBuf; hn.loop = true; const hf = ctx.createBiquadFilter(); hf.type = "highpass"; hf.frequency.value = 1800; hissG = ctx.createGain(); hissG.gain.value = 0; hn.connect(hf); hf.connect(hissG); hissG.connect(master); hn.start();
  }
  function toggle(){ if(!ctx) init(); on = !on; ctx.resume(); master.gain.cancelScheduledValues(ctx.currentTime); master.gain.linearRampToValueAtTime(on ? .6 : 0, ctx.currentTime + .8); return on; }
  function noise(freq, q, vol, dur){ if(!on) return; const s = ctx.createBufferSource(); s.buffer = noiseBuf; const f = ctx.createBiquadFilter(); f.type = "bandpass"; f.frequency.value = freq; f.Q.value = q; const g = ctx.createGain(); const t = ctx.currentTime; g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(.001, t + dur); s.connect(f); f.connect(g); g.connect(master); s.start(t); s.stop(t + dur + .05); }
  function tone(f, dur, vol, type){ if(!on) return; const o = ctx.createOscillator(); o.type = type || "sine"; o.frequency.value = f; const g = ctx.createGain(); const t = ctx.currentTime; g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(.001, t + dur); o.connect(g); g.connect(master); o.start(t); o.stop(t + dur); }
  return {
    toggle,
    burst(){ noise(2200, .5, .2, 1.3); },
    beat(){ tone(52, .25, .5); },
    thud(){ tone(40, .6, .6); tone(80, .3, .2, "triangle"); },
    click(){ tone(900, .04, .05, "square"); },
    good(){ tone(660, .15, .12, "triangle"); setTimeout(() => tone(880, .2, .1, "triangle"), 120); },
    bad(){ tone(140, .3, .2, "sawtooth"); },
    shot(){ noise(900, .4, .7, .25); tone(70, .2, .4); },
    boom(){ noise(200, .3, 1, 1.2); tone(35, 1, .7); },
    hiss(level){ if(!on || !hissG) return; hissG.gain.setTargetAtTime(.12 * (1 - level), ctx.currentTime, .05); setTimeout(() => { if(hissG) hissG.gain.setTargetAtTime(0, ctx.currentTime, .3); }, 600); }
  };
})();
$("#soundBtn").onclick = e => { const on = Sound.toggle(); e.currentTarget.setAttribute("aria-pressed", on); e.currentTarget.textContent = on ? "Sound on" : "Sound off"; };

/* ---------- weather ---------- */
const Weather = (() => {
  const c = $("#weather"), x = c.getContext("2d");
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  let W, H, mode = "fog", puffs = [], flakes = [], raf = null;
  function size(){ W = c.width = innerWidth; H = c.height = innerHeight; }
  size(); addEventListener("resize", size);
  for(let i = 0; i < 14; i++) puffs.push({x:Math.random(), y:.3 + Math.random() * .8, r:.25 + Math.random() * .35, v:(Math.random() * .4 + .15) / 4000});
  for(let i = 0; i < 140; i++) flakes.push({x:Math.random(), y:Math.random(), r:.6 + Math.random() * 1.8, v:.0006 + Math.random() * .0016, d:Math.random() * 6.28});
  function draw(){
    x.clearRect(0, 0, W, H);
    if(mode === "fog"){
      puffs.forEach(p => { p.x += p.v; if(p.x > 1.4) p.x = -.4; const cx = p.x * W, cy = p.y * H, r = p.r * Math.max(W, H); const g = x.createRadialGradient(cx, cy, 0, cx, cy, r); g.addColorStop(0, "rgba(150,165,168,0.09)"); g.addColorStop(1, "rgba(150,165,168,0)"); x.fillStyle = g; x.fillRect(cx - r, cy - r, r * 2, r * 2); });
    } else {
      x.fillStyle = "rgba(220,235,240,0.32)";
      flakes.forEach(f => { f.y += f.v; f.d += .01; f.x += Math.sin(f.d) * .0004; if(f.y > 1.02){ f.y = -.02; f.x = Math.random(); } x.beginPath(); x.arc(f.x * W, f.y * H, f.r, 0, 6.28); x.fill(); });
    }
    if(!reduce) raf = requestAnimationFrame(draw);
  }
  draw();
  return { mode(m){ mode = m || "fog"; if(reduce) draw(); } };
})();

/* ---------- boot ---------- */
syncSubBtn();
function start(data){
  if(data && data.S && data.S.scene && PARTS[data.S.part]){ S = data.S; setPart(S.part); render(false); }
  else titleScreen();
}
window.claude?.hot?.snapshot?.(() => ({S: screen === "game" ? S : null}));
window.claude?.hot?.ready ? window.claude.hot.ready(start) : start(window.claude?.hot?.data ?? {});
window.OTT_DEBUG = { go: id => go(id), state: () => S, parts: PARTS, setS: s => { S = s; setPart(s.part); } };
})();
