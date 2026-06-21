extends Node2D
const main = preload("res://main/main.tscn")

# the pyramid art is composed in this base resolution; it zooms to fit + centres
# while the UI stays a fixed pixel size (the UI is anchored in the scene, not here)
const DESIGN := Vector2(512, 288)

@onready var background: Node2D = $Background
@onready var no_gold: Sprite2D = $Background/Pyramidbg
@onready var gold: Sprite2D = $Background/Pyramidbg2


func _ready() -> void:
	_update_bg()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vp := get_viewport_rect().size
	var fit := minf(vp.x / DESIGN.x, vp.y / DESIGN.y)
	background.scale = Vector2(fit, fit)
	background.position = vp * 0.5 - DESIGN * 0.5 * fit


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://main/main.tscn")


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
