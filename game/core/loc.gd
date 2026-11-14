## Minimal localization: picks es/en from {"es": ..., "en": ...} dictionaries.
extends RefCounted

const LANGS := ["es", "en"]

var lang: String = "es"
var strings: Dictionary = {}


func _init(p_strings: Dictionary = {}, p_lang: String = "es") -> void:
	strings = p_strings
	lang = p_lang


## Translate an inline {"es","en"} dictionary.
func t(value: Variant) -> String:
	if value is Dictionary:
		return str(value.get(lang, value.get("en", "")))
	return str(value)


## Translate a UI string key, with optional {placeholder} arguments.
func s(key: String, args: Dictionary = {}) -> String:
	if not strings.has(key):
		return "<" + key + ">"
	return t(strings[key]).format(args)


func toggle() -> void:
	lang = "en" if lang == "es" else "es"
