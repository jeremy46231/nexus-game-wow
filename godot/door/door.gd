class_name Door
extends StaticBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var openCollision: CollisionShape2D = $openCollisionSometimes
var open_collides = false
@export var closed: bool = false:
	set(value):
		closed = value
		if is_node_ready():
			update_state()

func _ready() -> void:
	open_collides = rotation_degrees == 90.0 || rotation_degrees == -90.0
	update_state()
	
func _physics_process(delta: float) -> void:
	update_state()

func update_state() -> void:
	if (!open_collides):
		openCollision.set_deferred("disabled", true)
	if closed:
		anim.play("close")
		collision.set_deferred("disabled", false)
		if (open_collides):
			openCollision.set_deferred("disabled", true)
		
	else:
		anim.play("open")
		collision.set_deferred("disabled", true)
		if (open_collides):
			openCollision.set_deferred("disabled", false)
