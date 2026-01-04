class_name RichTextLabelSink
extends Logger.ExternalSink

var rtl: RichTextLabel


func _init(p_name: String, p_rich_text_label: RichTextLabel, p_queue_mode := QUEUE_MODES.NONE) -> void:
	super(p_name, p_queue_mode)
	rtl = p_rich_text_label


func flush_buffer() -> void:
	pass


func write(output: String, level: int) -> void:
	if not rtl:
		return

	if level in [Logger.VERBOSE, Logger.INFO]:
		rtl.append_text(output)
	else:
		match level:
			Logger.DEBUG:
				rtl.push_color(Color.SKY_BLUE)
			Logger.WARN:
				rtl.push_color(Color.YELLOW)
			Logger.ERROR:
				rtl.push_color(Color.ORANGE_RED)
		rtl.append_text(output)
		rtl.pop()

	rtl.newline()
