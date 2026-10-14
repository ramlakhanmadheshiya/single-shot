class_name Palette
extends RefCounted
## One calm colour story per chapter. Every screen reads its colours from here.

const CHAPTERS: Dictionary = {
	"ch1": {
		"name": "Dawn", "tagline": "Find the angle",
		"top": Color("#FFF4E8"), "bottom": Color("#FFD3C2"),
		"ink": Color("#2D2A4A"), "muted": Color("#2D2A4A", 0.45), "faint": Color("#2D2A4A", 0.08),
		"wall": Color("#2D2A4A"), "target": Color("#FF5D5D"), "orb": Color("#2D2A4A"),
		"accent": Color("#FF8A5B"), "special": Color("#5BC0BE"), "special2": Color("#F2A541"),
		"card": Color("#FFFFFF", 0.55), "dark": false,
	},
	"ch2": {
		"name": "Glass", "tagline": "Panes break once",
		"top": Color("#EAF8F4"), "bottom": Color("#B7E4DA"),
		"ink": Color("#173A45"), "muted": Color("#173A45", 0.45), "faint": Color("#173A45", 0.08),
		"wall": Color("#173A45"), "target": Color("#F2545B"), "orb": Color("#173A45"),
		"accent": Color("#2BA7A0"), "special": Color("#53C4C9"), "special2": Color("#F2A541"),
		"card": Color("#FFFFFF", 0.5), "dark": false,
	},
	"ch3": {
		"name": "Void", "tagline": "Darkness swallows light",
		"top": Color("#23204A"), "bottom": Color("#120F2B"),
		"ink": Color("#F1EEFF"), "muted": Color("#F1EEFF", 0.5), "faint": Color("#F1EEFF", 0.07),
		"wall": Color("#E6E1FF"), "target": Color("#FFB86B"), "orb": Color("#FFFFFF"),
		"accent": Color("#9D8CFF"), "special": Color("#070614"), "special2": Color("#7DE2D1"),
		"card": Color("#FFFFFF", 0.07), "dark": true,
	},
	"ch4": {
		"name": "Shift", "tagline": "Step through the rift",
		"top": Color("#3A2E6E"), "bottom": Color("#7C4F8F"),
		"ink": Color("#FFF1F7"), "muted": Color("#FFF1F7", 0.55), "faint": Color("#FFF1F7", 0.08),
		"wall": Color("#FFE9F3"), "target": Color("#FFD166"), "orb": Color("#FFFFFF"),
		"accent": Color("#FF8FC7"), "special": Color("#6EE7F9"), "special2": Color("#FF8FC7"),
		"card": Color("#FFFFFF", 0.09), "dark": true,
	},
	"ch5": {
		"name": "Prism", "tagline": "One becomes two",
		"top": Color("#0F1328"), "bottom": Color("#1E2046"),
		"ink": Color("#E9EDFF"), "muted": Color("#E9EDFF", 0.5), "faint": Color("#E9EDFF", 0.07),
		"wall": Color("#DCE2FF"), "target": Color("#FF5E8A"), "orb": Color("#FFFFFF"),
		"accent": Color("#8BE9FD"), "special": Color("#8BE9FD"), "special2": Color("#C3A6FF"),
		"card": Color("#FFFFFF", 0.07), "dark": true,
	},
	"ch6": {
		"name": "Gate", "tagline": "Find the switch",
		"top": Color("#F1F4E6"), "bottom": Color("#C9D7B0"),
		"ink": Color("#27352A"), "muted": Color("#27352A", 0.5), "faint": Color("#27352A", 0.08),
		"wall": Color("#27352A"), "target": Color("#E4572E"), "orb": Color("#27352A"),
		"accent": Color("#5E8C3A"), "special": Color("#D9A21B"), "special2": Color("#5E8C3A"),
		"card": Color("#FFFFFF", 0.5), "dark": false,
	},
	"ch7": {
		"name": "Spark", "tagline": "Catch a second wind",
		"top": Color("#2A1B12"), "bottom": Color("#4A2A14"),
		"ink": Color("#FFF2DD"), "muted": Color("#FFF2DD", 0.55), "faint": Color("#FFF2DD", 0.07),
		"wall": Color("#FFE7C2"), "target": Color("#FF6F59"), "orb": Color("#FFFFFF"),
		"accent": Color("#FFB347"), "special": Color("#FFD166"), "special2": Color("#FFB347"),
		"card": Color("#FFFFFF", 0.08), "dark": true,
	},
	"ch8": {
		"name": "Turn", "tagline": "Every hit turns the room",
		"top": Color("#FBEDE8"), "bottom": Color("#E8B4A6"),
		"ink": Color("#3E2430"), "muted": Color("#3E2430", 0.5), "faint": Color("#3E2430", 0.08),
		"wall": Color("#3E2430"), "target": Color("#D7263D"), "orb": Color("#3E2430"),
		"accent": Color("#C8553D"), "special": Color("#7D5BA6"), "special2": Color("#C8553D"),
		"card": Color("#FFFFFF", 0.5), "dark": false,
	},
	"ch9": {
		"name": "Drift", "tagline": "Time it with the platforms",
		"top": Color("#EEF5FB"), "bottom": Color("#CFE3F5"),
		"ink": Color("#1E3A55"), "muted": Color("#1E3A55", 0.5), "faint": Color("#1E3A55", 0.08),
		"wall": Color("#1E3A55"), "target": Color("#F25F5C"), "orb": Color("#1E3A55"),
		"accent": Color("#3D8BD9"), "special": Color("#3D8BD9"), "special2": Color("#F2A541"),
		"card": Color("#FFFFFF", 0.55), "dark": false,
	},
}

