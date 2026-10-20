/* Exports prototype scenes to data/story/ for Unreal.
 * Writes, per part:  <pid>_scenes.json  (full static structure)
 *                    <pid>_lines.csv    (DataTable rows for FOOTDialogueLine)
 *                    <pid>_choices.csv  (DataTable rows for FOOTChoice)
 * Lines, choices or targets computed at runtime from story state are marked "dynamic": true
 * and exported using a default state; implement them in Blueprint/C++ from the prototype source. */
const fs = require('fs'), vm = require('vm'), path = require('path');
const root = path.join(__dirname, '..');
const dir = path.join(root, 'prototype', 'browser');
const out = path.join(root, 'data', 'story');
fs.mkdirSync(out, { recursive: true });

const ctx = { window: {} }; vm.createContext(ctx);
const files = ['part1.js', ...[1,2,3,4,5,6,7,8].map(i => `p1e${i}.js`), 'part2.js', ...[1,2,3,4,5,6,7,8].map(i => `p2e${i}.js`)];
for (const f of files) vm.runInContext(fs.readFileSync(path.join(dir, f), 'utf8'), ctx, { filename: f });
const PARTS = ctx.window.OTT_PARTS;

function defaultState(pid) {
  const P = PARTS[pid];
  const S = { part: pid, flags: {}, vars: { rounds: 6, price: 26, brian: 2, rao: 2, cb: 0, interview: 2, bites: 0, chase: 0, trips: 0, dunnScore: 2, failAt: 'e8_offer' },
    trust: {}, danger: 0, clues: Object.keys(P.clues), hp: { mani: 100, preethi: 100 }, ammo: { rifle: 100, shells: 30, pistol: 40 },
    grenades: { mani: 2, preethi: 2 }, trunk: 4, medkits: 2, big: { mani: 'M4', preethi: 'Shotgun' }, hold: { mani: 'big', preethi: 'big' }, health: 50, active: 'mani' };
  Object.keys(P.people).forEach(k => S.trust[k] = 0);
  return S;
}
const isFn = v => typeof v === 'function';
const val = (v, S) => isFn(v) ? v(S) : v;

// "NAME (TAG): text || subtitle"  or  "~narration"
function parseLine(raw) {
  if (raw.startsWith('~')) return { speaker: '', channel: '', text: raw.slice(1).trim(), subtitle: '', narration: true };
  const m = raw.match(/^([A-Z0-9 .'\-]+?)(?:\s*\(([^)]+)\))?:\s*([\s\S]*)$/);
  if (!m) return { speaker: '', channel: '', text: raw, subtitle: '', narration: true };
  const [text, subtitle] = m[3].split('||').map(s => s.trim());
  return { speaker: m[1].trim(), channel: (m[2] || '').trim(), text, subtitle: subtitle || '', narration: false };
}

const csv = v => { const s = String(v ?? ''); return /[",\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; };
const arr = a => a && a.length ? '(' + a.map(x => '"' + x + '"').join(',') + ')' : '()';

for (const pid of Object.keys(PARTS)) {
  const P = PARTS[pid], S = defaultState(pid);
  const scenes = {}, lineRows = [], choiceRows = [];
  for (const [id, sc] of Object.entries(P.scenes)) {
    const rec = { id, ep: sc.ep, place: val(sc.place, S) || '', time: val(sc.time, S) || '', lines: [], choices: [] };
    if (isFn(sc.lines)) rec.dynamicLines = true;
    (val(sc.lines, S) || []).forEach((l, i) => {
      const dyn = isFn(l) || isFn(sc.lines);
      const t = val(l, S); if (typeof t !== 'string') return;
      const p = parseLine(t); if (dyn) p.dynamic = true;
      rec.lines.push(p);
      lineRows.push([`${id}_${String(i).padStart(3, '0')}`, id, i, p.speaker, p.channel, p.text, p.subtitle, p.narration ? 'True' : 'False']);
    });
    if (sc.next) rec.next = val(sc.next, S), isFn(sc.next) && (rec.nextDynamic = true);
    (val(sc.choices, S) || []).forEach((c, i) => {
      const ch = { label: val(c.label ?? c.t, S) || '', sub: val(c.sub, S) || '', to: val(c.to, S) || '' };
      if (isFn(c.to)) ch.dynamicTarget = true;
      if (c.req) ch.hasCondition = true;
      if (c.fx) ch.hasEffects = true;
      if (c.once) ch.once = true;
      rec.choices.push(ch);
      choiceRows.push([`${id}_c${i}`, id, ch.label, ch.sub, ch.to, arr([]), arr([]), c.lock ? val(c.lock, S) : '', sc.timer ? val(sc.timer.secs, S) : 0]);
    });
    if (sc.timer) rec.timer = { secs: val(sc.timer.secs, S), to: val(sc.timer.to, S) };
    const pz = val(sc.puzzle, S); if (pz) rec.puzzle = { type: pz.type, title: pz.title || '', to: val(pz.to, S) };
    const cb = val(sc.combat, S); if (cb) rec.combat = { to: cb.to, cleanTo: cb.cleanTo || null };
    if (sc.epEnd) rec.episodeEnd = true;
    if (sc.ending) rec.ending = val(sc.ending, S);
    scenes[id] = rec;
  }
  const meta = { id: P.id, name: P.name, episodes: P.episodes, people: P.people, clues: P.clues };
  fs.writeFileSync(path.join(out, `${pid}_scenes.json`), JSON.stringify({ part: meta, scenes }, null, 2));
  fs.writeFileSync(path.join(out, `${pid}_lines.csv`), '﻿' + [['Name', 'SceneId', 'Order', 'Speaker', 'Channel', 'Text', 'Subtitle', 'bIsNarration'], ...lineRows].map(r => r.map(csv).join(',')).join('\n'));
  fs.writeFileSync(path.join(out, `${pid}_choices.csv`), '﻿' + [['Name', 'SceneId', 'Label', 'SubLabel', 'TargetScene', 'RequiredFlags', 'RequiredClues', 'LockedReason', 'TimerSeconds'], ...choiceRows].map(r => r.map(csv).join(',')).join('\n'));
  console.log(pid, 'scenes', Object.keys(scenes).length, 'lines', lineRows.length, 'choices', choiceRows.length);
}
