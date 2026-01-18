# TODO : put in open_render_craft if we keep it
extends ORC_SafeRID
class_name ORC_TextureRID

func is_valid() -> bool:
	# TODO check if we needs ORC_RDHelper.get_rd().texture_is_valid(rid).
	return rid.is_valid()
