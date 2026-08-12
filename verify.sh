#!/bin/sh
# この部品だけを確かめる。
#
# リポジトリ直下に project.godot は置けない。取り込む側が
# addons/gmorn_transition へ submodule として入れるため、そこに project.godot が
# あるとGodotが「別のプロジェクト」と見なしてフォルダごと書き出しから外す。
#
# 代わりに、一時の置き場へ最小のプロジェクトを作って、その中へこの部品を写して回す。
set -eu

addon_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
godot_bin=${GODOT_BIN:-$(command -v godot 2>/dev/null || echo /Applications/Godot.app/Contents/MacOS/Godot)}
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

mkdir -p "$work_dir/addons/gmorn_transition/shaders"
cp "$addon_dir"/*.gd "$addon_dir"/plugin.cfg "$work_dir/addons/gmorn_transition/"
cp "$addon_dir"/shaders/*.gdshader "$work_dir/addons/gmorn_transition/shaders/"
cp "$addon_dir/verify.gd" "$work_dir/verify.gd"

cat > "$work_dir/project.godot" <<'PROJECT'
config_version=5

[application]

config/name="GMornTransition Verify"
config/features=PackedStringArray("4.7")
PROJECT

# シェーダは一度取り込ませないと `load()` で引けない。取り込みだけ先に回す。
"$godot_bin" --headless --path "$work_dir" --import >/dev/null 2>&1 || true
"$godot_bin" --headless --path "$work_dir" --script verify.gd
