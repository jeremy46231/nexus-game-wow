extends Node2D
const main = preload("res://main/main.tscn")

@onready var no_gold: Sprite2D = $Pyramidbg
@onready var gold: Sprite2D = $Pyramidbg2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_bg()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://main/main.tscn") # Replace with function body.


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_play_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://main/main.tscn")

func _update_bg() -> void:
	if  (!FileAccess.file_exists("user://savegame.save")):
		print("no file")
		no_gold.show()
		gold.hide()
	else:
		print("yes file")
		no_gold.hide()
		gold.show()
