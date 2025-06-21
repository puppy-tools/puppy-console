class_name PuppyConsole extends Node

#--------------- puppy-console ------------------#
#-- https://github.com/nik0-dev/puppy-console/ --#
#------------------------------------------------#

var interface := ConsoleInterface.new()
var history : Array[String] = []
var history_idx : int = 0
var commands : Dictionary[String, Callable]

enum Workspace { COMMAND_LINE, MONITORS }

@onready var working_node : Node = get_tree().root
var current_workspace : Workspace = Workspace.COMMAND_LINE:
	set = set_workspace

var _monitor_timer := Timer.new()
var _command_line_text_state : String = ""
var _command_line_scroll_state : float = 0.0

static var SETTINGS : ConsoleSettings = preload("res://addons/puppy-console/CONFIG.tres")

func _enter_tree() -> void:
	add_child(interface)
	
var monitors : Dictionary[String, Callable]

func _ready():
	interface.input.text_submitted.connect(process_command)
	add_child(_monitor_timer)
	
	_monitor_timer.one_shot = false
	_monitor_timer.start(SETTINGS.MONITOR_UPDATE_RATE)
	_monitor_timer.timeout.connect(_monitor_tick)
	
	add_command("cls", cls)
	add_command("cd", change_working_node)
	add_command("props", func():
		var property_list = working_node.get_property_list()
		for property in property_list:
			interface.write_line(property["name"])
	)
	add_command("tree", func():
		interface.write_line(get_tree().root.get_tree_string_pretty())
	)
	add_command("nwd", func():
		interface.write_line(working_node.name)
	)
	add_command("add_monitor", add_property_monitor)
	add_command("del_monitor", del_property_monitor)
	add_command("set_prop", working_node.set)
	add_command("commands", func():
		for cmd in commands.keys():
			interface.write_line(cmd)
	)
	add_command("call", working_node.callv)
	add_command("add", func(a, b):
		interface.write_line(str(a + b))
	)
	monitors["randf"] = create_progress_bar_monitor.bind(randf, 20)
	
func _monitor_tick():
	if current_workspace == Workspace.MONITORS:
		cls()
		interface.write_line("[center]───── Monitors ─────[/center]\n")
		for monitor in monitors:
			interface.write_line("[center]%s: %s[/center]" % [monitor, monitors[monitor].call()])

