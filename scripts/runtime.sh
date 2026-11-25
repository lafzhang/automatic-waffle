# Sourced by the Linux setup and check entry points.
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_root/env/versions.env"

WORKBENCH_HOME="${WORKBENCH_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/automatic-waffle}"
python_env="$WORKBENCH_HOME/python-$PYTHON_VERSION"
python_bin="${WORKBENCH_PYTHON:-$python_env/bin/python}"
fiji_dir="$WORKBENCH_HOME/fiji-$FIJI_BUILD"
fiji_bin="${WORKBENCH_FIJI:-$fiji_dir/fiji-linux-x64}"
export R_VERSION BIOC_VERSION CRAN_REPO
export R_LIBS_USER="${WORKBENCH_R_LIBS:-$WORKBENCH_HOME/r-library-$R_VERSION-$BIOC_VERSION}"
export UV_PYTHON_INSTALL_DIR="$WORKBENCH_HOME/uv-python"
export UV_CACHE_DIR="$WORKBENCH_HOME/uv-cache"

if [[ -n "${WORKBENCH_RSCRIPT:-}" ]]; then
    rscript_bin="$WORKBENCH_RSCRIPT"
elif [[ -x "/opt/R/$R_VERSION/bin/Rscript" ]]; then
    rscript_bin="/opt/R/$R_VERSION/bin/Rscript"
else
    rscript_bin=Rscript
fi

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Required executable unavailable: %s\n' "$1" >&2
        return 1
    fi
}
