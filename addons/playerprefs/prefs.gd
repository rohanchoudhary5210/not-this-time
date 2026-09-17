extends Node

const PATH := "user://prefs.save"
const SAVE_DELAY := 2.0

var _data: Dictionary = {}
var _dirty := false
var _timer := 0.0

# --------------------
# INIT
# --------------------
func _ready():
	_load()

func _process(delta):
	if _dirty:
		_timer += delta
		if _timer >= SAVE_DELAY:
			save()

# --------------------
# KEY ALIASES (Compatibility Map)
# --------------------
const KEY_ALIASES := {
	"maximum_pots": ["maximum_pots", "Maximum_pots", "max_pots"],
	"Maximum_pots": ["maximum_pots", "Maximum_pots", "max_pots"],
	"max_pots": ["maximum_pots", "Maximum_pots", "max_pots"],
	
	"total_pots": ["total_pots", "TotalPots"],
	"TotalPots": ["total_pots", "TotalPots"],
	
	"coins": ["coins", "Coins"],
	"Coins": ["coins", "Coins"],
	
	"rank": ["rank", "Rank"],
	"Rank": ["rank", "Rank"],
	
	"max_rank": ["max_rank", "MaxRank"],
	"MaxRank": ["max_rank", "MaxRank"],
	
	"rank_points": ["rank_points", "RankPoints"],
	"RankPoints": ["rank_points", "RankPoints"],
	
	"matches_won": ["matches_won", "MatchesWon"],
	"MatchesWon": ["matches_won", "MatchesWon"],
	
	"matches_lost": ["matches_lost", "MatchesLost"],
	"MatchesLost": ["matches_lost", "MatchesLost"],
	
	"matches_played": ["matches_played", "MatchesPlayed"],
	"MatchesPlayed": ["matches_played", "MatchesPlayed"],
	
	"powerup_no_wind": ["powerup_no_wind", "NoWind", "power_up_no_wind"],
	"NoWind": ["powerup_no_wind", "NoWind", "power_up_no_wind"],
	"power_up_no_wind": ["powerup_no_wind", "NoWind", "power_up_no_wind"],
	
	"powerup_timer": ["powerup_timer", "Timer", "power_up_timer"],
	"Timer": ["powerup_timer", "Timer", "power_up_timer"],
	"power_up_timer": ["powerup_timer", "Timer", "power_up_timer"],
	
	"powerup_projectile": ["powerup_projectile", "Projectile", "power_up_projectile"],
	"Projectile": ["powerup_projectile", "Projectile", "power_up_projectile"],
	"power_up_projectile": ["powerup_projectile", "Projectile", "power_up_projectile"],
	
	"equipped_cornbag": ["equipped_cornbag", "BagEquipped"],
	"BagEquipped": ["equipped_cornbag", "BagEquipped"],
	
	"equipped_board": ["equipped_board", "BoardEquipped"],
	"BoardEquipped": ["equipped_board", "BoardEquipped"],
	
	"maps": ["maps", "MapsUnlocked"],
	"MapsUnlocked": ["maps", "MapsUnlocked"],
	
	"crate_slots": ["crate_slots", "CrateSlots"],
	"CrateSlots": ["crate_slots", "CrateSlots"],
	
	"is_tutorial_done": ["is_tutorial_done", "tutorial_completed"],
	"tutorial_completed": ["is_tutorial_done", "tutorial_completed"],
}

# --------------------
# CORE API
# --------------------
func set_value(key: String, value) -> void:
	_data[key] = value
	if KEY_ALIASES.has(key):
		for alias in KEY_ALIASES[key]:
			_data[alias] = value
	_dirty = true

func get_value(key: String, default_value = null):
	if _data.has(key):
		return _data[key]
	if KEY_ALIASES.has(key):
		for alias in KEY_ALIASES[key]:
			if _data.has(alias):
				return _data[alias]
	return default_value

func has_key(key: String) -> bool:
	if _data.has(key):
		return true
	if KEY_ALIASES.has(key):
		for alias in KEY_ALIASES[key]:
			if _data.has(alias):
				return true
	return false

func delete_key(key: String) -> void:
	var erased := false
	if _data.erase(key):
		erased = true
	if KEY_ALIASES.has(key):
		for alias in KEY_ALIASES[key]:
			if _data.erase(alias):
				erased = true
	if erased:
		_dirty = true

func clear_all():
	_data.clear()
	_dirty = true
	save()

func get_all_data() -> Dictionary:
	return _data.duplicate()

# --------------------
# TYPED HELPERS
# --------------------
func set_int(key: String, v: int): set_value(key, v)
func get_int(key: String, d := 0) -> int: return int(get_value(key, d))

func set_float(key: String, v: float): set_value(key, v)
func get_float(key: String, d := 0.0) -> float: return float(get_value(key, d))

func set_string(key: String, v: String): set_value(key, v)
func get_string(key: String, d := "") -> String: return str(get_value(key, d))

func set_bool(key: String, v: bool): set_value(key, v)
func get_bool(key: String, d := false) -> bool: return bool(get_value(key, d))

# --------------------
# SAVE / LOAD
# --------------------
func save() -> void:
	var file = FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		var encoded = _encode(_data)
		file.store_string(JSON.stringify(encoded, "\t") + "\n")
		_dirty = false
		_timer = 0.0

func _load() -> void:
	if FileAccess.file_exists(PATH):
		var file = FileAccess.open(PATH, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())

		if typeof(parsed) == TYPE_DICTIONARY:
			_data = _decode(parsed)
		else:
			_data = {}

# --------------------
# SERIALIZATION
# --------------------
func _encode(value):
	if typeof(value) == TYPE_DICTIONARY:
		var result = {}
		for k in value.keys():
			result[k] = _encode(value[k])
		return result

	elif typeof(value) == TYPE_ARRAY:
		return value.map(_encode)

	elif value is Vector2:
		return {"__type": "Vector2", "x": value.x, "y": value.y}

	elif value is Vector3:
		return {"__type": "Vector3", "x": value.x, "y": value.y, "z": value.z}

	return value


func _decode(value):
	if typeof(value) == TYPE_DICTIONARY:
		if value.has("__type"):
			match value["__type"]:
				"Vector2":
					return Vector2(value["x"], value["y"])
				"Vector3":
					return Vector3(value["x"], value["y"], value["z"])

		var result = {}
		for k in value.keys():
			result[k] = _decode(value[k])
		return result

	elif typeof(value) == TYPE_ARRAY:
		return value.map(_decode)

	return value

# --------------------
# FORCE SAVE ON EXIT
# --------------------
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
