#!/bin/sh
# Builds build/GazeCNN.mlpackage from MobileGaze (github.com/yakhyo/gaze-estimation,
# MIT). Downloads PyTorch + coremltools (~500 MB) and the weights from the
# project's GitHub releases. ARCH=resnet18|resnet34|resnet50|mobilenetv2|mobileone_s0.
#
# The weights are trained on Gaze360, whose terms allow research use only and
# extend to models trained on it. The converted model is for your own
# non-commercial research use: never bundle it with an app or host it.
set -eu

cat <<'TERMS'
The MobileGaze weights are trained on the Gaze360 dataset. Its terms
(https://github.com/erkil1452/gaze360/blob/master/LICENSE.md) allow
non-commercial research use only, cover models trained on it, and forbid
redistribution. The converted model must not be shared, hosted or bundled.
TERMS
printf 'Type "yes" to confirm you will use it for non-commercial research only: '
read -r answer || answer=""
[ "$answer" = "yes" ] || { echo "Not confirmed; nothing downloaded." >&2; exit 1; }

ARCH="${ARCH:-mobileone_s0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/build/cnn"
mkdir -p "$WORK"
cd "$WORK"

# The model code needs Python 3.10+. uv fetches one if needed; otherwise use python3.
if command -v uv >/dev/null; then
    [ -d venv ] || uv venv --quiet --python 3.12 venv
    . venv/bin/activate
    uv pip install --quiet torch torchvision coremltools
else
    [ -d venv ] || python3 -m venv venv
    . venv/bin/activate
    pip install --quiet --upgrade pip torch torchvision coremltools
fi

[ -d gaze-estimation ] || git clone --depth 1 https://github.com/yakhyo/gaze-estimation.git
[ -f "$ARCH.pt" ] || curl -fL -o "$ARCH.pt" "https://github.com/yakhyo/gaze-estimation/releases/download/weights/$ARCH.pt"

python "$ROOT/scripts/convert_gaze_model.py" gaze-estimation "$ARCH" "$ARCH.pt" "$ROOT/build/GazeCNN.mlpackage"
echo "Now open ojoS → Settings → Gaze CNN → Load Model… and choose build/GazeCNN.mlpackage"
