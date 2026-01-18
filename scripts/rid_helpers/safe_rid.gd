# TODO : put in open_render_craft c++ api if we keep it. It coulb be possible to automate things from there
extends RefCounted
class_name ORC_SafeRID

var rid : RID:
	get:
		return rid
	set(value):
		free_rid()
		rid = value

func free_rid() -> void:
	if is_valid():
		ORC_RDHelper.get_rd().free_rid(rid)

func is_valid() -> bool:
	assert(false, "ORC_SafeRID._is_valid() must be overridden in subclass")
	return false
