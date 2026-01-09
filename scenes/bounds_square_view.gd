extends GridContainer

var top: int:
	set(value):
		_top.text = "z= " + str(value)
		top = value
var bottom: int:
	set(value):
		_bottom.text = "z= " + str(value)
		bottom = value
var left: int:
	set(value):
		_left.text = "x= " + str(value)
		left = value
var right: int:
	set(value):
		_right.text = "x= " + str(value)
		right = value

@onready var _top: Label = %Top
@onready var _bottom: Label = %Bottom
@onready var _left: Label = %Left
@onready var _right: Label = %Right


func set_bounds_from_rect2i(bounds: Rect2i) -> void:
	top = bounds.position.y
	bottom = bounds.end.y
	left = bounds.position.x
	right = bounds.end.x
