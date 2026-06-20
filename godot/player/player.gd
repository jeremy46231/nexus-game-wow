class_name Player
extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
const title = preload("res://title/title.tscn")

# keybinds
@export var jump_action: StringName = "p1_jump"
@export var left_action: StringName = "p1_left"
@export var right_action: StringName = "p1_right"
@export var smol_action: StringName = "p1_smol"
@export var teleport_action: StringName = "p1_teleport"

# the other player (wired up in the scene)
@export var other_player: Player

var is_dead = false
var isSmol := false;
const SCALE_FACTOR := 0.5

# movement vars
# horizontal
const speed: float = 300.0
const acceleration: float = 2000.0
const friction: float = 2400.0
const air_acceleration: float = 1200.0
const air_friction: float = 400.0
# jump
const jump_velocity: float = -400.0
# gravity
const rise_gravity_scale: float = 1.0
const fall_gravity_scale: float = 1.6
const max_fall_speed: float = 1000.0
# short tap -> short hop
# if you let go when going up, kinda like stop going up as much
const jump_cut_factor: float = 0.4
# coyote time! :D (and other buffer time)
const coyote_time: float = 0.1
const jump_buffer_time: float = 0.1
# how far above the resting gap a rider can drift before it detaches
const ride_gap_slack: float = 3.0

# timers
var _coyote_timer: float = 0.0
var _buffer_timer: float = 0.0

# true while on top of the other player, turns off our vertical physics
# until we jump or slide off the edge
var _riding: bool = false

# where we were at the start of the current frame
# (so we can move a player riding us)
var _frame_start_pos: Vector2

func _ready() -> void:
	_frame_start_pos = global_position

func _physics_process(delta: float) -> void:
	_frame_start_pos = global_position

	var on_floor := is_on_floor() or _riding

	# make timers go
	_coyote_timer = coyote_time if on_floor else _coyote_timer - delta
	if Input.is_action_just_pressed(jump_action):
		_buffer_timer = jump_buffer_time
	else:
		_buffer_timer -= delta

	# do gravity
	if not on_floor:
		var grav_scale := fall_gravity_scale if velocity.y > 0.0 else rise_gravity_scale
		velocity += get_gravity() * grav_scale * delta
		velocity.y = minf(velocity.y, max_fall_speed)

	# jump (if buffered jump, allow coyote too)
	if _buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_buffer_timer = 0.0
		_coyote_timer = 0.0
		_set_riding(false)

	# stop going up as much when we let go
	if Input.is_action_just_released(jump_action) and velocity.y < 0.0:
		velocity.y *= jump_cut_factor

	# shrink / grow toggle
	if Input.is_action_just_pressed(smol_action):
		# _set_smol(true)
		_set_smol(!isSmol)

	# horizontal movement
	var direction := Input.get_axis(left_action, right_action)
	if direction != 0.0:
		# horizontal move pressed
		var accel := acceleration if on_floor else air_acceleration
		velocity.x = move_toward(velocity.x, direction * speed, accel * delta)
		anim.flip_h = direction < 0.0
	else:
		# not pressing move, slow down
		var fric := friction if on_floor else air_friction
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	# teleport / "call" the other player to us
	# TODO: do
	if Input.is_action_just_pressed(teleport_action):
		pass

	_set_anim()

	# magic godot function waow godot is so cool
	move_and_slide()

	check_collisions()

	if is_instance_valid(other_player):
		# do all the work to do with the other player
		_resolve_other()


func _set_riding(value: bool) -> void:
	if _riding == value:
		return
	_riding = value
	# rider must run after carrier
	process_physics_priority = 1 if value else 0

func _set_smol(value: bool) -> void:
	if isSmol == value:
		return
	isSmol = value;
	scale = Vector2(SCALE_FACTOR, SCALE_FACTOR) if value else Vector2(1, 1)

func _get_half_size() -> Vector2:
	return Vector2(4, 4) if isSmol else Vector2(8, 8)
	
func _get_other_half_size() -> Vector2:
	return Vector2(4, 4) if other_player.isSmol else Vector2(8, 8)

