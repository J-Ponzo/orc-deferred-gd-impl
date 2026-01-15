extends ORC_QueueProcessor

func process_override(input : Array[ORC_ProxyData]) -> Array[ORC_ProxyData]:
	var result : Array[ORC_ProxyData]
	for proxy_data : ORC_ProxyData in input:
		var proxy_objects : Array[ORC_ProxyObject]
		if proxy_data is ORC_PrimaryData:
			proxy_objects.append(proxy_data.get_proxy_object())
		else:
			for primary_data : ORC_PrimaryData in proxy_data.get_primary_data_array():
				proxy_objects.append(primary_data.get_proxy_object())
		
		if are_proxy_objectrs_visible(proxy_objects):
			result.append(proxy_data)
			
	return result

func are_proxy_objectrs_visible(proxy_objects : Array[ORC_ProxyObject]) -> bool:
	for proxy_object : ORC_ProxyObject in proxy_objects:
		if proxy_object.node is Node3D:
			var node3d : Node3D = proxy_object.node as Node3D
			if !node3d.is_visible_in_tree():
				return false
	return true
			
