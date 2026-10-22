extends RefCounted
## Shared look for every screen. Tokens mirror the Figma file `pham_nhan_nghich_tien` (variables of the same names).

const SURFACE_PAGE := Color("EFE6D2")
const SURFACE_PANEL := Color("F6EFDF")
const BORDER_INK := Color("5B4B3A")
const INK_PRIMARY := Color("2B2118")
const INK_SECONDARY := Color("7A6A58")
const ACCENT_JADE := Color("4F7A5E")
const ACCENT_CINNABAR := Color("B5523B")
const FILL_PROGRESS := Color("E8B4A8")
const STATE_DISABLED := Color("CFC6B2")

const SIZE_TITLE := 28
const SIZE_HEADER := 18
const SIZE_BODY := 14
const SIZE_SMALL := 12
const RADIUS := 3

const FONT_PATH := "res://assets/fonts/NotoSerif-Variable.ttf"


static var _fonts: Dictionary = {}  # weight -> FontVariation, shared so glyph caches are not duplicated
static var _theme: Theme


static func font(weight: int = 400) -> FontVariation:
	if not _fonts.has(weight):
		var v := FontVariation.new()
		v.base_font = load(FONT_PATH)
		v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
		_fonts[weight] = v
	return _fonts[weight]


static func page_background() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = SURFACE_PAGE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	return bg


static func title_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", SIZE_TITLE)
	l.add_theme_font_override("font", font(700))
	return l


static func box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(RADIUS)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func make() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	_theme = t
	t.default_font = font()
	t.default_font_size = SIZE_BODY
	for cls in ["Label", "Button"]:
		t.set_color("font_color", cls, INK_PRIMARY)
	t.set_color("default_color", "RichTextLabel", INK_PRIMARY)
	for c in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK_PRIMARY)
	t.set_color("font_disabled_color", "Button", INK_SECONDARY)
	t.set_stylebox("normal", "Button", box(SURFACE_PANEL, BORDER_INK))
	t.set_stylebox("hover", "Button", box(SURFACE_PAGE, ACCENT_JADE))
	t.set_stylebox("pressed", "Button", box(FILL_PROGRESS, BORDER_INK))
	t.set_stylebox("hover_pressed", "Button", box(FILL_PROGRESS, ACCENT_JADE))
	t.set_stylebox("disabled", "Button", box(STATE_DISABLED, STATE_DISABLED))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(SURFACE_PANEL, BORDER_INK))
	t.set_font("bold_font", "RichTextLabel", font(700))
	return t


## Jade accent button (primary action, or a selected tab kept disabled). Also overrides the disabled style.
static func primary_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", box(ACCENT_JADE, ACCENT_JADE))
	b.add_theme_stylebox_override("hover", box(ACCENT_JADE.lightened(0.1), ACCENT_JADE))
	b.add_theme_stylebox_override("pressed", box(ACCENT_JADE.darkened(0.1), ACCENT_JADE))
	b.add_theme_stylebox_override("disabled", box(ACCENT_JADE, ACCENT_JADE))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, SURFACE_PANEL)


## Locked look from the disabled tokens while the button stays clickable (a click explains why it is locked).
static func set_locked(b: Button, locked: bool) -> void:
	if locked == b.has_theme_stylebox_override("normal"):
		return
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		if locked:
			b.add_theme_stylebox_override(s, box(STATE_DISABLED, STATE_DISABLED))
		else:
			b.remove_theme_stylebox_override(s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		if locked:
			b.add_theme_color_override(c, INK_SECONDARY)
		else:
			b.remove_theme_color_override(c)
