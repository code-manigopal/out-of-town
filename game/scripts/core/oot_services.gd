class_name OOTServices
extends RefCounted
## Looks up the StoryState / StoryDB autoloads at runtime so scripts also compile
## inside a --script SceneTree (tests/run_tests.gd), where autoload names are not
## compile-time identifiers.


static func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


static func state() -> Node:
	return _root().get_node_or_null("StoryState")


static func db() -> Node:
	return _root().get_node_or_null("StoryDB")
