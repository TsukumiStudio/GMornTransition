shader_type canvas_item;

// 帯が左右交互に滑り込んで画面を閉じ、開くときは**同じ向きへ抜けて**いく。
//
// 升目やひし形が育つ形の覆いは、途中で図形と図形の間が格子状に空いたまま残り、
// 下の画面が網目に透けて見える。帯は行を隙間なく敷き詰めるので、開いている場所は
// 1行に多くて1つで、必ず画面の端まで続く。
//
// 進み具合は `progress` 1つだけで決まる（0で何も無い、1で覆い切った）。
// 開くときは `progress` が 1 から 0 へ戻るため、そのままだと帯が来た道を
// 引き返し、入りと出が鏡になって流れが途切れる。`exiting` を立てると、後ろ端から
// 消えて同じ向きへ抜ける（`gmorn_transition.gd` が覆う前と開く前に立てる）。

uniform float progress : hint_range(0.0, 1.0) = 0.0;
// 開いている最中か。覆うときは false、開くときは true。
uniform bool exiting = false;
// 帯の本数。増やすと細かく、減らすと大味になる。
uniform float band_count = 9.0;
// 帯ごとの遅れ。0で全部が同時、大きいほど順に着く。
uniform float stagger : hint_range(0.0, 1.0) = 0.35;
// 帯の先端の傾き。まっすぐだと定規のようになる。
uniform float slant : hint_range(0.0, 0.3) = 0.06;
uniform vec4 primary_color : source_color = vec4(0.1, 0.1, 0.12, 1.0);
uniform vec4 accent_color : source_color = vec4(0.35, 0.35, 0.4, 1.0);

void fragment() {
	float row = floor(UV.y * band_count);
	float local_y = fract(UV.y * band_count);
	// 偶数の行は左から、奇数の行は右から入る。
	bool from_left = mod(row, 2.0) < 0.5;
	// 帯の向きに合わせて座標を裏返す。以降は「0が入口、1が出口」で考えられる。
	float x = from_left ? UV.x : 1.0 - UV.x;

	// 行ごとに少しずつ遅らせる。`progress` が1のときは、遅れた行も必ず1へ
	// 届くように幅を広げてある（届かないと最後まで埋まらない）。
	float delay = row / max(band_count - 1.0, 1.0) * stagger;
	float t = clamp(progress * (1.0 + stagger) - delay, 0.0, 1.0);

	// 先端は少し斜めにする。**傾けたぶん端が伸びる**ので、端から端までを
	// 傾き込みで測って動かす。測らないと、行の隅に細い三角が残る（覆い切る側は
	// 埋め残し、開き切る側は消え残り）。
	float slanted_x = x + slant * (local_y - 0.5);
	// 端はぼかしのぶんだけ外へ出しておく。ぴったりに置くと、覆い切った瞬間と
	// 開き切った瞬間に、隅の1画素だけが半分の濃さで残る。
	float margin = 0.01;
	float near_end = -slant * 0.5 - margin;
	float far_end = 1.0 + slant * 0.5 + margin;
	// 覆うとき: 先端が手前の端から向こうの端へ進む。塗るのはその手前側。
	float distance_to_edge = mix(near_end, far_end, t) - slanted_x;
	if (exiting) {
		// 開くとき: `progress` は 1 から 0 へ戻る。後ろ端を同じ向きへ進めて、
		// 入ってきた側から消す。帯は来た道を引き返さず、そのまま抜けていく。
		distance_to_edge = slanted_x - mix(far_end, near_end, t);
	}

	// 縁は少しだけぼかす。1画素で切ると、斜めの先端が階段になる。
	float softness = 0.004;
	float covered = smoothstep(-softness, softness, distance_to_edge);
	// 先端の内側を明るくして、走ってきた向きを見せる。**止まったら消す。**
	// 消さないと、覆い切った後も向こう端に明るい筋が残り、そこだけ色が違う
	// 帯に見える（覆い切ったのに埋まっていないように見える）。
	float moving = 1.0 - smoothstep(0.85, 1.0, t);
	float highlight = covered * moving * (1.0 - smoothstep(0.0, 0.10, distance_to_edge));
	vec3 color = mix(primary_color.rgb, accent_color.rgb, highlight);
	COLOR = vec4(color, covered);
}
