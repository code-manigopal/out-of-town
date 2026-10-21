class_name OOTRevealSpot
extends Resource
## A hidden detail on an inspectable item that appears when the player rotates
## the item so one face points at the camera (e.g. handwriting on the back of
## a photo). Directions are in the INSPECT frame: the pose the item has when the
## inspect view first opens, front face toward the camera. So +Z is the front,
## -Z the back, +X the right edge, +Y the top.

## Unique id inside the item (used for tracking what was revealed).
@export var id: StringName = &""
## Direction (inspect frame) of the face that must point at the camera.
@export var direction: Vector3 = Vector3(0, 0, -1)
## How far off-axis (degrees) the face may be and still count.
@export_range(1.0, 90.0) var tolerance_deg: float = 25.0
## Zoom condition: the camera must be at or closer than this distance (the
## inspect view starts at 2.2 and zooms in to 1.1). 0 = no zoom needed. Use it
## with direction (0, 0, 1) for details on the FRONT you must look at closely,
## e.g. a date stamp on a photo.
@export var max_camera_distance: float = 0.0
## Seconds the face must stay pointed at the camera (0 = instant).
@export var hold_time: float = 0.4
## The text revealed on the caption panel. Tanglish lines also carry `subtitle`.
@export_multiline var text: String = ""
@export_multiline var subtitle: String = ""
## Journal entry id added when revealed ("" = none).
@export var journal_entry: String = ""
## Node under Visual shown only once revealed. Default: a child named RevealDecal.
@export var decal_path: NodePath = ^"RevealDecal"


## Angle in degrees between the item's face and the direction to the camera,
## given the item's current basis (local to view space).
## True when the zoom condition (if any) is met for this camera distance.
func zoom_ok(camera_distance: float) -> bool:
	return max_camera_distance <= 0.0 or camera_distance <= max_camera_distance


func angle_to_camera(item_basis: Basis, to_camera: Vector3 = Vector3(0, 0, 1)) -> float:
	var face: Vector3 = (item_basis.orthonormalized() * direction).normalized()
	return rad_to_deg(face.angle_to(to_camera.normalized()))
