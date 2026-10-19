@tool
extends EditorPlugin

## 自動読み込みには登録しない。切り替えは場面ごとに置くものなので「ノードを追加」に出す。

const TYPE_NAME := "GMornTransition"

func _script_path() -> String:
	return get_script().resource_path.get_base_dir().path_join("gmorn_transition.gd")

func _enter_tree() -> void:
	add_custom_type(TYPE_NAME, "CanvasLayer", load(_script_path()), null)

func _exit_tree() -> void:
	remove_custom_type(TYPE_NAME)
