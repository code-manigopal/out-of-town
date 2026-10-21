# Sources - Windsor exterior PBR textures (Poly Haven, CC0)

All maps are the 1K JPG downloads (`diff` albedo, `nor_gl` normal (OpenGL), `rough` roughness) from [Poly Haven](https://polyhaven.com), licence **CC0** (public domain; https://polyhaven.com/license). Downloaded with `art_source/environments/windsor/exterior/tools/fetch_polyhaven.py` (Poly Haven API `https://api.polyhaven.com`), no file over 5 MB. The `*_nor.jpg.import` files set `compress/normal_map=1`.

| asset | page | authors | licence | size | download | used for |
|---|---|---|---|---|---|---|
| asphalt_02 | https://polyhaven.com/a/asphalt_02 | Rob Tuytel | CC0 | 1K | 2.5 MB | Asphalt (roads) |
| asphalt_01 | https://polyhaven.com/a/asphalt_01 | Dario Barresi, Charlotte Baglioni | CC0 | 1K | 2.3 MB | LotAsphalt (back lot) |
| brushed_concrete_04 | https://polyhaven.com/a/brushed_concrete_04 | Amal Kumar | CC0 | 1K | 2.5 MB | Sidewalk (broom finish with joints), kerbs |
| brushed_concrete_03 | https://polyhaven.com/a/brushed_concrete_03 | Amal Kumar | CC0 | 1K | 2.6 MB | AlleyConcrete, Concrete (foundations, porches) |
| concrete_pavement_03 | https://polyhaven.com/a/concrete_pavement_03 | Charlotte Baglioni | CC0 | 1K | 2.1 MB | Roof (asphalt shingles) |
| red_brick_03 | https://polyhaven.com/a/red_brick_03 | Rob Tuytel | CC0 | 1K | 1.9 MB | Brick, BrickTan |
| red_bricks_04 | https://polyhaven.com/a/red_bricks_04 | Rob Tuytel | CC0 | 1K | 0.9 MB | BrickBrown |
| white_planks_clean | https://polyhaven.com/a/white_planks_clean | Rob Tuytel | CC0 | 1K | 1.4 MB | Siding, SidingBlue/Green/Grey (rotated 90 degrees: white_planks_h_*) |
| sparse_grass | https://polyhaven.com/a/sparse_grass | Amal Kumar | CC0 | 1K | 2.9 MB | Grass (lawns, verges) |
| bark_brown_01 | https://polyhaven.com/a/bark_brown_01 | Rob Tuytel | CC0 | 1K | 2.2 MB | Bark (street trees) |
| weathered_planks | https://polyhaven.com/a/weathered_planks | Dario Barresi, Dimitrios Savva | CC0 | 1K | 1.5 MB | Fence |
| planks_brown_10 | https://polyhaven.com/a/planks_brown_10 | Rob Tuytel | CC0 | 1K | 1.0 MB | Deck |

Total 23.8 MB.

## Derived files

- `white_planks_h_diff/nor/rough.jpg`: `white_planks_clean` rotated 90 degrees (horizontal clapboard); the normal map's channels are re-oriented to match (`tools/prep_textures.py`).
