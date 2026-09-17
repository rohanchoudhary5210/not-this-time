# PlayerPrefs Plugin for Godot

A lightweight, Unity-style PlayerPrefs system for Godot with JSON storage, custom serialization, and global access.

---

## ✨ Overview

This plugin provides a simple and efficient way to store and retrieve persistent data using a key–value system. It is designed for ease of use, performance, and flexibility in small to medium-sized projects.

---

## 🚀 Features

* Global access via AutoLoad (`Prefs`)
* Simple API (Unity PlayerPrefs-like)
* JSON-based storage (`user://prefs.save`)
* In-memory caching for performance
* Auto-save system with delay
* Manual save support
* Custom serialization (supports complex data)
* Type-safe helper functions
* Reset / clear all data
* Debug access to all saved data

---

## 📦 Installation

1. Copy the plugin into your project:

```
res://addons/playerprefs/
```

2. Open Godot

3. Enable the plugin:

```
Project → Project Settings → Plugins → PlayerPrefs → ON
```

---

## 🧠 Basic Usage

Once enabled, you can use `Prefs` from any script.

### Save Data

```
Prefs.set_int("coins", 100)
Prefs.set_bool("sound", true)
Prefs.set_string("player_name", "Rohan")
```

---

### Load Data

```
var coins = Prefs.get_int("coins", 0)
var sound = Prefs.get_bool("sound", true)
var name = Prefs.get_string("player_name", "Guest")
```

---

### Manual Save

```
Prefs.save()
```

> Auto-save is enabled, but manual save is recommended at key moments (e.g., level complete, exit).

---

## 🧹 Clear Data

```
Prefs.clear_all()
```

Deletes all stored data and updates the file immediately.

---

## 📊 Access All Data (Debug)

```
var data = Prefs.get_all_data()
print(data)
```

---

## 🧪 Example

```
extends Node

func _ready():
	var best = Prefs.get_int("best_score", 0)

	if best < 100:
		Prefs.set_int("best_score", 100)
		Prefs.save()
```

---

## 🔧 Advanced Usage (Serialization)

This plugin supports saving complex data structures.

### Save complex data

```
Prefs.set_value("player", {
	"level": 5,
	"inventory": ["sword", "shield"],
	"position": Vector2(100, 200)
})
```

---

### Load complex data

```
var player = Prefs.get_value("player", {})
print(player["position"])
```

---

## 📁 Save Location

Data is stored in:

```
user://prefs.save
```

Example (Windows):

```
C:\Users\<User>\AppData\Roaming\Godot\app_userdata\<ProjectName>\prefs.save
```

---

## ⚠️ Limitations

* Not secure (data can be edited externally)
* Not suitable for large save systems
* Cannot store Nodes or Resources directly
* Designed for lightweight data only

---

## 📌 Best Practices

* Use simple keys: `"coins"`, `"level"`, `"sound"`
* Always provide default values
* Avoid saving every frame
* Save at checkpoints (level end, exit)
* Store only data (not objects)

---

## 🎯 Use Cases

* Game settings (audio, controls)
* Player progress (levels, coins)
* Lightweight save systems
* Casual and hyper-casual games

---

## ❌ Not Recommended For

* Large RPG save systems
* Complex object graphs
* Multiplayer/server-side persistence

---

## 🧩 Extending the Plugin

You can expand this system with:

* Encryption
* Save slots (multiple profiles)
* Cloud save integration
* Editor debug tools

---

## 👨‍💻 Author

Rohan Choudhary

---


## ⭐ Summary

This plugin acts as a high-level wrapper over Godot’s file system, making data persistence simple, fast, and easy to use while remaining flexible and extensible.

---
