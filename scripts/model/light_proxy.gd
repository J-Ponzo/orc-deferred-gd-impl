extends ORC_ProxyObject
class_name ORC_DeferredGD_LightProxy

var shadow_enabled_last_frame : bool

var has_shadow_changed = false 

func update_override() -> void:
	super_update()

	has_shadow_changed = false
	if node.shadow_enabled != shadow_enabled_last_frame:
		primary_data.shadow_enabled = node.shadow_enabled
		has_shadow_changed = true