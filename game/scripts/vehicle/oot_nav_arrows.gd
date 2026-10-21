class_name OOTNavArrows
extends Node3D
## Subtle navigation chevrons painted on the road along the drive route (a diegetic-looking "nav" aid, no HUD map).
## Arrows are laid out every `spacing` metres from `start_offset`; only the ones a short way ahead of the car are
## visible, fading in with distance and pulsing in a wave so the eye is pulled along the road.
##
## Usage: arrows.setup(route_points, car_node); the arrows are children named Arrow_0, Arrow_1, ...

@export var spacing: float = 9.0
@export var start_offset: float = 5.0
@export var show_ahead: float = 70.0
@export var show_behind: float = 4.0
@export var width: float = 2.8
@export var height_above_road: float = 0.035
@export var tint: Color = Color(0.86, 0.97, 1.0)
@export var max_alpha: float = 0.7

var route: PackedVector3Array = PackedVector3Array()
var target: Node3D = null
var arrows: Array[MeshInstance3D] = []
var arrow_distances: PackedFloat32Array = PackedFloat32Array()   # distance along the route of each arrow
var route_lengths: PackedFloat32Array = PackedFloat32Array()     # cumulative length at each route point
var progress: float = 0.0                                        # the target's distance along the route
var _mat: StandardMaterial3D
var _mesh: ArrayMesh
var _t: float = 0.0
var _last_idx: int = 0


func setup(p_route: PackedVector3Array, p_target: Node3D) -> void:
	route = p_route
	target = p_target
	_build()


func _build() -> void:
	for a: MeshInstance3D in arrows:
		a.queue_free()
	arrows.clear()
	arrow_distances.clear()
	route_lengths.clear()
	if route.size() < 2:
		return
	var acc: float = 0.0
	route_lengths.append(0.0)
	for i: int in range(1, route.size()):
		acc += route[i - 1].distance_to(route[i])
		route_lengths.append(acc)
	_mesh = _make_chevron()
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = Color(tint.r, tint.g, tint.b, max_alpha)
	_mat.render_priority = 2
	var s: float = start_offset
	var n: int = 0
	while s < acc - 2.0:
		var a: MeshInstance3D = MeshInstance3D.new()
		a.name = "Arrow_%d" % n
		a.mesh = _mesh
		a.material_override = _mat.duplicate() as StandardMaterial3D
		a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(a)
		var p: Vector3 = point_at(s)
		var d: Vector3 = point_at(minf(s + 1.5, acc)) - point_at(maxf(s - 1.5, 0.0))
		d.y = 0.0
		a.global_position = p + Vector3(0.0, height_above_road, 0.0)
		a.global_transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), a.global_position)
		a.scale = Vector3(width / 2.2, 1.0, width / 2.2 * 1.25)
		a.visible = false
		arrows.append(a)
		arrow_distances.append(s)
		n += 1
		s += spacing


func get_route_length() -> float:
	return route_lengths[route_lengths.size() - 1] if route_lengths.size() > 0 else 0.0


## Point on the route at distance `s` metres from its start.
func point_at(s: float) -> Vector3:
	if route.size() == 0:
		return Vector3.ZERO
	s = clampf(s, 0.0, get_route_length())
	var lo: int = 0
	var hi: int = route.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if route_lengths[mid] <= s:
			lo = mid
		else:
			hi = mid
	var seg: float = route_lengths[hi] - route_lengths[lo]
	var t: float = 0.0 if seg < 0.0001 else (s - route_lengths[lo]) / seg
	return route[lo].lerp(route[hi], t)


## Distance along the route of the point nearest to `p` (searches forward from the last answer).
func project(p: Vector3) -> float:
	if route.size() < 2:
		return 0.0
	var best: int = _last_idx
	var best_d: float = INF
	var lo: int = maxi(_last_idx - 4, 0)
	var hi: int = mini(_last_idx + 80, route.size() - 1)
	for i: int in range(lo, hi + 1):
		var d: float = Vector2(route[i].x - p.x, route[i].z - p.z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	_last_idx = best
	return route_lengths[best]


func _process(delta: float) -> void:
	if arrows.is_empty():
		return
	_t += delta
	if target != null and is_instance_valid(target):
		progress = project(target.global_position)
	for i: int in arrows.size():
		var ahead: float = arrow_distances[i] - progress
		var a: MeshInstance3D = arrows[i]
		if ahead < -show_behind or ahead > show_ahead:
			a.visible = false
			continue
		a.visible = true
		var fade_in: float = clampf((show_ahead - ahead) / 25.0, 0.0, 1.0)
		var fade_out: float = clampf((ahead + show_behind) / 4.0, 0.0, 1.0)
		var wave: float = 0.65 + 0.35 * sin(_t * 3.2 - ahead * 0.35)
		var m: StandardMaterial3D = a.material_override as StandardMaterial3D
		m.albedo_color.a = max_alpha * fade_in * fade_out * wave


## A flat ">" chevron pointing toward -Z, about 2.2 m wide and 1.5 m long.
func _make_chevron() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip: Vector3 = Vector3(0.0, 0.0, -0.8)
	var tip_in: Vector3 = Vector3(0.0, 0.0, -0.1)
	for sgn: float in [1.0, -1.0]:
		var o: Vector3 = Vector3(1.1 * sgn, 0.0, 0.1)
		var o2: Vector3 = Vector3(1.1 * sgn, 0.0, 0.7)
		var quad: Array[Vector3] = [tip, o, o2, tip_in]
		var idx: Array[int] = []
		idx.assign([0, 1, 2, 0, 2, 3] if sgn > 0.0 else [0, 2, 1, 0, 3, 2])
		for k: int in idx:
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[k])
	return st.commit()
