extends RefCounted
## Manual visual diagnostics write outside the imported project tree.
static func new_run(label: String) -> String:
	var dir := OS.get_cache_dir().path_join("cruises-tests").path_join("%s-%d-%d" %
		[label, OS.get_process_id(), Time.get_ticks_usec()])
	var error := DirAccess.make_dir_recursive_absolute(dir)
	if error != OK:
		push_error("Cannot create diagnostic output directory: " + dir)
	return dir
