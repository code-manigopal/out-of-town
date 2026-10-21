# Sources - Windsor opening montage environments

All outside assets are CC0 (Poly Haven, https://polyhaven.com, downloaded through https://api.polyhaven.com; no attribution
required, credited here anyway). Everything else is ours (CC0): the trees, the water and tower shaders, the scenes and scripts.
Maps are 1k (HDRI 2k); no file is over 5 MB; this folder is about 22 MB in total.

## Poly Haven downloads (22 MB of the folder)

| File(s) | Asset | Resolution | Size |
| --- | --- | --- | --- |
| `sky/kloppenheim_06_puresky_2k.hdr` | HDRI `kloppenheim_06_puresky` (low sun, soft partly cloudy sky) | 2k | 4.4 MB |
| `textures/grass_path_2_{diff,nor,rough}_1k.jpg` | texture `grass_path_2` (park lawn, verges) | 1k | 1.9 MB |
| `textures/forest_leaves_04_{diff,nor,rough}_1k.jpg` | texture `forest_leaves_04` (forest floor) | 1k | 1.3 MB |
| `textures/concrete_pavement_{diff,nor,rough}_1k.jpg` | texture `concrete_pavement` (riverside path, sidewalks) | 1k | 2.6 MB |
| `textures/dry_riverbed_rock_{diff,nor,rough}_1k.jpg` | texture `dry_riverbed_rock` (river bank rocks) | 1k | 2.8 MB |
| `textures/asphalt_01_{diff,nor,rough}_1k.jpg` | texture `asphalt_01` (roads) | 1k | 2.3 MB |
| `textures/bark_brown_02_{diff,nor,rough}_1k.jpg` | texture `bark_brown_02` (tree bark) | 1k | 2.0 MB |
| `models/fern_02/` (gltf, bin, 3 textures) | model `fern_02` (forest understorey) | 1k | 1.1 MB |
| `models/grass_medium_01/` (gltf, bin, 3 textures) | model `grass_medium_01` (bank grass tufts) | 1k | 2.9 MB |

## Reused read-only from the exterior kit (ours, see `../exterior/`)
`building.glb`, `neighbours.glb`, `house_*.glb`, `shop_*.glb`, `tree_*.glb`, `streetlight.glb`, `utility_pole.glb`, `bus_shelter.glb`,
`bench.glb`, `litter_bin.glb`, `hydrant.glb`, `person_*.glb`, `textures/leaf_*.png` (leaf cards), the shared materials in
`../exterior/materials/`, and the traffic cars in `res://vehicles/sedan/`.

## Ours
- `trees/*.glb`, `trees/spruce_cards.png`, `trees/materials/*.tres`: `tools/blender/build_montage_trees.py` (scripted limbs, leaf cards,
  numpy-drawn needle cards). Blender's Sapling Tree Gen is an extension and is not bundled with the LTS build.
- `water.gdshader`, `planar_reflection.gd` (mirrored-camera reflection), `building_facade.gdshader` (generic towers, no logos).
- The Detroit skyline is a generic backdrop: boxes, cylinders and spires with a window-grid shader. No real building, logo or sign.
