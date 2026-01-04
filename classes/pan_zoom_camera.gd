class_name PanZoomCamera
extends Camera2D

signal zoom_changed(value: float)
signal position_changed(value: Vector2)

const PAN_SPEED := 10

@export var min_zoom := 0.1
@export var max_zoom := 5.0
@export var zoom_factor := 0.1

var position_before_drag: Vector2
var position_before_drag2: Vector2
var zoom_level: float = 1:
	set(value):
		zoom_changed.emit(value)
		zoom_level = value


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		set_zoom_level(zoom_level + zoom_factor)
	elif event.is_action_pressed("zoom_out"):
		set_zoom_level(zoom_level - zoom_factor)
	elif event.is_action_pressed("camera_drag"):
		var mouse_event := event as InputEventMouseButton
		position_before_drag = mouse_event.global_position
		position_before_drag2 = self.global_position
	elif event.is_action_released("camera_drag"):
		position_before_drag = Vector2.ZERO
	elif event is InputEventPanGesture:
		var pan_gesture := event as InputEventPanGesture
		self.global_position += pan_gesture.delta * PAN_SPEED / zoom_level
	elif event is InputEventScreenDrag:
		var screen_drag := event as InputEventScreenDrag
		self.global_position -= screen_drag.relative
	elif event is InputEventMagnifyGesture:
		var magnify_gesture := event as InputEventMagnifyGesture
		if magnify_gesture.factor > 1:
			set_zoom_level(zoom_level + (zoom_factor * 0.5))
		elif magnify_gesture.factor < 1:
			set_zoom_level(zoom_level - (zoom_factor * 0.5))

	if position_before_drag and event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		self.global_position = position_before_drag2 + (position_before_drag - mouse_motion.global_position) * (1 / zoom_level)
	position_changed.emit(offset)


func _set(property: StringName, _value: Variant) -> bool:
	if property == &"global_position":
		position_changed.emit(global_position)
	return false


func set_zoom_level(level: float, mouse_world_position := self.get_global_mouse_position()) -> void:
	var old_zoom_level := zoom_level

	zoom_level = clampf(level, min_zoom, max_zoom)

	var direction := (mouse_world_position - self.global_position)
	var new_position := self.global_position + direction - direction / (zoom_level / old_zoom_level)

	self.zoom = Vector2(zoom_level, zoom_level)
	self.global_position = new_position
