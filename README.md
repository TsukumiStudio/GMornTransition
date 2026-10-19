# GMornTransition

## 概要

画面を覆ってから開く場面の切り替えを、待てる形で置くGodotアドオン。

切り替えの絵は `progress` という1つの数（0で何も無い、1で覆い切った）だけで決まるようにしてある。数の進め方をこの部品が持ち、絵の作り方はシェーダが持つ。分けておくと、絵を差し替えても待ち方は変わらない。

## 動作環境

- Godot 4.x（4.7で確認）

画面のない実行（`--headless`）と、長さを0にしたときは、途中を飛ばして終端の値へ移る。

## 何ができるか

- **待てる**。`await cover()` で覆い切るまで、`await reveal()` で開き切るまで止まる。切り替える場所に `await` を2つ並べるだけで書ける。
- **材質を汚さない**。置いてある `ShaderMaterial` は複製してから使う。そのまま触ると同じシェーダを使う他の場所まで動き、途中の値が資源に保存される。
- **置くだけで動く**。`.tscn` に覆いを用意していなければ、画面いっぱいの `ColorRect` を自分で作る。シェーダを1つ指すだけでよい。
- **開いたら消える**。開き切ったら自分を隠す。残すと覆いが入力を受け取り、透明なのに押せない場所ができる。
- **絵を4つ同梱**。塗り潰し（fade）、升目が広がる（mosaic）、斜めに横切る（wipe）、帯（stripe）。

## 使い方

### 1. 取り込む

アドオン一式をリポジトリ直下へ置いてある。取り込む側の `addons/gmorn_transition` へそのまま submodule として足せる。

```
git submodule add https://github.com/TsukumiStudio/GMornTransition.git addons/gmorn_transition
```

Godotのエディタで「プロジェクト設定 → プラグイン」から `GMornTransition` を有効にする。「ノードを追加」に `GMornTransition` が出るようになる。

**リポジトリ直下に `project.godot` は置かない。** 置くとGodotがそこを別のプロジェクトと見なし、submoduleとして取り込んだ側の書き出しからフォルダごと外れる。

### 2. 置く

「ノードを追加」から `GMornTransition` を選び、`transition_shader` に同梱のシェーダを指す。`layer` は他の表示より大きくしておく（100 など）。覆いの `ColorRect` は自分で作られる。

`.tscn` へ書くならこうなる。

```
[node name="Transition" type="CanvasLayer"]
layer = 100
script = ExtResource("gmorn_transition")
transition_shader = ExtResource("fade_shader")
```

自分で覆いを置きたいときは、`ColorRect` を子に置いて材質を付ける。`%Surface` という名前か、最初に見つかった `ColorRect` が使われる。そのときは `transition_shader` は見ない。

### 3. 切り替える

```gdscript
await transition.cover()
# ここで場面を入れ替える
get_tree().change_scene_to_file("res://scenes/next.tscn")
await transition.reveal()
```

### 4. 絵を選ぶ

| シェーダ | 見え方 | 主な設定 |
| --- | --- | --- |
| `shaders/fade.gdshader` | 一色で塗り潰す | `fill_color` |
| `shaders/mosaic.gdshader` | 升目ごとに菱形が広がる | `primary_color` / `accent_color` / `grid_size` |
| `shaders/wipe.gdshader` | 斜めの帯が横切る | `fill_color` / `angle` / `softness` |
| `shaders/stripe.gdshader` | 帯が左右交互に滑り込み、開くときも同じ向きへ抜ける | `primary_color` / `accent_color` / `band_count` / `stagger` / `slant` |

自作のシェーダでも、`progress`（0〜1）を受け取れば動く。名前を変えたいときは `progress_parameter` に入れる。

升目やひし形が育つ形は、途中で図形の間が格子状に空き、下の画面が透ける。帯（`stripe`）は行を隙間なく敷き詰めるので、覆いとして強い。

覆うときと開くときで絵の作り方が変わるシェーダには、`exiting`（開いている最中か）が渡る。`progress` は開くとき 1 から 0 へ戻るだけなので、それだけでは向きを決められない。受け取らないシェーダでは何も起きない。

### 5. 音も一緒に淡くする

曲ごと入れ替える切り替えでは、覆いに合わせて音も消さないと、開いた先で前の曲が鳴り続けてどこかでぶつ切りに変わる。同じ曲の続きなら触らない。

```gdscript
transition.set_audio_player(bgm_player)          # 淡くする相手を渡す
await transition.cover(transition.Audio.FADE)    # 覆いと同じ長さで曲も消える
_play_bgm(next_track)                            # 差し替える側は restore_audio() を通す
await transition.reveal(transition.Audio.FADE)   # 開きと同じ長さで上げ戻す
```

`Audio.KEEP`（既定）なら音は触らない。**開いた後で間を置いてから鳴らしたいとき**は、`reveal()` には `KEEP` を渡し、鳴らす時点で `fade_audio_in()` を呼ぶ。

基準の音量は渡した時点の `volume_db` を覚える。音量のつまみで動いたら `set_audio_base_db()` で教え直す。曲を差し替える側は必ず `restore_audio()` を通す。淡く消したまま次の曲を鳴らすと、その曲が無音で流れ続ける。

### 6. 長さを変える

| 項目 | 何を決めるか | 既定 |
| --- | --- | --- |
| `cover_duration` | 覆うのにかける秒数 | `0.55` |
| `reveal_duration` | 開くのにかける秒数 | `0.75` |
| `hold_duration` | 覆い切ってから `cover()` が返るまで、覆ったまま置く秒数 | `0.0` |

開くほうを長くすると、次の場面が現れる間が取れる。`cover_duration` と `reveal_duration` の両方を0にすると途中を飛ばす。検証を速くしたいときに使える。

切り替えの間は `hold_duration` で決める。使う側が呼び出しごとにタイマーを足すと、場面ごとに間がばらける。途中を飛ばすときは保つ間も飛ばす。

### その他の口

| 呼び出し | 何をするか |
| --- | --- |
| `cover(audio)` | 覆い切るまで待ち、`hold_duration` だけ覆ったまま置く。`Audio.FADE` で音も消す |
| `reveal(audio)` | 開き切るまで待ち、隠れる。`Audio.FADE` で音も上げ戻す |
| `set_progress(value)` | 覆っている度合いを直に指す |
| `set_audio_player(player, base_db)` | 淡くする相手と、戻す先の音量を渡す |
| `set_audio_base_db(db)` | 戻す先の音量を教え直す |
| `fade_audio_out(duration)` / `fade_audio_in(duration)` | 音だけを淡くする |
| `restore_audio()` | 音量を基準へ即座に戻す |
| `animations_disabled()` | 途中を飛ばすかどうか |
| `surface` | 覆いに使っている `ColorRect` |
| `transition_material` | 複製した後の `ShaderMaterial` |

### 手を入れる

`verify.sh` で、覆いの用意と終わり方をヘッドレスで確かめる。

```
./verify.sh
```

## ライセンス

Unlicense（パブリックドメイン）。
