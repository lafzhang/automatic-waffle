# Sourced by the Linux setup and check entry points.
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$repo_root/env/versions.env"

WORKBENCH_HOME="${WORKBENCH_HOME:-${XDG_CACHE_HOME:-$HOME/.cache}/automatic-waffle}"
python_env="$WORKBENCH_HOME/python-$PYTHON_VERSION"
python_bin="${WORKBENCH_PYTHON:-$python_env/bin/python}"
fiji_dir="$WORKBENCH_HOME/fiji-$FIJI_BUILD"
fiji_bin="${WORKBENCH_FIJI:-$fiji_dir/fiji-linux-x64}"
r_user_prefix="$WORKBENCH_HOME/r-user-$R_VERSION"
micromamba_bin="$WORKBENCH_HOME/micromamba-$MICROMAMBA_VERSION/micromamba"
micromamba_root="$WORKBENCH_HOME/micromamba-root"
export R_VERSION BIOC_VERSION CRAN_REPO
export UV_PYTHON_INSTALL_DIR="$WORKBENCH_HOME/uv-python"
export UV_CACHE_DIR="$WORKBENCH_HOME/uv-cache"

select_r_runtime() {
    rscript_bin="$1"
    local library_path="$WORKBENCH_HOME/r-library-$R_VERSION-$BIOC_VERSION"
    if [[ "$rscript_bin" == "$r_user_prefix/bin/Rscript" ]]; then
        library_path="$library_path-user"
    fi
    export R_LIBS_USER="${WORKBENCH_R_LIBS:-$library_path}"
}

if [[ -n "${WORKBENCH_RSCRIPT:-}" ]]; then
    select_r_runtime "$WORKBENCH_RSCRIPT"
elif [[ -x "$r_user_prefix/bin/Rscript" ]]; then
    select_r_runtime "$r_user_prefix/bin/Rscript"
elif [[ -x "/opt/R/$R_VERSION/bin/Rscript" ]]; then
    select_r_runtime "/opt/R/$R_VERSION/bin/Rscript"
else
    select_r_runtime Rscript
fi

run_rscript() {
    if [[ "$rscript_bin" == "$r_user_prefix/bin/Rscript" ]]; then
        "$micromamba_bin" --no-rc --root-prefix "$micromamba_root" \
            run --prefix "$r_user_prefix" "$rscript_bin" "$@"
    else
        "$rscript_bin" "$@"
    fi
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        printf 'Required executable unavailable: %s\n' "$1" >&2
        return 1
    fi
}
