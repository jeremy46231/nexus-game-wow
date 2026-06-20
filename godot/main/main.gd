extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var _players: Array = [$Player, $Player2]

const FOCUS_FRACTION := 0.8
const CAM_SMOOTH := 8.0

# captured at start
var _default_zoom: float
var _min_x: float
var _fixed_y: float


func _ready() -> void:
	_default_zoom = camera.zoom.x
	_min_x = camera.global_position.x
	_fixed_y = camera.global_position.y


func _physics_process(delta: float) -> void:
	var alive := _players.filter(func(p): return is_instance_valid(p))
	if alive.is_empty():
		return

	# follow the midpoint x, clamped
	var sum_x := 0.0
	for p in alive:
		sum_x += p.global_position.x
	var center_x: float = maxf(sum_x / alive.size(), _min_x)
	var target_pos := Vector2(center_x, _fixed_y)

	# zoom out until every player fits
	var half := FOCUS_FRACTION * 0.5
	var view := get_viewport_rect().size
	var target_zoom := _default_zoom
	for p in alive:
		var dx: float = absf(p.global_position.x - center_x)
		var dy: float = absf(p.global_position.y - _fixed_y)
		if dx > 0.0:
			target_zoom = minf(target_zoom, view.x * half / dx)
		if dy > 0.0:
			target_zoom = minf(target_zoom, view.y * half / dy)

	# smooth toward the target
	var t := 1.0 - exp(-CAM_SMOOTH * delta)
	camera.global_position = camera.global_position.lerp(target_pos, t)
	camera.zoom = camera.zoom.lerp(Vector2(target_zoom, target_zoom), t)
