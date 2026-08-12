extends SceneTree

## 覆いの用意と、覆う・開くの終わり方を確かめる。
##
## 画面のない実行なので途中は飛ぶ。飛んだときも終端の値へ必ず移ること、
## 開き終えたら隠れることを見る。ここが崩れると、透明なのに押せない場所が残る。

const TRANSITION_PATH := "res://addons/gmorn_transition/gmorn_transition.gd"
const SHADER_PATH := "res://addons/gmorn_transition/shaders/fade.gdshader"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var script: GDScript = load(TRANSITION_PATH)

	# 台本を付けるだけで覆いができる。`.tscn` を用意しなくてよい。
	var transition: CanvasLayer = script.new()
	transition.transition_shader = load(SHADER_PATH)
	root.add_child(transition)
	await process_frame
	assert(transition.surface != null, "覆いが作られていない")
	assert(transition.transition_material != null, "材質が用意されていない")
	assert(not transition.visible, "はじめから覆っている")
	assert(transition.animations_disabled(), "画面が無いのに途中を待とうとしている")

	# 覆うと、覆い切った値まで進んで見えている。
	await transition.cover()
	assert(transition.visible, "覆ったのに見えていない")
	assert(is_equal_approx(_progress(transition), 1.0),
		"覆い切っていない: %f" % _progress(transition))

	# 開くと、元へ戻って隠れる。隠さないと、透明なのに押せない場所が残る。
	await transition.reveal()
	assert(not transition.visible, "開いたのに隠れていない")
	assert(is_equal_approx(_progress(transition), 0.0),
		"開き切っていない: %f" % _progress(transition))

	# 置いてある材質は複製して使う。元を書き換えると、同じシェーダを使う
	# 他の場所まで一緒に動く。
	var shared := ShaderMaterial.new()
	shared.shader = load(SHADER_PATH)
	var placed: CanvasLayer = script.new()
	var rect := ColorRect.new()
	rect.name = "Surface"
	rect.material = shared
	placed.add_child(rect)
	root.add_child(placed)
	await process_frame
	assert(placed.transition_material != shared, "置いてある材質をそのまま使っている")
	placed.set_progress(1.0)
	assert(shared.get_shader_parameter("progress") == null,
		"元の材質まで書き換わっている")

	# 長さを0にすると、画面があっても途中を飛ばす。
	placed.cover_duration = 0.0
	placed.reveal_duration = 0.0
	assert(placed.animations_disabled(), "長さ0でも待とうとしている")

	print("覆い=%s 材質=複製" % placed.surface.name)
	print("GMORN TRANSITION VERIFY: PASS")
	quit(0)

static func _progress(transition: CanvasLayer) -> float:
	return float(transition.transition_material.get_shader_parameter("progress"))
