class_name Player
extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

const title = preload("res://title/title.tscn")

@export var player_id: int = 1

# keybinds
@export var jump_action: StringName = "p1_jump"
@export var left_action: StringName = "p1_left"
@export var right_action: StringName = "p1_right"
@export var smol_action: StringName = "p1_smol"
@export var call_action: StringName = "p1_call"


# the other player (wired up in the scene)
@export var other_player: Player

var is_dead = false
var isSmol := false

# smol shrinks the collision shape + sprite rather than scaling the body node:
# scaling a CharacterBody2D breaks collisions and would wreck the fused "call" state.
# (full bottom edge sits at +8, smol at +4, so the feet line up the same way)
const FULL_SHAPE_SIZE := Vector2(15.75, 15.75)
const SMOL_SHAPE_SIZE := Vector2(7.875, 7.875)
const FULL_SHAPE_OFFSET := Vector2(0, 0.125)
const SMOL_SHAPE_OFFSET := Vector2(0, 0.0625)
const SMOL_SPRITE_SCALE := Vector2(0.5, 0.5)
# wen smol, smol the physics too
const SMOL_SPEED_SCALE := 0.50
const SMOL_JUMP_SCALE := sqrt(0.5) # peak is proportional to velocity^2

# movement vars
# horizontal
const speed: float = 300.0
const acceleration: float = 4000.0
const friction: float = 2400.0
const air_acceleration: float = 2000.0
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

# fall below this y and you boom
const death_y: float = 2000.0

# timers
var _coyote_timer: float = 0.0
var _buffer_timer: float = 0.0

# true while on top of the other player, turns off our vertical physics
# until we jump or slide off the edge
var _riding: bool = false

# permanently fused with the other player (we're the host/driver, they've been
# absorbed into us)
var _fused: bool = false
# the absorbed passenger's nodes and geometry
var _fused_collision: CollisionShape2D
var _fused_sprite: AnimatedSprite2D
var _fused_col_offset: Vector2
var _fused_pass_half_y: float
# the passenger's player_id
var _fused_player_id: int = 1

# where we were at the start of the current frame
# (so we can move a player riding us)
var _frame_start_pos: Vector2

func _ready() -> void:
	_frame_start_pos = global_position
	# private copy of the shape so resizing for smol doesn't mutate the other
	# player's (potentially shared) shape resource
	_collision.shape = _collision.shape.duplicate()

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
		velocity.y = jump_velocity * (SMOL_JUMP_SCALE if isSmol else 1.0)
		_buffer_timer = 0.0
		_coyote_timer = 0.0
		_set_riding(false)

	# stop going up as much when we let go
	if Input.is_action_just_released(jump_action) and velocity.y < 0.0:
		velocity.y *= jump_cut_factor

	# shrink (permanent -- no growing back)
	if Input.is_action_just_pressed(smol_action):
		_set_smol(true)

	# horizontal movement
	var direction := Input.get_axis(left_action, right_action)
	var target_speed := speed * (SMOL_SPEED_SCALE if isSmol else 1.0)
	if direction != 0.0:
		# horizontal move pressed
		var accel := acceleration if on_floor else air_acceleration
		velocity.x = move_toward(velocity.x, direction * target_speed, accel * delta)
		anim.flip_h = direction < 0.0
	else:
		# not pressing move, slow down
		var fric := friction if on_floor else air_friction
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)
		
	if Input.is_action_just_pressed("exit"):
		if !is_dead:
			is_dead = true
			get_tree().change_scene_to_file("res://main/main.tscn")
	# "call" the other player
	if Input.is_action_just_pressed(call_action) and is_instance_valid(other_player):
		_fuse_with(other_player)

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
	isSmol = value
	var rect := _collision.shape as RectangleShape2D
	rect.size = SMOL_SHAPE_SIZE if value else FULL_SHAPE_SIZE
	_collision.position = SMOL_SHAPE_OFFSET if value else FULL_SHAPE_OFFSET
	anim.scale = SMOL_SPRITE_SCALE if value else Vector2.ONE
	_reposition_fused()

func _get_half_size() -> Vector2:
	return Vector2(4, 4) if isSmol else Vector2(8, 8)
	
func _get_other_half_size() -> Vector2:
	return Vector2(4, 4) if other_player.isSmol else Vector2(8, 8)

# permanently fuse the other player on top of us
func _fuse_with(passenger: Player) -> void:
	_set_riding(false)
	passenger._set_riding(false)
	passenger.velocity = Vector2.ZERO

	# remember their geometry n stuff
	var pass_col := passenger._collision
	var pass_sprite := passenger.anim
	_fused_col_offset = pass_col.position
	_fused_pass_half_y = (pass_col.shape as RectangleShape2D).size.y * 0.5
	_fused_player_id = passenger.player_id

	# absorb their ~~body~~ collision shape
	passenger.remove_child(pass_col)
	pass_col.name = "FusedCollision"
	add_child(pass_col)
	_fused_collision = pass_col

	# absorb their ~~soul~~ sprite
	passenger.remove_child(pass_sprite)
	pass_sprite.name = "FusedSprite"
	add_child(pass_sprite)
	_fused_sprite = pass_sprite

	other_player = null
	_fused = true
	_reposition_fused()

	# kill the passenger !!! murder
	passenger.set_physics_process(false)
	passenger.set_process(false)
	passenger.other_player = null
	passenger.queue_free()


# keep the fused passenger on our top edge, centred
func _reposition_fused() -> void:
	if not _fused:
		return
	var host_half_y := (_collision.shape as RectangleShape2D).size.y * 0.5
	var host_top := global_position.y + _collision.position.y - host_half_y
	# the passenger origin that puts its shape bottom exactly on our top edge
	var origin := Vector2(global_position.x, host_top - _fused_pass_half_y - _fused_col_offset.y)
	_fused_collision.global_position = origin + _fused_col_offset
	_fused_sprite.global_position = origin

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
	
	if other_player._riding:
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
	
	var anim_name
	if velocity.y == 0:
		if abs(velocity.x) == 0:
			anim_name = "idle"
		if abs(velocity.x) > 0:
			anim_name = "move"

	# down
	if velocity.y > 0:
		if abs(velocity.x) == 0:
			anim_name = "down"
		if abs(velocity.x) > 0:
			anim_name = "move_down"

	# up
	if velocity.y < 0:
		if abs(velocity.x) == 0:
			anim_name = "up"
		if abs(velocity.x) > 0:
			anim_name = "move_up"
	
	anim.play(_colour_variant(anim_name))

	# the fused passenger mirrors our motion but keeps its OWN colour
	if _fused and is_instance_valid(_fused_sprite):
		_fused_sprite.play(_colour_variant(anim_name, _fused_player_id))
		_fused_sprite.flip_h = anim.flip_h
		_fused_sprite.frame = anim.frame

func _colour_variant(base, id := player_id) -> String:
	return base + "2" if id != 1 else base

func _on_death() -> void:
	if !is_dead:
		is_dead = true
		get_tree().reload_current_scene()

func check_collisions() -> void:
	if global_position.y > death_y:
		_on_death()
		return

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
