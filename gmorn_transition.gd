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
## **切り替えには2種類ある。**曲ごと入れ替えるものと、同じ曲の続きのもの。
## 前者は覆いに合わせて音も淡くしないと、覆い切って開いた先で前の曲が鳴り続け、
## どこかでぶつ切りに変わる。呼ぶ側が `Audio.FADE` を渡して選ぶ。
##
## 使い方は README.md を参照。

## 覆うのにかける長さ（秒）。
@export_range(0.0, 3.0, 0.05) var cover_duration := 0.55
## 開くのにかける長さ（秒）。開くほうを長くすると、次の場面が現れる間が取れる。
@export_range(0.0, 3.0, 0.05) var reveal_duration := 0.75
## 覆い切ってから `cover()` が返るまで、覆ったまま置く長さ（秒）。
##
## 場面の入れ替えは覆い切った直後に走るため、ここが0だと切り替えた先が
## すぐ明け始める。使う側が各自でタイマーを足すと、間が場面ごとにばらける。
## **切り替えの間はここ1つで決める。**
@export_range(0.0, 5.0, 0.05) var hold_duration := 0.0
## 覆いに使うシェーダ。`progress` を受け取るものであれば何でもよい。
##
## 覆いの `ColorRect` を自分で置いてある場合は、そちらの材質が優先される。
@export var transition_shader: Shader
## シェーダへ渡す数の名前。既定の `progress` から変えたいときに使う。
@export var progress_parameter := "progress"
## 「開いている最中か」を渡す名前。受け取らないシェーダでは何も起きない。
##
## 覆うときと開くときで絵の作り方が変わるものがある（帯は開くときも同じ向きへ
## 抜ける）。`progress` は開くとき 1 から 0 へ戻るだけなので、それだけでは向きを
## 決められない。覆う前に `false`、開く前に `true` をここへ書く。
@export var exiting_parameter := "exiting"

## 覆いに合わせて音をどう扱うか。
enum Audio {
	## 触らない。同じ曲の続きで場面だけ変わるとき。
	KEEP,
	## 覆いと同じ長さで淡くする。曲ごと入れ替えるとき。
	FADE,
}

## 淡く消し切ったときの音量（dB）。
@export var audio_silent_db := -60.0

## 覆いに使う `ColorRect`。`.tscn` に置いていなければ自分で作る。
var surface: ColorRect
var transition_material: ShaderMaterial
var active_tween: Tween
## 淡くする相手。呼ぶ側が `set_audio_player()` で渡す。
var audio_player: AudioStreamPlayer
## 淡くする前の音量（dB）。戻すときの行き先になる。
var audio_base_db := 0.0
var audio_tween: Tween

func _ready() -> void:
	surface = _find_surface()
	if surface == null:
		surface = _create_surface()
	_prepare_material()
	set_progress(0.0)
	visible = false

## 覆い切るまで待つ。切り替えの前に呼ぶ。
##
## `Audio.FADE` を渡すと、覆いと同じ長さで音も消える。曲ごと入れ替える切り替えで
## 使う。渡さなければ音は触らない。
##
## `hold_duration` を入れてあれば、覆い切ったあとその分だけ待ってから返る。
## 途中を飛ばすときは保つ間も飛ばす。見えないものを待つと検証が遅くなる。
func cover(audio := Audio.KEEP) -> void:
	visible = true
	_set_exiting(false)
	set_progress(0.0)
	if audio == Audio.FADE:
		fade_audio_out(cover_duration)
	if animations_disabled():
		set_progress(1.0)
		return
	await _animate_progress(0.0, 1.0, cover_duration, Tween.EASE_IN)
	await _hold()

## 覆ったまま置く。既定のまま作れば木が止まっていても進み、時間の倍率には従う。
## 覆いの進み方（`TWEEN_PAUSE_PROCESS`）と揃えておかないと、遅回しにしたときだけ
## 保つ間が置いていかれる。
func _hold() -> void:
	if hold_duration <= 0.0:
		return
	await get_tree().create_timer(hold_duration).timeout

## 開き切るまで待つ。切り替えた後に呼ぶ。開き切ったら自分を隠す。
##
## 隠すのは、覆いが `mouse_filter` で入力を受け取るためである。開いたまま
## 残しておくと、透明なのに押せない場所ができる。
func reveal(audio := Audio.KEEP) -> void:
	_set_exiting(true)
	set_progress(1.0)
	if audio == Audio.FADE:
		fade_audio_in(reveal_duration)
	if animations_disabled():
		set_progress(0.0)
		visible = false
		return
	await _animate_progress(1.0, 0.0, reveal_duration, Tween.EASE_OUT)
	visible = false

## 淡くする相手を渡す。`base_db` を省くと、渡した時点の音量を基準にする。
##
## 基準は呼ぶ側の設定（音量のつまみ）で動くので、変わったら渡し直す。
func set_audio_player(player: AudioStreamPlayer, base_db := INF) -> void:
	audio_player = player
	set_audio_base_db(base_db if base_db < INF else (player.volume_db if player != null else 0.0))

## 淡くする前の音量を教え直す。
func set_audio_base_db(base_db: float) -> void:
	audio_base_db = base_db

## 音を淡く消す。
func fade_audio_out(duration: float) -> void:
	_fade_audio(audio_silent_db, duration)

## 音を淡く上げ戻す。**待ちを挟んでから上げたいときは、呼ぶ側がここを呼ぶ。**
func fade_audio_in(duration: float) -> void:
	_fade_audio(audio_base_db, duration)

## 音量を基準へ即座に戻す。
##
## **曲を差し替える側は必ずこれを通す。**淡く消したまま次の曲を鳴らすと、その曲が
## 無音で流れ続ける。切り替えを途中でやめた道でも戻し忘れが残らない。
func restore_audio() -> void:
	_fade_audio(audio_base_db, 0.0)

func _fade_audio(to_db: float, duration: float) -> void:
	if audio_player == null or not is_instance_valid(audio_player):
		return
	# 前の淡くしが残っていたら止める。重ねると音量が行ったり来たりする。
	if audio_tween and audio_tween.is_valid():
		audio_tween.kill()
	if duration <= 0.0 or animations_disabled():
		audio_player.volume_db = to_db
		return
	audio_tween = create_tween()
	# 切り替えの最中に木を止めることがある。止まっても淡くしは進めたい。
	audio_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	audio_tween.tween_property(audio_player, "volume_db", to_db, duration)

func _set_exiting(value: bool) -> void:
	if transition_material == null:
		return
	transition_material.set_shader_parameter(exiting_parameter, value)

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
