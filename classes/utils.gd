class_name Utils extends RefCounted


static func split_array_evenly(array: Array, n: int) -> Array[Array]:
	if n <= 0:
		push_error("split_array_evenly: n must be > 0")
		return [[]]
	
	var result: Array[Array] = []
	var total := array.size()
	if total == 0:
		for i in range(n): result.append([])
		return result
	
	@warning_ignore("integer_division")
	var base_size: int = total / n
	var remainder := total % n
	var index := 0
	for iter in range(n):
		var sub_size := base_size + (1 if iter < remainder else 0)
		var sub := array.slice(index, index + sub_size)
		result.append(sub)
		index += sub_size
	
	return result
