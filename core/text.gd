class_name WhiteText
extends RefCounted
## Language choice and text lookup. BASE holds the default texts of the shared screen; a game registers its own
## table, which overrides keys per language and may add keys.

const BASE := {
	"nl": {
		"levels": ["Makkelijk", "Middel", "Moeilijk"],
		"today": "Dagpuzzel #%d",
		"practice": "Oefenen",
		"daily": "Vandaag",
		"count": "Zetten: %d",
		"par": "Par: %d",
		"undo": "Terug",
		"restart": "Opnieuw",
		"next": "Volgende",
		"solved": "Opgelost in %d zetten (par %d) · %s",
		"perfect": "Precies par!",
		"share": "Deel uitslag",
		"copied": "Gekopieerd",
		"no_puzzle": "Voor vandaag is er nog geen puzzel. Kies Oefenen.",
		"hint": "Los de puzzel op in zo min mogelijk zetten.",
		"share_line": "White #%d · %s zetten (par %s)",
		"lang": "EN",
	},
	"en": {
		"levels": ["Easy", "Medium", "Hard"],
		"today": "Daily puzzle #%d",
		"practice": "Practice",
		"daily": "Today",
		"count": "Moves: %d",
		"par": "Par: %d",
		"undo": "Undo",
		"restart": "Restart",
		"next": "Next",
		"solved": "Solved in %d moves (par %d) · %s",
		"perfect": "Exactly par!",
		"share": "Share result",
		"copied": "Copied",
		"no_puzzle": "There is no puzzle for today yet. Choose Practice.",
		"hint": "Solve the puzzle in as few moves as you can.",
		"share_line": "White #%d · %s moves (par %s)",
		"lang": "NL",
	},
}

static var lang := "nl"
static var _merged: Dictionary = BASE


## BASE overridden per language by table; replaces earlier registrations.
static func register(table: Dictionary) -> void:
	var out: Dictionary = BASE.duplicate(true)
	for code in table:
		if not out.has(code):
			out[code] = {}
		for key in table[code]:
			out[code][key] = table[code][key]
	_merged = out


static func t(key: String) -> Variant:
	var table: Dictionary = _merged.get(lang, {})
	if not table.has(key):
		push_error("WhiteText: unknown key '%s' (lang %s)" % [key, lang])
		return key
	return table[key]


static func has_key(key: String) -> bool:
	return _merged.get(lang, {}).has(key)


## Languages of the merged table, "nl" first.
static func languages() -> PackedStringArray:
	var out := PackedStringArray()
	if _merged.has("nl"):
		out.append("nl")
	for code in _merged:
		if code != "nl":
			out.append(code)
	return out


static func has_lang(code: String) -> bool:
	return _merged.has(code)


## The language after the current one, wrapping.
static func next_lang() -> String:
	var list := languages()
	var i := list.find(lang)
	return list[(i + 1) % list.size()] if i >= 0 else list[0]
