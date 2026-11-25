# Repository instructions

- This repository provisions a Linux research environment. Use `env/versions.env` as the runtime version source and `env/python-requirements.txt` for Python dependency pins.
- Use the smallest relevant profile during development. Run `bash scripts/check.sh all` after a change that affects the shared setup. The mandatory profiles are `python`, `r`, `bioc` and `fiji`. Run the optional `tcga` check after changing the TCGAbiolinks setup.
- Validate on the synthetic fixtures in `examples/fixtures/`. Put analysis outputs under `outputs/`. Keep downloaded datasets, primary microscopy images, clinical data and credentials out of Git.
- Report the runtime, commit SHA, test exit statuses and output paths. Record results from GitHub runners and Codex Cloud tasks separately.
