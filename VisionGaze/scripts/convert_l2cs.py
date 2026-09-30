"""Convert L2CS-Net (ResNet50, Gaze360) to a Core ML gaze model for VisionGaze.

Usage: python convert_l2cs.py <L2CS-Net repo dir> <weights .pkl> <output .mlpackage>

The exported model takes a face crop and outputs `gaze` = [yaw, pitch] in radians.
The softmax-over-bins decoding (90 bins of 4°, from -180°) is folded into the model.
"""
import math
import sys

import coremltools as ct
import torch
import torchvision

repo, weights, output = sys.argv[1:4]
sys.path.insert(0, repo)
from l2cs.model import L2CS  # noqa: E402

BINS = 90
net = L2CS(torchvision.models.resnet.Bottleneck, [3, 4, 6, 3], BINS)
net.load_state_dict(torch.load(weights, map_location="cpu"))
net.eval()


class Decoded(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model
        self.register_buffer("idx", torch.arange(BINS, dtype=torch.float32))

    def forward(self, x):
        yaw, pitch = self.model(x)
        yaw = (torch.softmax(yaw, 1) * self.idx).sum(1) * 4 - 180
        pitch = (torch.softmax(pitch, 1) * self.idx).sum(1) * 4 - 180
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
model.short_description = "L2CS-Net gaze estimation (Gaze360). Output: [yaw, pitch] radians."
model.license = "Code: MIT (L2CS-Net). Weights: trained on Gaze360 — research use only."
model.save(output)
print(f"Saved {output}")
