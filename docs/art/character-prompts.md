# Character sheet prompts

Prompts for ChatGPT image generation. The sheets are **modelling references**: they go into Blender as image planes (front, side, back) to build each character, then into Godot as glTF. So they must be orthographic, evenly lit and consistent, not pretty concept art.

Appearance details below follow the screenplays in `docs/story/` (canon). Anything marked *(design)* is an art choice not in the screenplay and can change.

## Workflow

1. **One chat per character.** Generate the **face sheet** first. When it's right, keep it.
2. In the same chat, attach the approved face sheet and generate the **turnaround**, then each **outfit variant** and the **expression sheet**. Always start with "Same person as the attached reference."
3. Paste the character's **identity line** unchanged in every prompt for that character. Change only the outfit line.
4. Save approved images to `docs/art/sheets/<character>/` as PNG (Git LFS), named `<character>_<part>_<sheet>.png`, e.g. `mani_p1_turnaround.png`, `nila_p1_face.png`.
5. Bring the sheets back here and we review them against canon, then fix proportions before modelling.

**Build order (vertical slice first, `docs/production/roadmap.md` M2):** Mani → Nila → Victor → Ruth → Gus → Tess → Hades silhouette → everyone else by priority (A, B, C in `docs/art/asset-list.md`).

## Style blocks (paste at the end of the prompt)

**[FACE]**
> Character face reference sheet for 3D modelling. Four views of the same head on one image, left to right: front, three-quarter left, left profile, three-quarter right. Head and shoulders, same scale and eye line in every view, neutral expression, mouth closed. Photorealistic, natural unretouched skin with pores and small imperfections, an ordinary person, not a model. Flat even studio light, no dramatic shadows, plain mid-grey background, no text, no logos, 16:9.

**[TURNAROUND]**
> Full-body character turnaround sheet for 3D modelling. The same person shown four times side by side: front, left side, back, three-quarter front. Orthographic view, no perspective distortion, standing in a relaxed A-pose (arms 45 degrees from the body, feet shoulder-width apart), same height and scale in all four views, feet on the same ground line, whole body visible from head to shoes. Photorealistic, realistic proportions, flat even studio light, no cast shadows, plain mid-grey background, no props unless listed, no text, no logos, 16:9.

**[OUTFIT]**
> Outfit reference sheet. The same person in the outfit described, front and back views in a relaxed A-pose, plus close-up callouts of fabric textures, shoes, and any accessories listed. Photorealistic, flat even studio light, plain mid-grey background, no text, no logos, 16:9.

**[EXPRESSIONS]**
> Facial expression sheet for 3D animation, the same person, front view, head and shoulders, six panels in a 3x2 grid: neutral, worried, afraid, angry, laughing, exhausted. Same lighting, scale and angle in every panel. Photorealistic, natural skin, plain mid-grey background, no text, 16:9.

**Prompt pattern:** `Same person as the attached reference. [IDENTITY]. [OUTFIT LINE]. [STYLE BLOCK]`

## Part 1 — Greyhaven

### Mani (29) · playable · priority A
**Identity:** South Indian Tamil man from Vellore, age 29, medium-brown skin, thick curly black hair, short at the sides, a moustache and short goatee with light stubble, thin metal double-bridge glasses, a small black hoop earring in each ear *(design, from the approved sheet)*, average build, 175 cm, thoughtful tired eyes, a careful, quiet face.
- **Main outfit:** dark grey hoodie under a navy winter jacket, dark jeans, brown leather boots, a backpack on one shoulder, a cheap black digital watch.
- **Wet/night variant (lake dive):** same, soaked, hair flat, jacket open.
- Sheets: FACE, TURNAROUND, OUTFIT ×2, EXPRESSIONS.
- **Approved:** `sheets/mani/mani_p1_face.png`, `mani_p1_turnaround.png`, `mani_p1_expressions.png` (2026-10-20).

