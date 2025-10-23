extends Node2D
class_name SelectionTool

signal selected(rect: Rect2)

var camera: Camera2D

@onready var nine_patch_rect: NinePatchRect = %NinePatchRect # to visualize selection rectangle

var is_selecting := false
var selection_start := Vector2()
var selection_rect := Rect2()


func _ready() -> void:
	camera = get_viewport().get_camera_2d()


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
					selected.emit(selection_rect)
					_select()
					
		# De-select all units if RMB is pressed
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			_clear_previous_selection()

	elif event is InputEventMouseMotion:
		if is_selecting:
			# Show selection box only when mouse is dragged and rect is larger than (32,32)
			if selection_rect.size.length() > 32:
				nine_patch_rect.visible = true
			else:
				nine_patch_rect.visible = false


func _process(_delta: float) -> void:
	if is_selecting:
		# Continuously update the selection rectangle to match the mouse position
		var current_mouse_position := get_global_mouse_position()
		selection_rect = Rect2(selection_start, current_mouse_position - selection_start).abs()
		nine_patch_rect.position = selection_rect.position
		nine_patch_rect.size = selection_rect.size


func _select() -> void:
	pass


func _clear_previous_selection() -> void:
	pass
