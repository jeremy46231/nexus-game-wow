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

var _default_zoom: float


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

	# snap straight to the computed framing (no startup lerp)
	var alive := _players.filter(func(p): return is_instance_valid(p))
	var pos := _camera_pos(alive)
	camera.global_position = pos
	camera.zoom = Vector2.ONE * _camera_zoom(alive, pos)

	_won = false
	_win_timer = 0.0


func _physics_process(delta: float) -> void:
	var alive := _players.filter(func(p): return is_instance_valid(p))
	if alive.is_empty():
		return

	var target_pos := _camera_pos(alive)
	var target_zoom := _camera_zoom(alive, target_pos)

	# smooth toward the computed target
	var t := 1.0 - exp(-CAM_SMOOTH * delta)
	camera.global_position = camera.global_position.lerp(target_pos, t)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, t)

	if not _won:
		_check_win(alive, delta)


# centre of the alive players
func _camera_pos(alive: Array) -> Vector2:
	var sum := Vector2.ZERO
	for p in alive:
		sum += p.global_position
	return sum / alive.size()


# zoom out until every player fits within FOCUS_FRACTION of the view
func _camera_zoom(alive: Array, center: Vector2) -> float:
	var half := FOCUS_FRACTION * 0.5
	var view := get_viewport_rect().size
	var zoom := _default_zoom
	for p in alive:
		var d: Vector2 = (p.global_position - center).abs()
		if d.x > 0.0:
			zoom = minf(zoom, view.x * half / d.x)
		if d.y > 0.0:
			zoom = minf(zoom, view.y * half / d.y)
	return zoom


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
