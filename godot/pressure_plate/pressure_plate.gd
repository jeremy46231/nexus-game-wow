extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


@export var triggered: bool = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sprite.play("up")



func _on_body_entered(body: Node2D) -> void:
	if !triggered:
		print(body.name)
		triggered = true
		sprite.play("down")
