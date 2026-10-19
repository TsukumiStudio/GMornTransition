extends CanvasLayer


## 画面を覆ってから開く場面の切り替え。`await cover()` / `await reveal()` で待てる。
##
## 絵は `progress`（0で何も無い、1で覆い切った）1つで決まる。数の進め方をここが持ち、
## 絵の作り方はシェーダが持つので、絵を差し替えても待ち方は変わらない。

@export_range(0.0, 3.0, 0.05) var cover_duration := 0.55
@export_range(0.0, 3.0, 0.05) var reveal_duration := 0.75
## 覆い切ってから `cover()` が返るまでの間。切り替えの間はここ1つで決める。使う側が
## 各自でタイマーを足すと、間が場面ごとにばらける。
@export_range(0.0, 5.0, 0.05) var hold_duration := 0.0
## 覆いの `ColorRect` を自分で置いてある場合は、そちらの材質が優先される。
@export var transition_shader: Shader
@export var progress_parameter := "progress"
## 「開いている最中か」を渡す名前。`progress` は開くとき 1 から 0 へ戻るだけで
## 向きを決められないので、向きで絵が変わるシェーダ（stripe）がこれを読む。
@export var exiting_parameter := "exiting"

## 曲ごと入れ替える切り替えで音を触らないと、開いた先で前の曲が鳴り続け、
## どこかでぶつ切りに変わる。呼ぶ側が選ぶ。
enum Audio {
	## 同じ曲の続きで場面だけ変わるとき。
	KEEP,
	## 曲ごと入れ替えるとき。
	FADE,
}

@export var audio_silent_db := -60.0

## `.tscn` に置いていなければ自分で作る。
var surface: ColorRect
var transition_material: ShaderMaterial
var active_tween: Tween
var audio_player: AudioStreamPlayer
## 戻すときの行き先。
var audio_base_db := 0.0
var audio_tween: Tween
