extends CharacterBody2D
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var collisionUp: CollisionShape2D = $UpCollisionShape2D
@onready var collisionDown: CollisionShape2D = $DownCollisionShape2D


@export var down: bool = false

func _ready() -> void:
	collisionDown.disabled = true
	collisionUp.disabled = false

func _physics_process(delta: float) -> void:
	
	_set_anim()

	move_and_slide()

func _set_anim() -> void:
	if (down):
		anim.play("down")
		collisionUp.disabled = true
		collisionDown.disabled = false
	else:
		anim.play("up")
		collisionUp.disabled = false
		collisionDown.disabled = false