### Nila (25) · priority A
**Identity:** South Indian Tamil woman, age 25, medium-brown skin, long black hair, small nose stud, expressive eyes, quick wide smile, slim, 160 cm, Mani's younger sister (same family resemblance: similar eyes and nose).
- **Main outfit (photos, flashbacks, Ep 1 video):** oversized mustard knit sweater, black jeans, a denim jacket with radio-station pins, over-ear headphones around her neck *(design)*, hair in a loose braid.
- **Found at the Pike Point tower:** thinner, hair tied back, a scrape across one cheek, the same denim jacket dirty and torn, holding a flare gun.
- Sheets: FACE, TURNAROUND, OUTFIT ×2, EXPRESSIONS.

### Victor Kessler (47) · priority A
**Identity:** White Canadian man, age 47, tall, 188 cm, well-groomed salt-and-pepper hair, neat short beard, a charming smile that doesn't reach his eyes.
- **Main outfit:** tailored charcoal wool coat over a quarter-zip sweater, dark trousers, polished shoes, a silver watch, leather gloves.
- **Tower variant (finale):** the same coat with mud on it, a pistol in one hand.
- **Prop sheet:** Midas, a large golden lancehead snake, coiled (separate image, no person).
- Sheets: FACE, TURNAROUND, OUTFIT ×2, EXPRESSIONS.

### Hades, silhouette (Part 1) · priority A
**Identity:** a tall man, 190 cm, in a long dark coat to below the knee, face never visible.
- **Prompt:** Full-body silhouette reference for 3D modelling: a tall man in a long dark wool coat, standing still, hands at his sides, front, side and back views, the face completely in shadow, no features visible. Plain mid-grey background, flat light, 16:9.
- Same coat and height as Mark Hayden in Part 2 — he is the same man. No hat *(the screenplay only says "a long coat")*.
- Sheets: TURNAROUND (silhouette only).

### Ruth Vane (64) · priority A
**Identity:** White woman, age 64, short cropped grey hair, weathered face, sharp eyes, gruff, sturdy, 165 cm.
- **Main outfit:** flannel shirt under a quilted vest, work jeans, boots, reading glasses on a chain. Props (separate callout): a police scanner, a pump shotgun.
- **Rescue variant (the skiff in the fog):** soaked, grey hair loose, shotgun at her shoulder.
- Sheets: FACE, TURNAROUND, OUTFIT ×2, EXPRESSIONS.

### Gus Pell (55) · priority A
**Identity:** White man, age 55, burly and heavyset, bald, friendly round face, 180 cm, a faded tattoo on one forearm *(design)*.
- **Main outfit:** a diner apron under an open work jacket, flannel shirt, jeans, work boots.
- Sheets: FACE, TURNAROUND, OUTFIT.

### Tess Marsh (19) · priority A
**Identity:** White young woman, age 19, freckles, auburn hair in a ponytail, nervous posture, 163 cm.
- **Main outfit:** diner waitress uniform under a parka, sneakers.
- Sheets: FACE, TURNAROUND, OUTFIT.

### Eli Marsh (26) · priority B
**Identity:** White man, age 26, fisherman, short dark-blond hair, short beard, weathered hands, guilty eyes, 183 cm. Tess's brother (family resemblance).
- **Main outfit:** orange rain bib over a sweater, knit cap, rubber boots.
- Sheets: FACE, TURNAROUND, OUTFIT.

### Walter Marsh (72) · priority B
**Identity:** White man, age 72, stooped, white beard, haunted look, 175 cm, father of Eli and Tess.
- **Main outfit:** old wool coat, flat cap, a wooden cane.
- Sheets: FACE, TURNAROUND.

### Sheriff Dale Corbin (50) · priority B
**Identity:** White man, age 50, heavy build, neat moustache, calm unreadable eyes, soft-spoken face, 180 cm.
- **Main outfit:** small-town sheriff uniform, brown sheriff's jacket, campaign hat in hand, duty belt.
- Sheets: FACE, TURNAROUND, OUTFIT.

### Deputy Sam Ortiz (27) · priority B
**Identity:** Latino man, age 27, clean-shaven, short dark hair, anxious honest face, slim, 175 cm.
- **Main outfit:** deputy uniform and jacket.
- **Off-duty variant (lakeshore search):** a grey hoodie and jeans.
- **Ending variant:** a sheriff's jacket two sizes too big.
- Sheets: FACE, TURNAROUND, OUTFIT ×3.

