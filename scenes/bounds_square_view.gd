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


func set_bounds_from_vect(top_left: Vector2i, bottom_right: Vector2i) -> void:
	top = top_left.y
	bottom = bottom_right.y
	left = top_left.x
	right = bottom_right.x
