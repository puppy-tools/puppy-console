@tool
extends EditorPlugin

const AUTOLOAD_PLUGIN_NAME = "Console"

func _enable_plugin():
	add_autoload_singleton (
		AUTOLOAD_PLUGIN_NAME, 
		"res://addons/puppy-console/src/puppy_console.gd"
	)

func _disable_plugin():
	remove_autoload_singleton(AUTOLOAD_PLUGIN_NAME)
