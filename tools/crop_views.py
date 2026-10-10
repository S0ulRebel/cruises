"""Cut the turnaround row of a character sheet into Tripo-ready view images.

Why this is a script and not a judgement call: Tripo reconstructs from the four views
treating them as the same object seen from four angles. If the figures are framed
differently - one a little larger, one sitting lower in its box - the reconstruction
reads the difference as shape and the mesh comes out wrong. Eyeballing four crops gives
four framings. Measuring gives one.

So the rule this enforces is: find the figures, measure them together, and cut every
view with the SAME box size and the SAME foot line. Only the horizontal centre moves.

    python crop_views.py sheet.png --out ../art/characters/captain_live/views
    python crop_views.py sheet.png --row 0.08 0.42 --preview check.png

Background is assumed light and roughly uniform, which is true of the design sheets.
Everything is reported, so a bad detection is visible rather than silent.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

# The four views Tripo wants, in the order they appear on a left-to-right turnaround.
# Sheets carry six (front, 3/4 front, side, back, 3/4 back, side); these are the four
# that carry the most new information, and more views is not better if they disagree.
WANTED = ["front", "three_quarter", "side", "back"]


def modal_colour(pixels: np.ndarray) -> np.ndarray:
    colours, counts = np.unique(pixels.reshape(-1, 3), axis=0, return_counts=True)
    return colours[counts.argmax()].astype(np.int16)


def ink_mask(rgb: np.ndarray, background: np.ndarray | None = None,
             tolerance: int = 18) -> np.ndarray:
    """True where the image differs from its background colour.

    The background is the most common colour in the region being examined, not white
    and not the colour at the top of the sheet. A design sheet puts the turnaround on
    its own panel, a shade off the card it sits on - sample the card and the whole
    panel reads as figure, which welds the six views into one blob.
    """
    if background is None:
        background = modal_colour(rgb[: max(2, rgb.shape[0] // 50)])
    distance = np.abs(rgb.astype(np.int16) - background).sum(axis=2)
    return distance > tolerance * 3


def find_row(mask: np.ndarray) -> tuple[int, int]:
    """Guess the turnaround band: the tallest run of rows that contain figures."""
    per_row = mask.sum(axis=1)
    threshold = per_row.max() * 0.08
    busy = per_row > threshold

    best = (0, 0)
    start = None
    for y, is_busy in enumerate(busy):
        if is_busy and start is None:
            start = y
        elif not is_busy and start is not None:
            if y - start > best[1] - best[0]:
                best = (start, y)
            start = None
    if start is not None and len(busy) - start > best[1] - best[0]:
        best = (start, len(busy))
    return best


def column_profile(mask: np.ndarray) -> np.ndarray:
    return mask.sum(axis=0)


def find_figures(mask: np.ndarray, min_gap: int) -> list[tuple[int, int]]:
    """Columns occupied by each figure, split on vertical gaps of empty background."""
    per_column = mask.sum(axis=0)
    # A threshold, not a zero test: one stray pixel of jpeg noise or a soft drop shadow
    # in the gap is enough to weld two figures into one.
    floor = max(2.0, per_column.max() * 0.04)
    occupied = per_column > floor

    spans: list[tuple[int, int]] = []
    start = None
    gap = 0
    for x, is_on in enumerate(occupied):
        if is_on:
            if start is None:
                start = x - gap if gap and spans and x - gap <= spans[-1][1] else x
            gap = 0
        elif start is not None:
            gap += 1
            if gap >= min_gap:
                spans.append((start, x - gap))
                start = None
                gap = 0
    if start is not None:
        spans.append((start, len(occupied)))

    # Drop slivers - stray marks, labels, a dropped shadow.
    if spans:
        widest = max(b - a for a, b in spans)
        spans = [s for s in spans if (s[1] - s[0]) > widest * 0.25]
    return spans


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheet", type=Path)
    ap.add_argument("--out", type=Path, default=Path("views"))
    ap.add_argument("--row", nargs=2, type=float, metavar=("TOP", "BOTTOM"),
                    help="turnaround band as fractions of image height, if detection misses")
    ap.add_argument("--cols", nargs=2, type=float, metavar=("LEFT", "RIGHT"),
                    help="turnaround band as fractions of image width. A design sheet is "
                         "mostly text and panels, so auto-detection usually needs this")
    ap.add_argument("--names", nargs="*", default=WANTED,
                    help="names for the figures, left to right; extra figures are skipped")
    ap.add_argument("--pad", type=float, default=0.12, help="breathing room around the figure")
    ap.add_argument("--size", type=int, default=1024, help="output square size")
    ap.add_argument("--tolerance", type=int, default=18,
                    help="how far a pixel must differ from the panel background to count "
                         "as figure. Raise it if a textured panel is being read as ink")
    ap.add_argument("--count", type=int, default=0,
                    help="split the band into this many equal slices instead of detecting "
                         "figures. Turnaround rows are evenly spaced, so this is usually "
                         "right and always predictable")
    ap.add_argument("--min-gap", type=int, default=0, help="blank columns that separate two figures")
    ap.add_argument("--preview", type=Path, help="write a contact sheet of the crops for checking")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    image = Image.open(args.sheet).convert("RGB")
    rgb = np.asarray(image)
    height, width = rgb.shape[:2]
    print(f"sheet   {args.sheet.name}  {width}x{height}")

    mask = ink_mask(rgb)

    if args.row:
        top, bottom = int(args.row[0] * height), int(args.row[1] * height)
    else:
        top, bottom = find_row(mask)
    print(f"row     y {top}..{bottom}  ({(bottom - top) / height:.0%} of height)")
    if bottom - top < 20:
        print("could not find a turnaround band - pass --row TOP BOTTOM", file=sys.stderr)
        return 1

    left_edge = int(args.cols[0] * width) if args.cols else 0
    right_edge = int(args.cols[1] * width) if args.cols else width

    # Re-derive the background from inside the band now that we know where it is.
    band_rgb = rgb[top:bottom, left_edge:right_edge]
    band_bg = modal_colour(band_rgb)
    band = ink_mask(band_rgb, band_bg, args.tolerance)
    print(f"panel   background {tuple(int(v) for v in band_bg)}")
    if args.cols:
        print(f"cols    x {left_edge}..{right_edge}")
    if args.count:
        slice_width = band.shape[1] / float(args.count)
        spans = [(int(i * slice_width), int((i + 1) * slice_width)) for i in range(args.count)]
    else:
        min_gap = args.min_gap or max(4, width // 120)
        spans = find_figures(band, min_gap)
    print(f"figures {len(spans)} found: " + ", ".join(f"{a}-{b}" for a, b in spans))

    if len(spans) < len(args.names):
        print(f"expected at least {len(args.names)} figures; adjust --row or --min-gap", file=sys.stderr)
        if not args.dry_run:
            return 1

    # One box size for every view, from the widest and tallest figure present. This is
    # the whole point of the tool: identical framing, identical foot line.
    tallest = 0
    rows_of = []
    for a, b in spans:
        column = band[:, a:b]
        ys = np.where(column.any(axis=1))[0]
        if ys.size == 0:
            rows_of.append((0, column.shape[0]))
            continue
        rows_of.append((int(ys[0]), int(ys[-1]) + 1))
        tallest = max(tallest, int(ys[-1]) - int(ys[0]) + 1)
    widest = max((b - a) for a, b in spans) if spans else 0

    box = int(max(tallest, widest) * (1.0 + args.pad * 2))
    print(f"box     {box}x{box} px per view (tallest figure {tallest}, widest {widest})")
    if box < args.size:
        print(f"        native crop is smaller than --size {args.size}; upscaling will not "
              f"add detail. Recorded in views.json.")

    args.out.mkdir(parents=True, exist_ok=True)
    written = []
    crops = []

    # The background colour of the sheet, reused as the canvas so a composited view
    # looks like it was always photographed against that card.
    card = tuple(int(v) for v in band_bg)

    for index, name in enumerate(args.names):
        if index >= len(spans):
            break
        a, b = spans[index]
        a += left_edge
        b += left_edge
        y0, y1 = rows_of[index]

        # Cut the figure's OWN bounds, never a square window onto the sheet. These
        # characters are tall and narrow on a tightly spaced row, so a square big
        # enough for the height always reaches into the neighbours. Composite instead.
        figure = image.crop((a, top + y0, b, top + y1))

        canvas = Image.new("RGB", (box, box), card)
        pad_px = int(box * args.pad)
        # Shared foot line: every figure's feet land the same distance off the bottom,
        # so a short character reads as short instead of as a differently framed one.
        paste_y = box - pad_px - figure.height
        paste_x = (box - figure.width) // 2
        canvas.paste(figure, (paste_x, max(0, paste_y)))

        if paste_y < 0:
            print(f"    WARNING {name}: figure taller than the box; reduce --pad")

        out = canvas if canvas.size == (args.size, args.size)             else canvas.resize((args.size, args.size), Image.LANCZOS)
        crops.append(out)

        path = args.out / f"{name}.png"
        if not args.dry_run:
            out.save(path)
        written.append({
            "name": name,
            "figure_box": [int(a), int(top + y0), int(b), int(top + y1)],
            "figure_px": [int(figure.width), int(figure.height)],
            "canvas_px": box,
            "output_px": args.size,
            "upscaled": box < args.size,
        })
        print(f"  {name:<14} figure {figure.width}x{figure.height} -> {path.name}")

    if not args.dry_run:
        meta = {
            "source_sheet": str(args.sheet),
            "source_size": [width, height],
            "box_px": box,
            "output_px": args.size,
            "upscale_method": "LANCZOS" if box < args.size else "none",
            "card_colour": list(card),
            "note": "Each figure is cut to its own bounds and composited onto a shared "
                    "square canvas at a shared foot line. Nothing from the surrounding "
                    "sheet is included, and framing is identical by construction.",
            "views": written,
        }
        (args.out / "views.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
        print(f"wrote   {args.out / 'views.json'}")

    if args.preview and crops:
        strip = Image.new("RGB", (args.size * len(crops), args.size), "white")
        for i, crop in enumerate(crops):
            strip.paste(crop, (i * args.size, 0))
        strip.save(args.preview)
        print(f"preview {args.preview}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
