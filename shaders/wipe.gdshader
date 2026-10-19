shader_type canvas_item;

// 斜めの帯が横切る切り替え。境目に幅（`softness`）が無いと画素の並びが段になって見える。

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float angle : hint_range(-1.0, 1.0) = 0.35;
uniform float softness : hint_range(0.001, 0.5) = 0.08;

void fragment() {
	float position = UV.x + (UV.y - 0.5) * angle;
	// 境目の幅の分だけ広げて動かさないと、端が覆い切れない。
	float edge = progress * (1.0 + softness * 2.0) - softness;
	COLOR = vec4(fill_color.rgb, fill_color.a * (1.0 - smoothstep(edge, edge + softness, position)));
}
