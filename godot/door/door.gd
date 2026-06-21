class_name Door
extends StaticBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

@export var closed: bool = false:
	set(value):
		closed = value
		if is_node_ready():
			update_state()

func _ready() -> void:
	update_state()
	
func _physics_process(delta: float) -> void:
	update_state()

func update_state() -> void:
	if closed:
		anim.play("close")
		collision.set_deferred("disabled", false)
	else:
		anim.play("open")
		collision.set_deferred("disabled", true)