# bounding box, global
func _rect() -> Rect2:
	return Rect2(global_position - _get_half_size(), _get_half_size() * 2.0)


func _resolve_other() -> void:
	# already riding: keep sticking until we slide off the side or the carrier
	# rises above us (e.g. we got stopped by a ceiling)
	if _riding:
		var sep := _get_half_size() + _get_other_half_size()
		var dx := absf(global_position.x - other_player._frame_start_pos.x)

		var gap := other_player._frame_start_pos.y - _frame_start_pos.y
		if dx < sep.x and gap > 0.0 and gap < sep.y + ride_gap_slack:
			# stick to them
			_stick_to(other_player)
		else:
			# we aren't close enough to stick anymore
			_set_riding(false)
		return

	var a := _rect()
	var b := other_player._rect()
	if not a.intersects(b):
		return

	# how deep we overlap on each axis
	var overlap_x := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	var overlap_y := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)

	if overlap_y <= overlap_x:
		# mostly stacked, if I'm the upper one and not flying upward, start riding
		if global_position.y < other_player.global_position.y and velocity.y >= 0.0:
			_set_riding(true)
			_stick_to(other_player)
		# if I'm the bottom one, I do nothing special
	else:
		# mostly side-by-side
		var dir := signf(a.get_center().x - b.get_center().x)
		if dir == 0.0:
			dir = 1.0
		var half := overlap_x * 0.5
		# shove the other player out by up to half
		var other_col := other_player.move_and_collide(Vector2(-dir * half, 0.0))
		var other_moved := absf(other_col.get_travel().x) if other_col != null else half
		# move ourselves out by whatever overlap remains (more if they hit a wall)
		var my_request := overlap_x - other_moved
		var my_col := move_and_collide(Vector2(dir * my_request, 0.0))
		var my_moved := absf(my_col.get_travel().x) if my_col != null else my_request
		# if we hit a wall too, push the leftover back onto the other player
		var leftover := my_request - my_moved
		if leftover > 0.0:
			other_player.move_and_collide(Vector2(-dir * leftover, 0.0))


# lock onto the carrier, match its height exactly and follow whatever
# horizontal distance it moved this frame
func _stick_to(carrier: Player) -> void:
	var target_y := carrier.global_position.y - (_get_half_size() + _get_other_half_size()).y
	var dy := target_y - global_position.y
	var hit := move_and_collide(Vector2(0.0, dy))

	# carrier pushed us into a ceiling, shove it back down and zero velocity
	if hit != null and dy < 0.0:
		var push_down := (global_position.y + (_get_half_size() + _get_other_half_size()).y) - carrier.global_position.y
		if push_down > 0.0:
			carrier.move_and_collide(Vector2(0.0, push_down))
			if carrier.velocity.y < 0.0:
				carrier.velocity.y = 0.0

	var carrier_dx := carrier.global_position.x - carrier._frame_start_pos.x
	if carrier_dx != 0.0:
		move_and_collide(Vector2(carrier_dx, 0.0))

	velocity.y = carrier.velocity.y

func _set_anim() -> void:
	if velocity.y == 0:
		if velocity.x == 0:
			anim.play("idle")
		if velocity.x > 0:
			anim.play("right")
		if velocity.x < 0:
			anim.play("left")

	# down
	if velocity.y > 0:
		if velocity.x == 0:
			anim.play("down")
		if velocity.x > 0:
			anim.play("right_down")
		if velocity.x < 0:
			anim.play("left_down")

	# up
	if velocity.y < 0:
		if velocity.x == 0:
			anim.play("up")
		if velocity.x > 0:
			anim.play("right_up")
		if velocity.x < 0:
			anim.play("left_up")

func _on_death() -> void:
	if !is_dead:
		is_dead = true
		get_tree().change_scene_to_file("res://title/title.tscn")

func check_collisions() -> void:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is TileMapLayer:
			var tilemap = collider
			var collision_position = collision.get_position()
			var tile_pos = tilemap.local_to_map(tilemap.to_local(collision_position - collision.get_normal() * 2))
			var tile = tilemap.get_cell_tile_data(tile_pos)

			if tile:
				var action_type = tile.get_custom_data("spike")

				if action_type:
					_on_death()
