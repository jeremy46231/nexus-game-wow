class_name Level
extends Node2D

# each level scene exposes these so the Game manager (main.gd) can wire it up
@onready var spawn_1: Marker2D = $Spawn1
@onready var spawn_2: Marker2D = $Spawn2
@onready var win_zone: Area2D = $WinZone
