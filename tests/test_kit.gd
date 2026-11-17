extends RefCounted


func run(check: Callable, _node: Node) -> void:
	var file := FileAccess.get_file_as_string(WhiteKit.INSTALL_PATH + "VERSION").strip_edges()
	check.call(file == WhiteKit.VERSION, "VERSION file equals WhiteKit.VERSION (%s vs %s)" % [file, WhiteKit.VERSION])
	check.call(WhiteKit.INSTALL_PATH == "res://addons/white_kit/", "install path is fixed")
