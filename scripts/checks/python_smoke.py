import os
import platform
import sys
from importlib.metadata import version
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def main(output: Path) -> None:
    output.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("MPLCONFIGDIR", str(output / ".matplotlib"))
    expected_python = next(
        line.partition("=")[2]
        for line in (ROOT / "env/versions.env").read_text(encoding="utf-8").splitlines()
        if line.startswith("PYTHON_VERSION=")
    )
    if platform.python_version() != expected_python:
        raise SystemExit(f"Expected Python {expected_python}, got {platform.python_version()}")

    versions = [f"python=={platform.python_version()}"]
    for line in (ROOT / "env/python-requirements.txt").read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        package, expected_version = line.split("==")
        actual_version = version(package)
        if actual_version != expected_version:
            raise SystemExit(f"Expected {line}, got {package}=={actual_version}")
        versions.append(line)
    (output / "versions.txt").write_text("\n".join(versions) + "\n", encoding="utf-8")

    import matplotlib
    import numpy as np
    import pandas as pd
    import tifffile
    from PIL import Image
    from scipy.stats import linregress
    from skimage.io import imread

    matplotlib.use("Agg")
    from matplotlib import pyplot as plt

    measurements = pd.read_csv(ROOT / "examples/fixtures/measurements.csv")
    summary = (
        measurements.groupby("condition", as_index=False)["signal"]
        .agg(count="size", mean="mean")
        .sort_values("condition")
        .reset_index(drop=True)
    )
    expected = pd.DataFrame(
        {"condition": ["control", "treated"], "count": [3, 3], "mean": [4.0, 10.0]}
    )
    pd.testing.assert_frame_equal(summary, expected)
    control = measurements.loc[measurements["condition"] == "control"]
    np.testing.assert_allclose(linregress(control["batch"], control["signal"]).slope, 2.0)
    summary.to_csv(output / "summary.csv", index=False)
    summary.to_excel(output / "summary.xlsx", index=False)
    pd.testing.assert_frame_equal(
        pd.read_excel(output / "summary.xlsx"), expected, check_dtype=False
    )

    fig, axis = plt.subplots(figsize=(4, 3), dpi=100)
    axis.bar(summary["condition"], summary["mean"])
    axis.set(ylabel="Mean signal")
    fig.tight_layout()
    fig.savefig(output / "signal.png")
    plt.close(fig)
    with Image.open(output / "signal.png") as image:
        if image.size != (400, 300):
            raise SystemExit(f"Unexpected plot size: {image.size}")

    pixels = np.arange(12, dtype=np.uint8).reshape(3, 4)
    tifffile.imwrite(output / "fixture.tif", pixels, photometric="minisblack")
    np.testing.assert_array_equal(imread(output / "fixture.tif"), pixels)
    print(f"Python {platform.python_version()}: verified statistics, Excel, PNG and TIFF")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python scripts/checks/python_smoke.py OUTPUT_DIRECTORY")
    main(Path(sys.argv[1]).resolve())
