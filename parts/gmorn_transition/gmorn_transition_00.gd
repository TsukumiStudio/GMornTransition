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