const HOME_ID: String = "ch1"

## Colour themes from the Theme pack. "chapters" (free) keeps each chapter's own
## colours; any other theme repaints every chapter in one calm scheme.
const THEMES: Dictionary = {
	"midnight": {"name": "Midnight", "top": "#15161E", "bottom": "#23253A", "ink": "#ECEAF6", "target": "#FF6B81", "accent": "#7AA2F7", "special": "#7DCFFF", "special2": "#E0AF68", "dark": true},
	"paper": {"name": "Paper", "top": "#FAFAF7", "bottom": "#E9E7E1", "ink": "#222222", "target": "#E5484D", "accent": "#222222", "special": "#3E9B8F", "special2": "#D9822B", "dark": false},
	"sepia": {"name": "Sepia", "top": "#F6EEDF", "bottom": "#E2D2B4", "ink": "#4A3B2A", "target": "#C0532E", "accent": "#A66A2C", "special": "#5C8A7A", "special2": "#B0882C", "dark": false},
	"nord": {"name": "Nord", "top": "#2E3440", "bottom": "#3B4252", "ink": "#ECEFF4", "target": "#BF616A", "accent": "#88C0D0", "special": "#8FBCBB", "special2": "#EBCB8B", "dark": true},
	"dracula": {"name": "Dracula", "top": "#282A36", "bottom": "#343746", "ink": "#F8F8F2", "target": "#FF5555", "accent": "#BD93F9", "special": "#8BE9FD", "special2": "#F1FA8C", "dark": true},
	"forest": {"name": "Forest", "top": "#EEF3EA", "bottom": "#C9DBC0", "ink": "#22372B", "target": "#D2553F", "accent": "#3F7D4F", "special": "#2F8F83", "special2": "#C9962E", "dark": false},
	"ocean": {"name": "Ocean", "top": "#0E2233", "bottom": "#14405A", "ink": "#E6F4FB", "target": "#FF8A65", "accent": "#4FC3F7", "special": "#80DEEA", "special2": "#FFD54F", "dark": true},
	"rose": {"name": "Rose", "top": "#FFF1F3", "bottom": "#F7C9D2", "ink": "#4A2030", "target": "#E0405F", "accent": "#C2185B", "special": "#7E57C2", "special2": "#F29E4C", "dark": false},
	"mint": {"name": "Mint", "top": "#EFFAF5", "bottom": "#BFE8D6", "ink": "#16413A", "target": "#F2545B", "accent": "#18A57E", "special": "#2B8BD6", "special2": "#F2A541", "dark": false},
	"sunset": {"name": "Sunset", "top": "#2B1B3D", "bottom": "#7A3B57", "ink": "#FFF0E6", "target": "#FFD166", "accent": "#FF8C61", "special": "#6EE7F9", "special2": "#FFB4A2", "dark": true},
	"mono": {"name": "Mono", "top": "#101010", "bottom": "#1C1C1C", "ink": "#F2F2F2", "target": "#F2F2F2", "accent": "#BDBDBD", "special": "#9E9E9E", "special2": "#E0E0E0", "dark": true},
}

## The active theme, set by SaveSystem from the player's setting.
static var theme_id: String = "chapters"


static func get_palette(chapter_id: String) -> Dictionary:
	var base: Dictionary = CHAPTERS.get(chapter_id, CHAPTERS[HOME_ID])
	if not THEMES.has(theme_id):
		return base
	return themed(base, theme_id)


## A chapter palette repainted in a theme (keeps the chapter's name and tagline).
static func themed(base: Dictionary, id: String) -> Dictionary:
	var th: Dictionary = THEMES[id]
	var ink: Color = Color(th["ink"])
	var dark: bool = bool(th["dark"])
	var out: Dictionary = base.duplicate()
	out["top"] = Color(th["top"])
	out["bottom"] = Color(th["bottom"])
	out["ink"] = ink
	out["muted"] = Color(ink, 0.5)
	out["faint"] = Color(ink, 0.07 if dark else 0.08)
	out["wall"] = ink
	out["orb"] = Color.WHITE if dark else ink
	out["target"] = Color(th["target"])
	out["accent"] = Color(th["accent"])
	out["special"] = Color(th["special"])
	out["special2"] = Color(th["special2"])
	out["card"] = Color("#FFFFFF", 0.08 if dark else 0.5)
	out["dark"] = dark
	return out


## Theme ids in shop order, "chapters" first.
static func theme_ids() -> Array:
	return ["chapters"] + THEMES.keys()


static func theme_name(id: String) -> String:
	return "Chapter colours" if id == "chapters" else str(THEMES.get(id, {}).get("name", id))


## Play order, gentlest idea first. Ids stay as they were so saves keep working.
const ORDER: Array = ["ch1", "ch2", "ch6", "ch9", "ch8", "ch4", "ch3", "ch5", "ch7"]


static func ids() -> Array:
	return ORDER
