import csv
import sys
from pathlib import Path


def main(output: Path) -> None:
    with (output / "stats.csv").open(encoding="utf-8", newline="") as stream:
        rows = list(csv.DictReader(stream))
    expected = {"width": 4, "height": 3, "count": 12, "mean": 11.5, "min": 0, "max": 23}
    if len(rows) != 1 or {name: float(value) for name, value in rows[0].items()} != expected:
        raise SystemExit(f"Unexpected Fiji statistics: {rows}")
    image = output / "fixture.tif"
    with image.open("rb") as stream:
        if stream.read(4) not in (b"II*\x00", b"MM\x00*") or image.stat().st_size <= 8:
            raise SystemExit("Fiji did not write a TIFF image")
    imagej_version = (output / "imagej-version.txt").read_text(encoding="utf-8").strip()
    if not imagej_version:
        raise SystemExit("Missing Fiji ImageJ version")
    print(f"ImageJ {imagej_version}: verified TIFF and pixel statistics")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python scripts/checks/fiji_output.py OUTPUT_DIRECTORY")
    main(Path(sys.argv[1]))
