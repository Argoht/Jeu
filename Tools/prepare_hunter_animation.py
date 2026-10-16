"""Convert every source frame to mobile atlases with an exterior white matte.

Requires PyAV, numpy, OpenCV and Pillow. The original video is never modified.
"""
import argparse
import json
import math
from pathlib import Path

import av
import cv2
import numpy as np
from PIL import Image, ImageFilter


def cutout(image):
    rgb = np.asarray(image.convert("RGB"))
    low = rgb.min(axis=2).astype(np.int16)
    high = rgb.max(axis=2).astype(np.int16)
    candidates = (low >= 215) & ((high - low) <= 24)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(candidates.astype(np.uint8), connectivity=4)
    # Only exterior-connected white is background; the enclosed shirt stays opaque.
    removed = {int(labels[y, x]) for x, y in [(0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1)]}
    removed.discard(0)
    # This fixed-camera clip sometimes closes the gap between left arm and torso.
    # Remove only tall white components wholly in that gap, never the shirt/cuff.
    left, right = int(image.width * 0.30), int(image.width * 0.52)
    top, bottom = int(image.height * 0.28), int(image.height * 0.58)
    brightness_sums = np.bincount(labels.ravel(), weights=low.ravel(), minlength=count)
    for component in range(1, count):
        x, y, width, height, area = stats[component]
        if area > 500 and x >= left and x + width <= right and height > 151 and y < bottom and y + height > top:
            removed.add(component)
        # Small enclosed background fragments survive interpolation around the arm.
        # Bound this correction below the cuff and left of the white shirt.
        in_arm_gap = x >= image.width * 0.34 and x + width <= right and y >= image.height * 0.33 and y + height <= image.height * 0.57
        if in_arm_gap and area >= 8 and brightness_sums[component] / area >= 240:
            removed.add(component)
        # The other hand periodically touches the scarf, enclosing exterior white.
        # Stay below the rolled cuff and to the right of the shirt and scarf knot.
        in_hand_scarf_gap = (x >= image.width * 0.68
                            and x + width <= image.width * 0.88
                            and y >= image.height * 0.37
                            and y + height <= image.height * 0.58)
        if in_hand_scarf_gap:
            removed.add(component)
    alpha = Image.fromarray(np.where(np.isin(labels, list(removed)), 0, 255).astype(np.uint8))
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.5))
    a = np.asarray(alpha, dtype=np.float32) / 255.0
    # Remove white contamination in the softened boundary before compositing.
    clean = np.clip((rgb.astype(np.float32) - 255 * (1 - a[..., None])) / np.maximum(a[..., None], 0.01), 0, 255)
    rgba = np.dstack([clean.astype(np.uint8), np.asarray(alpha)])
    return Image.fromarray(rgba).resize((256, 384), Image.Resampling.LANCZOS)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    with av.open(str(args.source)) as video:
        stream = video.streams.video[0]
        if float(stream.average_rate) != 60.0:
            raise ValueError("Expected the 60 FPS interpolated clip, not the original 25 FPS source.")
        frames = [frame.to_image() for frame in video.decode(stream)]
        source_fps = float(stream.average_rate)
    if len(frames) != 300:
        raise ValueError("AvatarView expects exactly 300 frames (5 seconds at 60 FPS).")
    sprites = [cutout(frame) for frame in frames]
    args.output.mkdir(parents=True, exist_ok=True)
    for sheet_index in range(math.ceil(len(sprites) / 35)):
        atlas = Image.new("RGBA", (1820, 1940))
        for cell, sprite in enumerate(sprites[sheet_index * 35:(sheet_index + 1) * 35]):
            atlas.paste(sprite, ((cell % 7) * 260 + 2, (cell // 7) * 388 + 2))
        atlas.save(args.output / f"hunter_idle_{sheet_index}.png", optimize=True)
    metadata = {"source_frames": len(frames), "source_fps": source_fps,
                "frames": len(sprites), "frame_size": [256, 384], "cell_size": [260, 388],
                "columns": 7, "frames_per_atlas": 35, "padding": 2,
                "playback": "ping_pong", "step_seconds": 1.0 / source_fps}
    (args.output / "animation.json").write_text(json.dumps(metadata, indent=2), encoding="ascii")
    if args.preview:
        preview = Image.new("RGB", (1024, 384), (37, 43, 48))
        for i, index in enumerate([0, 20, 64, len(sprites) - 1]):
            preview.paste(sprites[index], (i * 256, 0), sprites[index])
        preview.save(args.preview)
    print(json.dumps(metadata))


if __name__ == "__main__":
    main()
