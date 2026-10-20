# Browser prototype

The playable reference build of **Part 1: Greyhaven** and **Part 2: Red Lake** (362 scenes, both parts, all endings).

## Run
```bash
python3 -m http.server 8000   # from this folder
# open http://localhost:8000
```
Opening `index.html` directly also works in most browsers.

## Files
| File | Contents |
| --- | --- |
| `index.html` | Page, styles, script order |
| `engine.js` | Story engine: lines, choices, timers, puzzles, combat, journal, saves, audio, weather |
| `part1.js`, `part2.js` | Part definitions: episodes, people, clues, default state |
| `p1e1.js` … `p1e8.js` | Part 1 scenes per episode |
| `p2e1.js` … `p2e8.js` | Part 2 scenes per episode |

## Line format
- `"~text"` — narration / stage direction.
- `"NAME: text || subtitle"` — speech. `"NAME (ON RADIO): …"` adds a channel tag.
- Lines, `next`, choice targets and conditions can be functions of state `S`.

## Scene fields
`ep`, `place`, `time`, `lines`, `next` or `choices` (`t`, `sub`, `to`, `req`, `fx`, `once`, `show`), `timer`, `puzzle` (`code`, `pick`, `multi`, `order`, `search`, `tune`), `combat`, `fx`, `epEnd`, `ending`.

After any change: `node tools/validate_prototype.js` from the repo root (must show `errors 0`).
