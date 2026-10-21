class_name OOTMontageKit
extends RefCounted
## Shared helpers for the opening montage environments (riverside, street, forest edge, house): PBR materials from the
## Poly Haven CC0 maps in textures/, the early-November morning environment (HDRI sky, haze), small mesh builders.
## See SOURCES.md for every downloaded asset.

const TEX_DIR: String = "res://environments/windsor/montage/textures/"
const SKY_PATH: String = "res://environments/windsor/montage/sky/kloppenheim_06_puresky_2k.hdr"
const EXT_DIR: String = "res://environments/windsor/exterior/"
const EXT_MATERIALS: String = "res://environments/windsor/exterior/materials/"
const TREES_DIR: String = "res://environments/windsor/montage/trees/"
const SEDAN_DIR: String = "res://vehicles/sedan/"

## The HDRI's sun sits at about 13.7 degrees elevation; the directional light matches it after this sky yaw.
const SUN_ELEVATION_DEG: float = 13.7

static var _mat_cache: Dictionary = {}
static var _scene_cache: Dictionary = {}


## A PBR material from <name>_diff / _nor / _rough 1k JPGs; `tile_m` metres per texture repeat (world triplanar by default).
static func pbr(tex_name: String, tile_m: float = 2.0, tint: Color = Color.WHITE, triplanar: bool = true,
		normal_strength: float = 1.0, uv_repeat: bool = true) -> StandardMaterial3D:
	var key: String = "%s|%s|%s|%s" % [tex_name, tile_m, tint, triplanar]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.resource_name = tex_name
	m.albedo_texture = load(TEX_DIR + tex_name + "_diff_1k.jpg") as Texture2D
	m.albedo_color = tint
	var nrm: Texture2D = load(TEX_DIR + tex_name + "_nor_1k.jpg") as Texture2D
	if nrm != null:
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = normal_strength
	var rough: Texture2D = load(TEX_DIR + tex_name + "_rough_1k.jpg") as Texture2D
	if rough != null:
		m.roughness_texture = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_scale = Vector3.ONE / tile_m
	m.uv1_triplanar = triplanar
	m.uv1_world_triplanar = triplanar
	_mat_cache[key] = m
	return m


static func flat(color: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


## Loads (and caches) a scene / glb as a PackedScene; null when missing.
static func scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path]
	var ps: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	_scene_cache[path] = ps
	return ps


## Instances a scene and applies the exterior's shared materials (the exterior .glb files name their surfaces and the engine
## materials replace them by name).
static func spawn(path: String, parent: Node3D, pos: Vector3 = Vector3.ZERO, yaw_deg: float = 0.0, scale: float = 1.0,
		remap: bool = true) -> Node3D:
	var ps: PackedScene = scene(path)
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	parent.add_child(n)
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	n.scale = Vector3.ONE * scale
	if remap:
		var r: OOTMaterialRemap = OOTMaterialRemap.new()
		r.material_dir = EXT_MATERIALS
		r.apply_to(n)
	return n


static func box(parent: Node3D, center: Vector3, size: Vector3, mat: Material, collide: bool = false) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = center
	parent.add_child(mi)
	return mi


## One oriented triangle: the winding is chosen so the front face looks along `n`.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, uv_m: float, uv_mode: int) -> void:
	if (c - a).cross(b - a).dot(n) < 0.0:
		var t: Vector3 = b
		b = c
		c = t
	for p: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(p.x, p.z) / uv_m if uv_mode == 0 else Vector2(p.x, p.z + p.y) / uv_m)
		st.add_vertex(p)


static func _mesh_instance(parent: Node3D, st: SurfaceTool, mat: Material) -> MeshInstance3D:
	st.generate_tangents()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## A flat horizontal rectangle at height y spanning [x0,x1] x [z0,z1] with UVs in metres.
static func ground(parent: Node3D, x0: float, x1: float, z0: float, z1: float, y: float, mat: Material, uv_m: float = 4.0) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0: Vector3 = Vector3(x0, y, z0)
	var p1: Vector3 = Vector3(x1, y, z0)
	var p2: Vector3 = Vector3(x1, y, z1)
	var p3: Vector3 = Vector3(x0, y, z1)
	_tri(st, p0, p1, p2, Vector3.UP, uv_m, 0)
	_tri(st, p0, p2, p3, Vector3.UP, uv_m, 0)
	return _mesh_instance(parent, st, mat)


## A sloped strip along x from (z0,y0) to (z1,y1), for river banks and verges.
static func slope(parent: Node3D, x0: float, x1: float, z0: float, y0: float, z1: float, y1: float, mat: Material, uv_m: float = 4.0) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p0: Vector3 = Vector3(x0, y0, z0)
	var p1: Vector3 = Vector3(x1, y0, z0)
	var p2: Vector3 = Vector3(x1, y1, z1)
	var p3: Vector3 = Vector3(x0, y1, z1)
	var n: Vector3 = Vector3(1, 0, 0).cross(Vector3(0, y1 - y0, z1 - z0)).normalized()
	if n.y < 0.0:
		n = -n
	_tri(st, p0, p1, p2, n, uv_m, 1)
	_tri(st, p0, p2, p3, n, uv_m, 1)
	return _mesh_instance(parent, st, mat)


## Early-November morning: HDRI sky, warm low sun colour in the haze, soft glow, aerial perspective fog.
static func make_environment(fog_density: float = 0.0016) -> Environment:
	var env: Environment = Environment.new()
	var sky_mat: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
	sky_mat.panorama = load(SKY_PATH) as Texture2D
	var sky: Sky = Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 0.9
	env.glow_bloom = 0.06
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssil_enabled = false
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.74, 0.8, 0.88)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.18
	env.fog_density = fog_density
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.35
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 1.02
	return env


## Procedural seamless normal map for the water.
static func water_normal(seed: int, freq: float, strength: float) -> NoiseTexture2D:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 4
	var t: NoiseTexture2D = NoiseTexture2D.new()
	t.noise = n
	t.width = 512
	t.height = 512
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = strength
	return t


## Latest AABB of all meshes under a node (world space).
static func world_aabb(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Drifting autumn leaves in a box around the node (GPU particles, alpha-scissor leaf quads).
static func leaf_particles(extents: Vector3) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "DriftingLeaves"
	p.amount = 90
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.visibility_aabb = AABB(-extents * 1.4, extents * 2.8)
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3(1, -0.2, 0.3)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0.0, -0.35, 0.0)
	pm.angular_velocity_min = -120.0
	pm.angular_velocity_max = 120.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var lm: StandardMaterial3D = StandardMaterial3D.new()
	lm.albedo_texture = load(EXT_DIR + "textures/leaf_orange.png") as Texture2D
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	lm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	lm.roughness = 0.9
	q.material = lm
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
