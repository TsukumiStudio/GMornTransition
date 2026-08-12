shader_type canvas_item;

// 升目ごとに菱形が広がって画面を埋めていく切り替え。
//
// 升目の位置で始まりをずらす（`wave`）ため、左上から右下へ流れるように見える。
// 一斉に広げると、ただ画面が明るくなるだけで動きが読めない。

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 primary_color : source_color = vec4(0.992, 0.247, 0.906, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.72, 0.94, 1.0);
uniform vec2 grid_size = vec2(20.0, 12.0);

void fragment() {
	vec2 grid_uv = UV * grid_size;
	vec2 cell = fract(grid_uv) - vec2(0.5);
	vec2 cell_id = floor(grid_uv);
	vec2 normalized_cell = (cell_id + vec2(0.5)) / grid_size;
	float wave = normalized_cell.x * 0.58 + (1.0 - normalized_cell.y) * 0.42;
	float cell_progress = clamp((progress * 1.55 - wave * 0.55) / 0.72, 0.0, 1.0);
	float diamond_distance = abs(cell.x) + abs(cell.y);
	float diamond_size = cell_progress * 1.08;
	float mask_alpha = 1.0 - smoothstep(diamond_size - 0.035, diamond_size + 0.035, diamond_distance);
	// 縁だけ色を変える。境目が見えないと、広がっている最中だと分からない。
	float highlight = 1.0 - smoothstep(diamond_size - 0.16, diamond_size - 0.05, diamond_distance);
	vec3 color = mix(accent_color.rgb, primary_color.rgb, highlight);
	COLOR = vec4(color, mask_alpha);
}
