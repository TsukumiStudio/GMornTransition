shader_type canvas_item;

// 斜めの帯が横切っていく切り替え。
//
// 境目に幅（`softness`）を持たせる。真っ直ぐな線で切ると、画素の並びが
// そのまま段になって見える。

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float angle : hint_range(-1.0, 1.0) = 0.35;
uniform float softness : hint_range(0.001, 0.5) = 0.08;

void fragment() {
	float position = UV.x + (UV.y - 0.5) * angle;
	// 端まで確実に覆えるよう、進み具合を境目の幅の分だけ広げて動かす。
	float edge = progress * (1.0 + softness * 2.0) - softness;
	COLOR = vec4(fill_color.rgb, fill_color.a * (1.0 - smoothstep(edge, edge + softness, position)));
}
