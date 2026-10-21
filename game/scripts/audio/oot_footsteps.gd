class_name OOTFootsteps
extends RefCounted
## Surface -> random footstep stream (Kenney Impact Sounds, CC0). Not wired into
## the player yet: call OOTFootsteps.pick("wood") and play the result on an
## AudioStreamPlayer3D on the "SFX" bus.
##
##   var s: AudioStream = OOTFootsteps.pick(surface)
##   if s != null: player3d.stream = s; player3d.play()

const DIR: String = "res://audio/sfx/kenney/impact/"
const VARIANTS: int = 5
## Surface names -> Kenney set. Unknown surfaces fall back to concrete.
const SURFACES: Dictionary = {
	"wood": "wood", "floor": "wood", "laminate": "wood",
	"carpet": "carpet", "rug": "carpet",
	"concrete": "concrete", "tile": "concrete", "asphalt": "concrete", "stone": "concrete",
	"grass": "grass", "dirt": "grass",
	"snow": "snow",
}

static var _cache: Dictionary = {}
static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var _last: Dictionary = {}


static func surface_set(surface: String) -> String:
	return str(SURFACES.get(surface.to_lower(), "concrete"))


static func stream_path(surface: String, variant: int) -> String:
	return "%sfootstep_%s_%03d.ogg" % [DIR, surface_set(surface), clampi(variant, 0, VARIANTS - 1)]


## A random footstep for the surface, never repeating the previous variant. Null if missing.
static func pick(surface: String) -> AudioStream:
	var set_name: String = surface_set(surface)
	var v: int = _rng.randi_range(0, VARIANTS - 1)
	if v == int(_last.get(set_name, -1)):
		v = (v + 1 + _rng.randi_range(0, VARIANTS - 2)) % VARIANTS
	_last[set_name] = v
	var path: String = stream_path(surface, v)
	if not _cache.has(path):
		_cache[path] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _cache[path]
