"""Convert a MobileGaze model (github.com/yakhyo/gaze-estimation, MIT) to Core ML.

Usage: python convert_gaze_model.py <repo dir> <arch> <weights .pt> <output .mlpackage>

The exported model takes a 448×448 face crop and outputs `gaze` = [yaw, pitch]
in radians. The softmax-over-bins decoding (Gaze360: 90 bins of 4°, from -180°)
is folded into the model.
"""
import math
import sys

import coremltools as ct
import torch

repo, arch, weights, output = sys.argv[1:5]
sys.path.insert(0, repo)
import models  # noqa: E402  (the repo's utils pull in OpenCV; models don't)
from config import data_config  # noqa: E402

cfg = data_config["gaze360"]
build = {"mobilenetv2": models.mobilenet_v2}.get(arch) or getattr(models, arch)
kwargs = {"inference_mode": True} if arch.startswith("mobileone") else {}
net = build(pretrained=False, num_classes=cfg["bins"], **kwargs)
# weights_only: the checkpoint is a plain state dict; refuse to run pickled code.
net.load_state_dict(torch.load(weights, map_location="cpu", weights_only=True))
net.eval()


class Decoded(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model
        self.register_buffer("idx", torch.arange(cfg["bins"], dtype=torch.float32))

    def forward(self, x):
        yaw, pitch = self.model(x)
        yaw = (torch.softmax(yaw, 1) * self.idx).sum(1) * cfg["binwidth"] - cfg["angle"]
        pitch = (torch.softmax(pitch, 1) * self.idx).sum(1) * cfg["binwidth"] - cfg["angle"]
        return torch.stack([yaw, pitch], 1) * (math.pi / 180)


traced = torch.jit.trace(Decoded(net).eval(), torch.rand(1, 3, 448, 448))

# ImageNet normalization. Core ML image inputs take one scale, so use the mean std (0.226).
std = 0.226
model = ct.convert(
    traced,
    inputs=[ct.ImageType(name="face", shape=(1, 3, 448, 448), color_layout=ct.colorlayout.RGB,
                         scale=1 / (255 * std), bias=[-0.485 / std, -0.456 / std, -0.406 / std])],
    outputs=[ct.TensorType(name="gaze")],
    minimum_deployment_target=ct.target.macOS14,
    compute_precision=ct.precision.FLOAT16,
)
model.short_description = f"MobileGaze {arch} gaze estimation (Gaze360). Output: [yaw, pitch] radians."
model.license = ("Code MIT (github.com/yakhyo/gaze-estimation); weights trained on Gaze360: "
                 "non-commercial research use only; do not redistribute (github.com/erkil1452/gaze360)")
model.save(output)
print(f"Saved {output}")
