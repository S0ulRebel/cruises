"""Cut the dialogue bar out of the UI master.

The art session delivers `art/ui/dialogue_frame.png` as a 2172x724 production
master with the bar sitting inside it, and publishes the bar's region in
`art/ui/ENGINE_INTEGRATION.md`. The engine needs it as its own texture, because
NinePatchRect ignores both `region_rect` and an AtlasTexture region and nine-slices
the WHOLE source - which drew the top rail squashed to a quarter of its height and
the bar at 185 px instead of 330.

So the bar is DERIVED rather than hand-trimmed: the master stays byte-for-byte what
they delivered and their hashes still hold, and when they redeliver it this is one
command rather than a measurement someone has to repeat.

    python tools/trim_dialogue_frame.py --out <owned-output.png>
"""

from pathlib import Path
import argparse

from PIL import Image

# Published by the art session in art/ui/ENGINE_INTEGRATION.md: the bar's atlas
# region inside the master. Measured independently here as a check - the solid
# alpha runs 43,178..2129,559, which this contains with a few pixels of soft edge.
REGION = (39, 176, 39 + 2094, 176 + 387)

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / "art" / "ui" / "dialogue_frame.png"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--master", type=Path, default=MASTER)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    master = Image.open(args.master).convert("RGBA")
    if master.size != (2172, 724):
        raise SystemExit("master is %sx%s, not the 2172x724 the region was measured on"
                         % master.size)
    bar = master.crop(REGION)
    bar.save(args.out)
    print("%s  %dx%d" % (args.out, bar.width, bar.height))


if __name__ == "__main__":
    main()
