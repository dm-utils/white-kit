class_name WhiteUi
extends RefCounted
## Widget factory in the look of WhiteTheme.


static func label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, WhiteTheme.BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", WhiteTheme.FONT_BUTTON)
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = WhiteTheme.BUTTON[state]
		box.set_corner_radius_all(WhiteTheme.BUTTON_RADIUS)
		box.content_margin_left = WhiteTheme.BUTTON_PADDING
		box.content_margin_right = WhiteTheme.BUTTON_PADDING
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", WhiteTheme.TEXT)
	b.add_theme_color_override("font_pressed_color", WhiteTheme.ACCENT)
	b.add_theme_color_override("font_disabled_color", WhiteTheme.BUTTON_DISABLED_TEXT)
	b.pressed.connect(action)
	return b
