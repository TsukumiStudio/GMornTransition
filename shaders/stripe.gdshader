shader_type canvas_item;

// 帯が左右交互に滑り込んで画面を閉じ、開くときは同じ向きへ抜ける切り替え。
//
// 開くときは `progress` が 1 から 0 へ戻るので、そのままだと帯が来た道を引き返す。
// `exiting`（gmorn_transition.gd が開く前に立てる）で後ろ端から消して同じ向きへ抜ける。

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool exiting = false;
uniform float band_count = 9.0;
uniform float stagger : hint_range(0.0, 1.0) = 0.35;
uniform float slant : hint_range(0.0, 0.3) = 0.06;
uniform vec4 primary_color : source_color = vec4(0.1, 0.1, 0.12, 1.0);
uniform vec4 accent_color : source_color = vec4(0.35, 0.35, 0.4, 1.0);

void fragment() {
	float row = floor(UV.y * band_count);
	float local_y = fract(UV.y * band_count);
	bool from_left = mod(row, 2.0) < 0.5;
	// 以降は「0が入口、1が出口」。
	float x = from_left ? UV.x : 1.0 - UV.x;

	// `progress` が1のとき遅れた行も1へ届くよう幅を広げる。届かないと最後まで埋まらない。
	float delay = row / max(band_count - 1.0, 1.0) * stagger;
	float t = clamp(progress * (1.0 + stagger) - delay, 0.0, 1.0);

	// 傾けたぶん端が伸びるので、端から端までを傾き込みで測る。測らないと行の隅に
	// 細い三角が残る。
	float slanted_x = x + slant * (local_y - 0.5);
	// 端をぼかしのぶん外へ出さないと、覆い切った瞬間に隅の1画素が半分の濃さで残る。
	float margin = 0.01;
	float near_end = -slant * 0.5 - margin;
	float far_end = 1.0 + slant * 0.5 + margin;
	float distance_to_edge = mix(near_end, far_end, t) - slanted_x;
	if (exiting) {
		// 後ろ端を同じ向きへ進め、入ってきた側から消す。
		distance_to_edge = slanted_x - mix(far_end, near_end, t);
	}

	// 1画素で切ると、斜めの先端が階段になる。
	float softness = 0.004;
	float covered = smoothstep(-softness, softness, distance_to_edge);
	// 先端の明るい筋は止まったら消す。残すと覆い切った後も向こう端に筋が残り、
	// 埋まっていないように見える。
	float moving = 1.0 - smoothstep(0.85, 1.0, t);
	float highlight = covered * moving * (1.0 - smoothstep(0.0, 0.10, distance_to_edge));
	vec3 color = mix(primary_color.rgb, accent_color.rgb, highlight);
	COLOR = vec4(color, covered);
}