### Brian Holt (44) · priority B
**Identity:** White man, age 44, station manager, carefully styled hair, a slightly nervous salesman's smile, 178 cm.
- **Main outfit:** a polo shirt tucked into chinos, lanyard with a 94.1 FM badge, loafers.
- Sheets: FACE, TURNAROUND.

### Dr. Anika Rao (46) · priority B
**Identity:** Indian-Canadian woman, age 46, hair in a low bun, glasses, tired but determined, 162 cm.
- **Main outfit:** white coat over a sweater, stethoscope, flat shoes.
- Sheets: FACE, TURNAROUND.

### Father Tom Reid (68) · priority B
**Identity:** White man, age 68, priest, thin, white hair, gentle tired face, 178 cm.
- **Main outfit:** black clerical shirt and collar, long dark coat.
- Sheets: FACE, TURNAROUND.

### Jonah Pike (70) · priority B
**Identity:** White man, age 70, reclusive radio engineer, white beard, thick glasses *(design)*, wild white hair *(design)*, 172 cm.
- **Main outfit:** a cardigan full of holes over a flannel shirt, corduroy trousers, slippers or old boots, a headset around his neck.
- Sheets: FACE, TURNAROUND.

### Amma (50s) and Appa (50s) · priority B (video calls only in Part 1)
**Amma identity:** Tamil mother, mid-50s, warm face, grey streaks in hair worn in a bun, small bindi, reading glasses on a chain *(design)*.
- Outfit: cotton saree in deep green.

**Appa identity:** Tamil father, late 50s, thinning grey hair, moustache, owns a leather business in Ranipet.
- Outfit: half-sleeve white shirt, veshti, a pen in his shirt pocket.
- Sheets: FACE (both). TURNAROUND only for Part 2, when they fly in (add winter coats over their clothes).

### Victor's men (3 variants) · priority B, AI enemies
**Identity:** White men, 30s–40s, hard faces, varied builds.
- Outfit: dark work jackets, jeans, boots, black knit caps, rifles. Variant 1 heavyset with beard, variant 2 lean and clean-shaven, variant 3 tall with a shaved head.
- Sheets: TURNAROUND for each.

## Part 2 — Red Lake

### Mani (30) · playable · priority C
**Identity:** same as Part 1, one year older, slightly leaner, fuller beard.
- **Winter outfit:** black parka with fur-lined hood, thermal gloves, insulated boots, a tactical chest rig over the parka, an M4 rifle slung.
- **Disguise variant (the Burn):** a hunter's white winter camouflage parka with a radio on the chest.
- Sheets: TURNAROUND, OUTFIT ×2, EXPRESSIONS.

### Preethi (27) · playable · priority C
**Identity:** South Indian Tamil woman, age 27, medium-brown skin, shoulder-length black hair tied back, calm focused eyes, small gold earrings, thin mangalsutra chain, athletic, 163 cm.
- **Winter outfit:** olive parka, beanie, thermal gloves, a medic pouch on her belt, a pump-action shotgun.
- **Windsor outfit (pharmacist):** *(design)* a simple kurta top over jeans, a cardigan, hospital ID badge.
- Sheets: FACE, TURNAROUND, OUTFIT ×2, EXPRESSIONS.

### Nila (26), hospital · priority C
**Identity:** same as Part 1, now thin and pale.
- **Outfit:** hair short after treatment, a hospital gown under a cardigan, a headset microphone. Prop callout: a ham radio on a bedside table.
- **Ending variant (Pongal):** thinner, hair short, healthy colour returning, a simple cotton saree *(design)*, laughing.
- Sheets: FACE, TURNAROUND, OUTFIT ×2.

### Hades / Mark Hayden (58) · priority C
**Identity:** White man, age 58, tall, 190 cm, lean, silver hair swept back, clean-shaven, pale grey eyes, a calm, patient, soft-voiced face.
- **Outfit:** the same long dark coat as the Part 1 silhouette, over a cashmere sweater, dark trousers, leather gloves. Prop: a golden lancehead coiled around one forearm.
- Sheets: FACE, TURNAROUND, OUTFIT, EXPRESSIONS (subtle only: calm, amused, cold, curious).

