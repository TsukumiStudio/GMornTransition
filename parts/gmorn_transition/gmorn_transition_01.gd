extends "res://addons/gmorn_transition/parts/gmorn_transition/gmorn_transition_00.gd"


func set_progress(value: float) -> void:
	if transition_material == null:
		return
	transition_material.set_shader_parameter(progress_parameter, value)

## `%Surface` か、最初に見つかった `ColorRect`。
func _find_surface() -> ColorRect:
	var named := get_node_or_null("%Surface")
	if named is ColorRect:
		return named as ColorRect
	for child in get_children():
		if child is ColorRect:
			return child as ColorRect
	return null

func _create_surface() -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "Surface"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color.WHITE
	# 覆っている間に押せると、切り替えの最中に次の場面の釦へ届く。
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(rect)
	return rect

## 置いてある材質は複製してから使う。そのまま触ると同じシェーダを使う他の場所まで
## 動き、資源として保存されるので途中の値がエディタに残る。
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

func _ready() -> void:
	surface = _find_surface()
	if surface == null:
		surface = _create_surface()
	_prepare_material()
	set_progress(0.0)
	visible = false

## 既定の timer は木が止まっていても進み、時間の倍率には従う。覆いの進み方
## （`TWEEN_PAUSE_PROCESS`）と揃えないと、遅回しのときだけ保つ間が置いていかれる。
func _hold() -> void:
	if hold_duration <= 0.0:
		return
	await get_tree().create_timer(hold_duration).timeout

## 画面が無いとき、長さが0のときは途中を飛ばす。見えないものを待つと検証が遅くなる。
func animations_disabled() -> bool:
	return DisplayServer.get_name() == "headless" \
		or is_zero_approx(cover_duration + reveal_duration)

func _fade_audio(to_db: float, duration: float) -> void:
	if audio_player == null or not is_instance_valid(audio_player):
		return
	# 前の淡くしを止めずに重ねると、音量が行ったり来たりする。
	if audio_tween and audio_tween.is_valid():
		audio_tween.kill()
	if duration <= 0.0 or animations_disabled():
		audio_player.volume_db = to_db
		return
	audio_tween = create_tween()
	# 切り替えの最中に木を止めても淡くしは進める。
	audio_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	audio_tween.tween_property(audio_player, "volume_db", to_db, duration)

func fade_audio_out(duration: float) -> void:
	_fade_audio(audio_silent_db, duration)

func _set_exiting(value: bool) -> void:
	if transition_material == null:
		return
	transition_material.set_shader_parameter(exiting_parameter, value)

func _animate_progress(from: float, to: float, duration: float, ease: Tween.EaseType,
		trans: Tween.TransitionType = Tween.TRANS_CUBIC) -> void:
	# 前の切り替えを止めずに重ねると、数が行ったり来たりする。
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	# 切り替えの最中に木を止めても覆いは進める。
	active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	active_tween.tween_method(set_progress, from, to, duration) \
		.set_trans(trans).set_ease(ease)
	await active_tween.finished

## 覆い切り、`hold_duration` だけ置いてから返る。`Audio.FADE` で音も消す。
func cover(audio := Audio.KEEP) -> void:
	visible = true
	_set_exiting(false)
	set_progress(0.0)
	if audio == Audio.FADE:
		fade_audio_out(cover_duration)
	if animations_disabled():
		set_progress(1.0)
		return
	# 緩急を付けると低い progress が続き、段階表示では開始が止まって見える。
	await _animate_progress(0.0, 1.0, cover_duration, Tween.EASE_IN, Tween.TRANS_LINEAR)
	await _hold()

## 開いた後に間を置いてから上げたいときは、`reveal()` に KEEP を渡して呼ぶ側がこれを呼ぶ。
func fade_audio_in(duration: float) -> void:
	_fade_audio(audio_base_db, duration)

## 開き切ったら隠す。覆いは入力を受け取るので、残すと透明なのに押せない場所ができる。
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

func set_audio_base_db(base_db: float) -> void:
	audio_base_db = base_db

## `base_db` を省くと渡した時点の音量を基準にする。音量設定が変わったら渡し直す。
func set_audio_player(player: AudioStreamPlayer, base_db := INF) -> void:
	audio_player = player
	set_audio_base_db(base_db if base_db < INF else (player.volume_db if player != null else 0.0))

## 曲を差し替える側は必ず通す。淡く消したまま次の曲を鳴らすと無音で流れ続ける。
func restore_audio() -> void:
	_fade_audio(audio_base_db, 0.0)
