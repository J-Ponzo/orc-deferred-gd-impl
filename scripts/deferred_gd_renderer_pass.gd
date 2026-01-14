extends ORC_RenderPassBase
class_name ORC_DeferredGDRendererPass

var deferred_gd_renderer : ORC_DeferredGDRenderer

func setup_override() -> void:
	super_setup()
	deferred_gd_renderer = renderer as ORC_DeferredGDRenderer

func cleanup_override() -> void:
	super_cleanup()
