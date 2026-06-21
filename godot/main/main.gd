extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var _players: Array = [$Player, $Player2]
@onready var _level_holder: Node2D = $CurrentLevel

# ordered list of levels
const LEVELS := [
	"res://levels/level_1.tscn",
	"res://levels/level_TODO_platformer.tscn",
]

const FOCUS_FRACTION := 0.8
const CAM_SMOOTH := 8.0

const WIN_DWELL := 0.3
var _win_timer: float = 0.0
var _won: bool = false

var _level: Level

# camera bounds
var _default_zoom: float
var _fixed_y: float


func _ready() -> void:
	_default_zoom = camera.zoom.x
	_load_level(Game.level)


func _load_level(index: int) -> void:
	# clear any previous level
	for c in _level_holder.get_children():
		c.queue_free()

	_level = (load(LEVELS[index]) as PackedScene).instantiate()
	_level_holder.add_child(_level)

	# drop the players on their spawn points
	_players[0].global_position = _level.spawn_1.global_position
	_players[1].global_position = _level.spawn_2.global_position

	# anchor the camera to this level's start marker
	camera.global_position = _level.camera_start.global_position
	camera.zoom = Vector2(_default_zoom, _default_zoom)
	_fixed_y = _level.camera_start.global_position.y

	_won = false
	_win_timer = 0.0


func _physics_process(delta: float) -> void:
	var alive := _players.filter(func(p): return is_instance_valid(p))
	if alive.is_empty():
		return

	# follow the midpoint x, clamped
	var sum_x := 0.0
	for p in alive:
		sum_x += p.global_position.x
	var center_x: float = sum_x / alive.size()
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

	if not _won:
		_check_win(alive, delta)


# clear the level once every alive player is in the win zone together
func _check_win(alive: Array, delta: float) -> void:
	if _level == null:
		return
	var in_zone := _level.win_zone.get_overlapping_bodies().filter(func(b): return b is Player)
	if in_zone.size() == alive.size():
		_win_timer += delta
		if _win_timer >= WIN_DWELL:
			_level_complete()
	else:
		_win_timer = 0.0


func _level_complete() -> void:
	_won = true
	Game.level += 1
	if Game.level >= LEVELS.size():
		# beat the last level -> back to the title
		Game.level = 0
		get_tree().change_scene_to_file("res://title/title.tscn")
	else:
		# reload for fresh player instances on the next level
		get_tree().reload_current_scene()