func _input(event: InputEvent) -> void:
	interface.set_status(ConsoleInterface._DEFAULT_STATUS_FORMATTER % [
		working_node.name,
		Workspace.keys()[current_workspace]
	])
	
	if !event.is_echo() && event.is_pressed():
		if interface.output.has_focus():
			if event.is_match(PuppyConsole.SETTINGS.SELECT_ALL_OUTPUT_EVENT):
				interface.output.select_all()
			if event.is_match(PuppyConsole.SETTINGS.COPY_OUTPUT_EVENT):
				DisplayServer.clipboard_set(interface.output.get_selected_text())
		if interface.input.has_focus():
			if event.is_match(PuppyConsole.SETTINGS.CLEAR_INPUT_EVENT):
				interface.clear_input()
			if event.is_match(PuppyConsole.SETTINGS.SELECT_ALL_INPUT_EVENT):
				interface.input.select()
			if event.is_match(PuppyConsole.SETTINGS.COPY_INPUT_EVENT):
				if interface.input.has_selection():
					DisplayServer.clipboard_set(interface.input.get_selected_text())
			if event.is_match(PuppyConsole.SETTINGS.PASTE_INPUT_EVENT):
				if interface.input.has_selection():
					var from = interface.input.get_selection_from_column()
					var to = interface.input.get_selection_to_column()
					interface.input.delete_text(from, to)
					interface.input.deselect()
				interface.input.insert_text_at_caret(DisplayServer.clipboard_get())
			if event.is_match(PuppyConsole.SETTINGS.NEXT_WORD_EVENT) || event.is_match(PuppyConsole.SETTINGS.DELETE_NEXT_WORD_EVENT):
				var from : int = interface.input.caret_column
				if !interface.input.text.is_empty():
					if interface.input.caret_column != interface.input.text.length():
						var initial_lookahead = interface.input.text[interface.input.caret_column]
						var initial_pos = interface.input.caret_column 
				
						for i in range(initial_pos, interface.input.text.length()):
							if initial_lookahead == " ":
								if interface.input.text[interface.input.caret_column] != " ": break
							if initial_lookahead != " ":
								if interface.input.text[interface.input.caret_column] == " ": break
							interface.input.caret_column += 1
				var to : int = interface.input.caret_column
				if event.is_match(PuppyConsole.SETTINGS.DELETE_NEXT_WORD_EVENT): 
					interface.input.delete_text(min(from,to), max(from,to))
							
			if event.is_match(PuppyConsole.SETTINGS.PREV_WORD_EVENT) || event.is_match(PuppyConsole.SETTINGS.DELETE_LAST_WORD_EVENT):
				var from : int = interface.input.caret_column
				if !interface.input.text.is_empty():
					if interface.input.caret_column != 0:
						var initial_lookbehind = interface.input.text[interface.input.caret_column - 1]
						var initial_pos = interface.input.caret_column 
				
						for i in range(initial_pos, -1, -1):
							if initial_lookbehind == " ":
								if interface.input.text[interface.input.caret_column - 1] != " ": break
							if initial_lookbehind != " ":
								if interface.input.text[interface.input.caret_column - 1] == " ": break
							interface.input.caret_column -= 1
				var to : int = interface.input.caret_column
				if event.is_match(PuppyConsole.SETTINGS.DELETE_LAST_WORD_EVENT): 
					interface.input.delete_text(min(from,to), max(from,to))
		if event.is_match(SETTINGS.HISTORY_NEXT_EVENT):
			pass
		if event.is_match(SETTINGS.HISTORY_PREV_EVENT):
			pass
		if event.is_match(SETTINGS.INCREASE_FONT_SIZE_EVENT):
			interface.font_size += 1
		if event.is_match(SETTINGS.DECREASE_FONT_SIZE_EVENT):
			interface.font_size -= 1
		if event.is_match(SETTINGS.CLEAR_OUTPUT_EVENT):
			interface.clear_output()
		if event.is_match(SETTINGS.TOGGLE_CONSOLE_VISIBILITY_EVENT):
			interface.visible = !interface.visible
		if event.is_match(SETTINGS.RESET_FONT_SIZE_EVENT):
			interface.set_font_size(SETTINGS.FONT_SIZE)
		if event.is_match(SETTINGS.TOGGLE_MONITORS):
			if current_workspace != Workspace.MONITORS:
				current_workspace = Workspace.MONITORS
			else:
				current_workspace = Workspace.COMMAND_LINE
		if event.is_match(SETTINGS.DOCK_LEFT):
			var size = DisplayServer.window_get_size()
			interface.handle.size = Vector2(size.x/2, size.y) 
			interface.handle.position = Vector2.ZERO
		if event.is_match(SETTINGS.DOCK_TOP_LEFT):
			var size = DisplayServer.window_get_size()
			interface.handle.size = Vector2(size.x/2, size.y/2) 
			interface.handle.position = Vector2.ZERO
		if event.is_match(SETTINGS.DOCK_TOP):
			var size = DisplayServer.window_get_size()
			interface.handle.size = Vector2(size.x, size.y/2) 
			interface.handle.position = Vector2.ZERO
		if event.is_match(SETTINGS.DOCK_RIGHT):
			var size = DisplayServer.window_get_size()
			interface.handle.size = Vector2(size.x/2, size.y) 
			interface.handle.position = Vector2(size.x/2, 0)
		if event.is_match(SETTINGS.DOCK_TOP_RIGHT):
			var size = DisplayServer.window_get_size()
			interface.handle.size = Vector2(size.x/2, size.y/2) 
			interface.handle.position = Vector2(size.x/2, 0)
		if event.is_match(SETTINGS.DOCK_BOTTOM_LEFT):
			var size = DisplayServer.window_get_size()
			interface.handle.size = Vector2(size.x/2, size.y/2) 
			interface.handle.position = Vector2(0, size.y/2)
		if event.is_match(SETTINGS.DOCK_BOTTOM):
			var size = DisplayServer.window_get_size()
			interface.handle.size = Vector2(size.x, size.y/2) 
			interface.handle.position = Vector2(0, size.y/2)
		if event.is_match(SETTINGS.DOCK_BOTTOM_RIGHT):
			var size = DisplayServer.window_get_size()
			interface.handle.size = Vector2(size.x/2, size.y/2) 
			interface.handle.position = Vector2(size.x/2, size.y/2)
		if event.is_match(SETTINGS.DOCK_FULL):
			interface.handle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			
	if event is InputEventKey && event.is_command_or_control_pressed():
		get_viewport().set_input_as_handled()
	
func history_next(): pass
func history_prev(): pass

func create_progress_bar_monitor(progress: Callable, size: Variant = 10):
	var progress_res = progress.call()
	if typeof(progress_res) != TYPE_FLOAT: return "Nil"
	
	var lerp_res : float = lerpf(0, size, progress_res) 
	@warning_ignore("narrowing_conversion")
	return "[bgcolor=gray][color=black][%s%s][/color][/bgcolor]" % ["#".repeat(lerp_res), ".".repeat(size - floor(lerp_res))]

func cls(): interface.clear_output()

func add_property_monitor(monitor_name: String, property_name: String):
	monitors[monitor_name] = working_node.get.bind(property_name)
func del_property_monitor(monitor_name: String):
	monitors.erase(monitor_name)

@warning_ignore("shadowed_variable_base_class")
func add_command(name: String, callable: Callable):
	commands[name] = callable

func change_working_node(path: String):
	if working_node.has_node(path):
		working_node = working_node.get_node(path)
		
func set_workspace(workspace: Workspace):
	var vscroll = interface.output.get_v_scroll_bar()
	
	match workspace:
		Workspace.COMMAND_LINE:
			interface.output.text = _command_line_text_state
			interface.input.editable = true
			interface.input.placeholder_text = SETTINGS.CLI_INPUT_HINT
			interface.input.call_deferred("grab_focus")
			vscroll.set_deferred("value", _command_line_scroll_state)
		Workspace.MONITORS:
			_command_line_text_state = interface.output.text
			_command_line_scroll_state = vscroll.value
			interface.input.editable = false
			interface.input.placeholder_text = SETTINGS.MONITOR_INPUT_HINT
	
	current_workspace = workspace
			
func process_command(command: String):
	if command.is_empty(): return
	var argv : Array = command.split(" ", false)
	var cmd : String = argv.pop_front()

	if commands.has(cmd):
		interface.write_line(command)
		var conv_args : Array = argv.map(func(arg):
			var conv_arg = str_to_var(arg)
			if conv_arg == null: return arg
			return conv_arg
		)
		commands[cmd].callv(conv_args)
	else:
		interface.write_line("[color=red]Command '%s' not registered.[/color]" % command)
	
	interface.clear_input()
