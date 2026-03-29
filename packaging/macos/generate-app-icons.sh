#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h:h}

source_logo="${repo_root}/nook logo.png"
runtime_icon="${repo_root}/Sources/AppShell/Resources/AppIcon.png"
xcassets_dir="${repo_root}/Sources/AppShell/Resources/Assets.xcassets"
appiconset_dir="${xcassets_dir}/AppIcon.appiconset"
bundle_icon="${repo_root}/packaging/macos/AppIcon.icns"

if [[ ! -f "${source_logo}" ]]; then
  echo "Missing source logo at ${source_logo}" >&2
  exit 1
fi

mkdir -p "${appiconset_dir}"

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/nook-icons.XXXXXX")
trap 'rm -rf "${tmp_dir}"' EXIT

padded_base="${tmp_dir}/AppIcon-1024.png"

/usr/bin/sips --padToHeightWidth 640 640 "${source_logo}" --out "${tmp_dir}/padded.png" >/dev/null
/usr/bin/sips --resampleHeightWidth 1024 1024 "${tmp_dir}/padded.png" --out "${padded_base}" >/dev/null
/usr/bin/sips --resampleHeightWidth 512 512 "${padded_base}" --out "${runtime_icon}" >/dev/null

sizes=(
  "16 icon_16x16.png"
  "32 icon_16x16@2x.png"
  "32 icon_32x32.png"
  "64 icon_32x32@2x.png"
  "128 icon_128x128.png"
  "256 icon_128x128@2x.png"
  "256 icon_256x256.png"
  "512 icon_256x256@2x.png"
  "512 icon_512x512.png"
  "1024 icon_512x512@2x.png"
)

for spec in "${sizes[@]}"; do
  size=${spec%% *}
  filename=${spec#* }
  /usr/bin/sips --resampleHeightWidth "${size}" "${size}" "${padded_base}" --out "${appiconset_dir}/${filename}" >/dev/null
done

/usr/bin/sips -s format icns "${runtime_icon}" --out "${bundle_icon}" >/dev/null

echo "Updated:"
echo "  ${runtime_icon}"
echo "  ${appiconset_dir}"
echo "  ${bundle_icon}"
