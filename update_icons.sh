#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
NEW_LOGO="$ROOT/assets/fireracoon_logo.png"

if [[ ! -f "$NEW_LOGO" ]]; then
  echo "Missing source logo: $NEW_LOGO" >&2
  exit 1
fi

should_skip() {
  local file="$1"
  [[ "$file" == ./assets/* ]] && return 0
  [[ "$file" == ./build/* ]] && return 0
  [[ "$file" == "$NEW_LOGO" ]] && return 0
  return 1
}

update_png() {
  local file="$1"
  local w h

  w=$(sips -g pixelWidth "$file" | tail -n1 | awk '{print $2}')
  h=$(sips -g pixelHeight "$file" | tail -n1 | awk '{print $2}')

  if [[ -z "$w" || -z "$h" || ! "$w" =~ ^[0-9]+$ || ! "$h" =~ ^[0-9]+$ ]]; then
    echo "Could not get size for $file, skipping..."
    return
  fi

  echo "Updating $file ($w x $h)"
  sips -z "$h" "$w" "$NEW_LOGO" --out "$file" > /dev/null
}

cd "$ROOT"

find . -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) \
  | grep -iE "logo|icon|ic_launcher" \
  | while read -r file; do
  if should_skip "$file"; then
    continue
  fi
  update_png "$file"
done

if command -v magick >/dev/null 2>&1; then
  ico="$ROOT/windows/runner/resources/app_icon.ico"
  if [[ -f "$ico" ]]; then
    echo "Updating $ico"
    magick "$NEW_LOGO" -define icon:auto-resize=256,128,64,48,32,16 "$ico"
  fi
else
  echo "ImageMagick not found; skipping Windows .ico update"
fi
