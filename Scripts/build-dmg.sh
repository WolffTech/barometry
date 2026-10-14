#!/usr/bin/env bash

# Packs an app into the styled Barometry disk image: the app beside an
# Applications link on the background from Scripts/dmg. The image is not
# signed; Scripts/release.sh signs, notarizes and staples it.
#
#   Scripts/build-dmg.sh <Barometry.app> <output.dmg>
#
# dmgbuild (pure Python) writes the Finder layout directly, so no Finder
# scripting is involved and the result is the same on CI and locally. It is
# installed from Scripts/dmg/requirements.txt into a venv under .tools/.
set -euo pipefail

APP="${1:?usage: build-dmg.sh <app> <output.dmg>}"
OUTPUT="${2:?usage: build-dmg.sh <app> <output.dmg>}"
if [[ ! -d "$APP/Contents" ]]; then
  echo "$APP is not an app bundle" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$ROOT/.tools/dmgbuild"
REQUIREMENTS="$ROOT/Scripts/dmg/requirements.txt"

# dmgbuild 1.6.7 needs Python 3.10 or later; macOS's /usr/bin/python3 is 3.9.
PYTHON="${PYTHON:-python3}"
if ! "$PYTHON" -c 'import sys; sys.exit(sys.version_info < (3, 10))'; then
  echo "$PYTHON is $("$PYTHON" --version 2>&1); set PYTHON to Python 3.10 or later" >&2
  exit 1
fi
if [[ ! -x "$VENV/bin/dmgbuild" || "$REQUIREMENTS" -nt "$VENV/bin/dmgbuild" ]]; then
  echo "Installing dmgbuild into $VENV..."
  rm -rf "$VENV"
  "$PYTHON" -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --disable-pip-version-check \
    --require-hashes --requirement "$REQUIREMENTS"
fi

rm -f "$OUTPUT"
mkdir -p "$(dirname "$OUTPUT")"
# hdiutil occasionally reports "Resource busy" on GitHub runners; retry.
for attempt in 1 2 3; do
  if "$VENV/bin/dmgbuild" -s "$ROOT/Scripts/dmg/settings.py" \
      -D app="$(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")" \
      -D background="$ROOT/Scripts/dmg/background.png" \
      Barometry "$OUTPUT"; then
    break
  fi
  if [[ "$attempt" == 3 ]]; then
    echo "dmgbuild failed after $attempt attempts" >&2
    exit 1
  fi
  echo "dmgbuild failed (attempt $attempt); retrying..." >&2
  sleep 5
done
echo "Disk image ready: $OUTPUT"
