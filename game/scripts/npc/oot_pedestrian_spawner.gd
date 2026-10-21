class_name OOTPedestrianSpawner
extends RefCounted
## Spawns pedestrians on Path3D routes (the exterior's PedRoute_* nodes).
##   var peds := OOTPedestrianSpawner.spawn_along(routes, 12)
## Closed routes loop, open routes ping-pong. A route whose name contains "BusStop" (or that has meta "idle_wait")
## gets standing pedestrians at its start (facing along the route) instead of walkers. Wait* children of a route are
## crossings. Peds are added under [param parent] (default: the first route's parent).

const MODELS: Array[String] = [
	"res://characters/pedestrians/ped_1.glb", "res://characters/pedestrians/ped_2.glb",
	"res://characters/pedestrians/ped_3.glb", "res://characters/pedestrians/ped_4.glb",
	"res://characters/pedestrians/ped_5.glb", "res://characters/pedestrians/ped_6.glb",
]
const SCENE: String = "res://scenes/npc/pedestrian.tscn"


static func spawn_along(route_paths: Array[Path3D], count: int, parent: Node = null, seed_value: int = 0,
		min_speed: float = 0.9, max_speed: float = 1.4) -> Array[OOTPedestrian]:
	var out: Array[OOTPedestrian] = []
	if route_paths.is_empty() or count <= 0:
		return out
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else randi()
	if parent == null:
		parent = route_paths[0].get_parent()
	var scene: PackedScene = load(SCENE) as PackedScene
	var models: Array[String] = MODELS.duplicate()
	var per_route: Dictionary = {}
	for i in count:
		per_route[i % route_paths.size()] = int(per_route.get(i % route_paths.size(), 0)) + 1
	var model_i: int = rng.randi() % models.size()
	var made: int = 0
	for ri: int in per_route:
		var path: Path3D = route_paths[ri]
		if path.curve == null:
			continue
		var n: int = per_route[ri]
		var length: float = path.curve.get_baked_length()
		var idle_route: bool = String(path.name).contains("BusStop") or path.has_meta("idle_wait")
		for k in n:
			var p: OOTPedestrian = scene.instantiate() as OOTPedestrian
			p.model_path = models[model_i % models.size()]
			model_i += 1
			p.speed = rng.randf_range(min_speed, max_speed)
			var slot: float = (float(k) + rng.randf_range(0.15, 0.85)) / float(n)
			p.start_offset = slot * length
			p.reverse = rng.randf() < 0.5
			if idle_route:
				p.mode = OOTPedestrian.Mode.IDLE_WAIT
				p.start_offset = clampf(rng.randf_range(0.0, minf(length, 1.5 * n)), 0.0, length)
				p.idle_style = OOTPedestrian.IdleStyle.MIXED
			parent.add_child(p)
			p.set_route(path)
			p.name = "Pedestrian_%d" % made
			out.append(p)
			made += 1
	return out
