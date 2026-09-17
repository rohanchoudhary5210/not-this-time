extends Node

# Level Lifecycle Events
signal level_started(level_id: int, level_data: Dictionary)
signal level_completed(level_id: int)
signal level_restarted()

# Entity Lifecycle Events
signal entity_died(entity: Node2D)

# Generic Rule & Action Events
signal rule_activated(rule_name: String)
signal rule_action_triggered(action_name: String, payload: Dictionary)
