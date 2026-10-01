#!/bin/sh
# Builds build/GazeCNN.mlpackage from MobileGaze (github.com/yakhyo/gaze-estimation,
# MIT). Downloads PyTorch + coremltools (~500 MB) and the weights from the
# project's GitHub releases. ARCH=resnet18|resnet34|resnet50|mobilenetv2|mobileone_s0.
set -eu
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
echo "Now open VisionGaze → Settings → Gaze CNN → Load Model… and choose build/GazeCNN.mlpackage"