### Robert Hayden · priority C
**Identity:** White man, Mark's father; strong family resemblance.
- **1978 version (portrait and dam photo):** age about 45, a long dark coat, stern.
- **Present day (Part 3 hook):** very old, frail but upright, the same long dark coat.
- Sheets: FACE ×2 (both ages).

### Kane (40s) · priority C
**Identity:** White man, mid-40s, ex-military contractor, big and broad, shaved head, heavy beard, a scar through one eyebrow, 190 cm.
- **Outfit:** white winter camouflage, tactical vest, radio on the chest, rifle.
- Sheets: FACE, TURNAROUND.

### Ivy Laurent (34) · priority C
**Identity:** Black Canadian woman, age 34, journalist and former lab technician, short natural hair, sharp eyes, 168 cm.
- **Outfit:** practical winter coat, scarf, camera bag across the body.
- **Rescue variant (Hayden Deep):** a bruise over one eye, lips blue with cold, wrapped in Preethi's olive parka.
- Sheets: FACE, TURNAROUND, OUTFIT ×2.

### Dr. Helen Marchetti (52) · priority C
**Identity:** White woman, age 52, physician, grey-blonde hair in a clip, glasses.
- **Outfit:** scrubs under a fleece, hospital ID.
- Sheets: FACE, TURNAROUND.

### Daniel Keeper (45) · priority C
**Identity:** Anishinaabe man, age 45, bush pilot, long black hair in a braid, weathered face.
- **Outfit:** heavy canvas parka, insulated work pants, mukluks or pac boots, aviator sunglasses pushed up.
- Sheets: FACE, TURNAROUND. Depict respectfully: contemporary working clothes, no costume or stereotype.

### Bev Arsenault (61) · priority C
**Identity:** French-Canadian woman, age 61, motel owner, curly red-dyed hair, reading glasses on her head, tough and kind.
- **Outfit:** plaid shirt, fleece vest, jeans, a mug of coffee.
- **Variant (motel break-in):** a bruise on her cheek, furious.
- Sheets: FACE, TURNAROUND.

### Sully O'Rourke (78) · priority C
**Identity:** Irish-Canadian man, age 78, retired gold miner, white stubble, red nose, small and wiry.
- **Outfit:** worn toque, old miner's jacket, wool trousers, heavy boots.
- Sheets: FACE, TURNAROUND.

### Constable Rachel Dunn (33) · priority C
**Identity:** White woman, age 33, police officer, blonde hair in a tight bun, professional and suspicious.
- **Outfit:** a provincial police winter uniform (dark navy, generic: no real insignia or text).
- Sheets: FACE, TURNAROUND.

### Dr. Grace Okafor · priority C
**Identity:** Black woman, about 60 *(design)*, criminology professor in Thunder Bay, Nila's former teacher, reading glasses, warm but piercing gaze.
- **Outfit:** a wool cardigan over a blouse, at home.
- Sheets: FACE.

### Rocco Delisle (50s) · priority C
**Identity:** White man, 50s, gun seller, greasy grey hair, hard face.
- **Outfit:** leather jacket, dark jeans, boots, at night in the rain.
- Sheets: FACE, TURNAROUND.

### Minor Part 2 faces · priority C
- **Big Lou:** trucker, grey beard, trucker cap, flannel jacket, a CB radio handset.
- **Tyler (20s):** motel night clerk, thin, nervous, brand-new winter boots.
- **Kane's men (3 variants):** white winter camouflage parkas, balaclavas or goggles, rifles, radios.
- **Kane's scarred man:** big and broad, a scar on his chin, white winter camouflage. He paid Tyler at the motel and leads the three men who break into Bev's motel. Not Kane.
- **Northstar staff:** lab coats over sweaters, ID badges (generic, no logos), safety glasses.
- Sheets: FACE for Big Lou, Tyler and the scarred man, TURNAROUND for each enemy variant.

## Open questions (canon)
- **Hades silhouette hat.** The old prompt gave him a wide-brimmed hat; the screenplay only says a long coat, so it has been dropped.

## Scene images
Prompt pattern for a scene still: *"[Scene description from the screenplay]. Characters: [names], use the attached reference sheets for their faces and clothes. Cinematic still, 16:9, [Greyhaven fog / Red Lake snow] lighting, photorealistic, game cutscene quality."*
