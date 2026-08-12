extends CanvasLayer

## 画面を覆ってから開く、場面の切り替え。
##
## 切り替えの絵は `progress` という1つの数（0で何も無い、1で覆い切った）だけで
## 決まるようにする。数の進め方をこちらが持ち、絵の作り方はシェーダが持つ。
## 分けておくと、絵を差し替えても待ち方は変わらない。
##
## 使う側は待てる。
##
##   await transition.cover()   覆い切るまで待つ
##   （ここで場面を入れ替える）
##   await transition.reveal()  開き切るまで待つ
##
## 材質は必ず複製してから使う。`.tscn` に置いた `ShaderMaterial` をそのまま
## 触ると、同じシェーダを使っている他の場所まで一緒に動く。しかもその材質は
## 資源として保存されるため、エディタで開き直すと途中の値が残っている。
##
## 画面のない実行と、長さを0にしたときは、途中を飛ばして終端の値へ移る。
## 見えないものを待つと、検証がその分だけ遅くなる。
##
## 使い方は README.md を参照。

## 覆うのにかける長さ（秒）。
@export_range(0.0, 3.0, 0.05) var cover_duration := 0.55
## 開くのにかける長さ（秒）。開くほうを長くすると、次の場面が現れる間が取れる。
@export_range(0.0, 3.0, 0.05) var reveal_duration := 0.75
## 覆いに使うシェーダ。`progress` を受け取るものであれば何でもよい。
##
## 覆いの `ColorRect` を自分で置いてある場合は、そちらの材質が優先される。
@export var transition_shader: Shader
## シェーダへ渡す数の名前。既定の `progress` から変えたいときに使う。
@export var progress_parameter := "progress"

## 覆いに使う `ColorRect`。`.tscn` に置いていなければ自分で作る。
var surface: ColorRect
var transition_material: ShaderMaterial
var active_tween: Tween

func _ready() -> void:
	surface = _find_surface()
	if surface == null:
		surface = _create_surface()
	_prepare_material()
	set_progress(0.0)
	visible = false

## 覆い切るまで待つ。切り替えの前に呼ぶ。
func cover() -> void:
	visible = true
	set_progress(0.0)
	if animations_disabled():
		set_progress(1.0)
		return
	await _animate_progress(0.0, 1.0, cover_duration, Tween.EASE_IN)

## 開き切るまで待つ。切り替えた後に呼ぶ。開き切ったら自分を隠す。
##
## 隠すのは、覆いが `mouse_filter` で入力を受け取るためである。開いたまま
## 残しておくと、透明なのに押せない場所ができる。
func reveal() -> void:
	set_progress(1.0)
	if animations_disabled():
		set_progress(0.0)
		visible = false
		return
	await _animate_progress(1.0, 0.0, reveal_duration, Tween.EASE_OUT)
	visible = false

## いま覆っている度合い。0で何も無い、1で覆い切っている。
func set_progress(value: float) -> void:
	if transition_material == null:
		return
	transition_material.set_shader_parameter(progress_parameter, value)

## 途中を飛ばすか。画面が無いとき、長さが0のときは飛ばす。
func animations_disabled() -> bool:
	return DisplayServer.get_name() == "headless" \
		or is_zero_approx(cover_duration + reveal_duration)

func _animate_progress(from: float, to: float, duration: float, ease: Tween.EaseType) -> void:
	# 前の切り替えが残っていたら止める。重ねると数が行ったり来たりする。
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	# 切り替えの最中に木を止めることがある。止まっても覆いは進めたい。
	active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	active_tween.tween_method(set_progress, from, to, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(ease)
	await active_tween.finished

## 覆いを探す。`%Surface` か、最初に見つかった `ColorRect` を使う。
func _find_surface() -> ColorRect:
	var named := get_node_or_null("%Surface")
	if named is ColorRect:
		return named as ColorRect
	for child in get_children():
		if child is ColorRect:
			return child as ColorRect
	return null

## 覆いを自分で作る。`.tscn` を用意しなくても、この台本を付けるだけで動くようにする。
func _create_surface() -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "Surface"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color.WHITE
	# 覆っている間は下を押させない。押せてしまうと、切り替えの最中に次の場面の
	# 釦へ届く。
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(rect)
	return rect

## 材質を用意する。複製してから使うことがここでの肝。
func _prepare_material() -> void:
	var existing := surface.material as ShaderMaterial
	if existing != null:
		transition_material = existing.duplicate() as ShaderMaterial
	elif transition_shader != null:
		transition_material = ShaderMaterial.new()
		transition_material.shader = transition_shader
	else:
		return
	surface.material = transition_material
