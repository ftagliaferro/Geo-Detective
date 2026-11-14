## Deduction board logic: filter suspects by known traits.
extends RefCounted


## selection: {trait_id: value_id}; empty or missing traits are ignored.
static func matching(suspects: Dictionary, selection: Dictionary) -> Array:
	var out: Array = []
	for id in suspects:
		var traits: Dictionary = suspects[id]["traits"]
		var ok := true
		for t in selection:
			var v = selection[t]
			if v != null and v != "" and traits.get(t) != v:
				ok = false
				break
		if ok:
			out.append(id)
	out.sort()
	return out
