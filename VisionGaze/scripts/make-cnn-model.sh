#!/bin/sh
# Builds build/GazeCNN.mlpackage from L2CS-Net. Downloads ~1 GB (PyTorch, weights).
# The weights are trained on Gaze360 (research use only), so they are not shipped
# with VisionGaze. Pass WEIGHTS=/path/to/L2CSNet_gaze360.pkl to skip that download.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/build/cnn"
mkdir -p "$WORK"
cd "$WORK"

[ -d venv ] || python3 -m venv venv
. venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet torch torchvision coremltools gdown

[ -d L2CS-Net ] || git clone --depth 1 https://github.com/Ahmednull/L2CS-Net.git

if [ -z "${WEIGHTS:-}" ]; then
    gdown --folder "https://drive.google.com/drive/folders/17p6ORr-JQJcw-eYtG2WGNiuS_qVKwdWd" -O weights
    WEIGHTS="$(find weights -iname '*gaze360*.pkl' | head -1)"
fi
[ -n "$WEIGHTS" ] || { echo "L2CSNet_gaze360.pkl not found"; exit 1; }

python "$ROOT/scripts/convert_l2cs.py" L2CS-Net "$WEIGHTS" "$ROOT/build/GazeCNN.mlpackage"
echo "Now open VisionGaze → Settings → Gaze CNN → Load Model… and choose build/GazeCNN.mlpackage"
