shader_type canvas_item;

// 一色で塗り潰していくだけの切り替え。何も足さない分どこでも合う。

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fill_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	COLOR = vec4(fill_color.rgb, fill_color.a * progress);
}
