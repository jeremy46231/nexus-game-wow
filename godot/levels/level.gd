class_name Level
extends Node2D

# each level scene exposes these so the Game manager (main.gd) can wire it up
@onready var spawn_1: Marker2D = $Spawn1
@onready var spawn_2: Marker2D = $Spawn2
@onready var win_zone: Area2D = $WinZone
# the camera tries to keep its view inside this rect (editor-only outline)
@onready var camera_area: ReferenceRect = $CameraArea


# the camera area as a world-space Rect2
func camera_rect() -> Rect2:
	return Rect2(camera_area.global_position, camera_area.size)
