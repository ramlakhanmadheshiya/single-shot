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
}

const HOME_ID: String = "ch1"


static func get_palette(chapter_id: String) -> Dictionary:
	return CHAPTERS.get(chapter_id, CHAPTERS[HOME_ID])


static func ids() -> Array:
	return CHAPTERS.keys()
