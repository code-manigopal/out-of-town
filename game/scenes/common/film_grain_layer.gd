extends CanvasLayer
## Full-screen film grain + slight chromatic aberration. Sits on a CanvasLayer
## below the UI layer so subtitles and HUD stay crisp.

@export var effect_enabled: bool = true:
	set(value):
		effect_enabled = value
		_apply()
@export_range(0.0, 0.2) var grain_strength: float = 0.03:
	set(value):
		grain_strength = value
		_apply()
@export_range(0.0, 0.01) var aberration: float = 0.0006:
	set(value):
		aberration = value
		_apply()

@onready var _rect: ColorRect = $Rect


func _ready() -> void:
	_apply()


func _apply() -> void:
	if _rect == null:
		return
	_rect.visible = effect_enabled
	var mat: ShaderMaterial = _rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("grain_strength", grain_strength)
		mat.set_shader_parameter("aberration", aberration)
