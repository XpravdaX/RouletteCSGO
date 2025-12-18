extends Node

signal case_opened(case_node)
signal case_closed()

var current_case: Control = null
var is_case_open: bool = false

func open_case(case_node: Control) -> bool:
	if is_case_open:
		return false
	
	current_case = case_node
	is_case_open = true
	emit_signal("case_opened", case_node)
	return true

func close_case() -> void:
	if is_case_open:
		current_case = null
		is_case_open = false
		emit_signal("case_closed")

func can_open_case() -> bool:
	return not is_case_open
