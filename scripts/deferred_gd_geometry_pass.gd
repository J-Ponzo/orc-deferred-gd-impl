extends ORC_RenderPassBase
class_name ORC_DeferredGDGeometryPass

func setup_override() -> void:
	super_setup()
	print("ORC_DeferredGDGeometryPass.setup()")

func render_override() -> void:
	if renderer.current_cam_data == null:
		return
