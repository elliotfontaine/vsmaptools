class_name SelectionTool
extends Node2D

signal selected(rect: Rect2)

var camera: Camera2D
var is_selecting := false
var selection_start := Vector2()
var selection_rect := Rect2()

@onready var nine_patch_rect: NinePatchRect = %NinePatchRect # to visualize selection rectangle


func _ready() -> void:
	camera = get_viewport().get_camera_2d()


func _process(_delta: float) -> void:
	if is_selecting:
		# Continuously update the selection rectangle to match the mouse position
		var current_mouse_position := get_global_mouse_position()
		selection_rect = Rect2(selection_start, current_mouse_position - selection_start).abs()
		nine_patch_rect.position = selection_rect.position
		nine_patch_rect.size = selection_rect.size


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				# Start selection
				is_selecting = true
				selection_start = get_global_mouse_position()
				nine_patch_rect.position = selection_start
				nine_patch_rect.size = Vector2()
			else:
				# End selection
				if is_selecting:
					is_selecting = false
					nine_patch_rect.visible = false
					if selection_rect.size >= Vector2(1, 1):
						selected.emit(selection_rect)

	elif event is InputEventMouseMotion:
		if is_selecting:
			# Show selection box only when mouse is dragged and rect is larger than (2,2)
			if selection_rect.size.length() > 2:
				nine_patch_rect.visible = true
			else:
				nine_patch_rect.visible = false
