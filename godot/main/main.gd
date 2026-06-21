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
	var center := _centroid(alive)
	var zoom := _camera_zoom(alive, center)
	camera.global_position = _shifted_pos(alive, center, zoom)
	camera.zoom = Vector2.ONE * zoom

	_won = false
	_win_timer = 0.0


func _physics_process(delta: float) -> void:
	var alive := _players.filter(func(p): return is_instance_valid(p))
	if alive.is_empty():
		return

	var center := _centroid(alive)
	var target_zoom := _camera_zoom(alive, center)
	var target_pos := _shifted_pos(alive, center, target_zoom)

	# smooth toward the computed target
	var t := 1.0 - exp(-CAM_SMOOTH * delta)
	camera.global_position = camera.global_position.lerp(target_pos, t)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, t)

	if not _won:
		_check_win(alive, delta)


# centre of the alive players
func _centroid(alive: Array) -> Vector2:
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


# shift the camera (per axis) to keep the view inside the level's camera area,
# never moving a player out of the middle FOCUS_FRACTION of the screen
func _shifted_pos(alive: Array, center: Vector2, zoom: float) -> Vector2:
	if _level == null or not is_instance_valid(_level.camera_area):
		return center

	var area := _level.camera_rect()
	var view := get_viewport_rect().size

	# players' bounding box
	var pmin := center
	var pmax := center
	for p in alive:
		pmin = pmin.min(p.global_position)
		pmax = pmax.max(p.global_position)

	var x := _shift_axis(center.x, pmin.x, pmax.x, view.x / zoom, area.position.x, area.end.x)
	var y := _shift_axis(center.y, pmin.y, pmax.y, view.y / zoom, area.position.y, area.end.y)
	return Vector2(x, y)


# one axis of the shift. vis = full visible size on this axis (world units).
func _shift_axis(center: float, pmin: float, pmax: float, vis: float, amin: float, amax: float) -> float:
	var vh := vis * 0.5                  # visible half-size
	var box80 := vh * FOCUS_FRACTION     # half-size of the must-contain-players box

	# the area-driven target
	var desired: float
	if vis >= amax - amin:
		desired = (amin + amax) * 0.5    # view bigger than the area -> centre on it
	else:
		desired = clampf(center, amin + vh, amax - vh)  # shift just enough to stay inside

	# 80% framing is absolute: clamp the shift to the slack it allows
	var lo := pmax - box80
	var hi := pmin + box80
	return clampf(desired, lo, hi)


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
