"""Generate a transparent-background variant of the FlutterSync logo.

Strategy: chroma-aware background removal with Gaussian-blurred alpha for
smooth edges. The source logo has a chromatic foreground (cyan/teal ring,
dark-blue type) on a grayscale background; we mark a pixel as foreground
when it has noticeable color saturation OR is dark enough to belong to the
small "ADVANCED OFFLINE FIRST SYNC" subtitle text.

If a higher-quality result is desired, install `rembg` and re-run with the
`--rembg` flag — that path uses a U2Net segmentation model and is slower
but cleaner around soft shadows.

The script is a one-shot reproducibility tool kept under `branding/` and
is not part of the Dart package.

Usage:
    python _make_transparent.py            # chroma-based (default, fast)
    python _make_transparent.py --rembg    # rembg ML-based (better, slow)
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageFilter
import numpy as np

HERE = Path(__file__).resolve().parent
SRC = HERE / "flutter_sync_logo.png"
DST = HERE / "flutter_sync_logo_transparent.png"


def remove_via_chroma() -> None:
    """Chroma-aware background removal with feathered alpha edges."""
    img = Image.open(SRC).convert("RGBA")
    arr = np.array(img)
    r = arr[:, :, 0].astype(np.int16)
    g = arr[:, :, 1].astype(np.int16)
    b = arr[:, :, 2].astype(np.int16)

    max_rgb = np.maximum(np.maximum(r, g), b)
    min_rgb = np.minimum(np.minimum(r, g), b)
    chroma = max_rgb - min_rgb

    # A pixel is foreground when:
    # - it has visible chroma (cyan ring, blue text), OR
    # - it is dark enough to be the gray subtitle's strokes.
    foreground = (chroma > 18) | (min_rgb < 140)
    alpha = np.where(foreground, 255, 0).astype(np.uint8)

    # Feather the binary mask so we get anti-aliased edges around glyphs and
    # arrow tips rather than the harsh stair-step you get from threshold masks.
    alpha_img = Image.fromarray(alpha, mode="L").filter(
        ImageFilter.GaussianBlur(radius=1.2),
    )
    arr[:, :, 3] = np.array(alpha_img)

    Image.fromarray(arr, mode="RGBA").save(DST, optimize=True)


def remove_via_rembg() -> None:
    """ML-based removal via the U2Net segmentation model. Requires `rembg`."""
    try:
        from rembg import remove
    except ImportError as e:
        raise SystemExit(
            "rembg is not installed. Run: pip install rembg",
        ) from e
    with SRC.open("rb") as fp:
        out_bytes = remove(fp.read())
    DST.write_bytes(out_bytes)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--rembg",
        action="store_true",
        help="Use rembg (U2Net) instead of the chroma-aware default.",
    )
    args = parser.parse_args()

    if not SRC.exists():
        print(f"Source not found: {SRC}", file=sys.stderr)
        return 1

    if args.rembg:
        remove_via_rembg()
        print(f"rembg → {DST.name} ({DST.stat().st_size:,} bytes)")
    else:
        remove_via_chroma()
        print(f"chroma → {DST.name} ({DST.stat().st_size:,} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
