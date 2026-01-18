# TODO : put in open_render_craft if we keep it
extends ORC_SafeRID
class_name ORC_VertexArrayRID

func is_valid() -> bool:
	return rid.is_valid()
