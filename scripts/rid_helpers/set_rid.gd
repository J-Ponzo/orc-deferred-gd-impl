# TODO : put in open_render_craft if we keep it
extends ORC_SafeRID
class_name ORC_SetRID

func is_valid() -> bool:
	return ORC_RDHelper.get_rd().uniform_set_is_valid(rid)
