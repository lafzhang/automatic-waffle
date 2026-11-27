#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/runtime.sh"

usage() {
    printf 'Usage: bash scripts/setup.sh [all|python|r|bioc|fiji|tcga]\n' >&2
}

if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
    printf 'Setup requires a Linux x86_64 environment. See README.md for Windows checks.\n' >&2
    exit 2
fi

download() {
    curl --fail --location --silent --show-error --retry 3 \
        --connect-timeout 15 --max-time 600 "$1" --output "$2"
}

apt_install() {
    local elevate=()
    if (( EUID != 0 )); then
        require_command sudo
        elevate=(sudo -n)
    fi
    "${elevate[@]}" apt-get update
    "${elevate[@]}" env DEBIAN_FRONTEND=noninteractive \
        apt-get -o DPkg::Lock::Timeout=120 install -y --no-install-recommends "$@"
}

install_python() (
    local uv_dir="$WORKBENCH_HOME/uv-$UV_VERSION"
    local uv="$uv_dir/uv"
    if [[ ! -x "$uv" ]]; then
        local stage
        stage="$(mktemp -d "$WORKBENCH_HOME/uv-stage.XXXXXX")"
        trap 'rm -rf -- "$stage"' EXIT
        local bundle=uv-x86_64-unknown-linux-gnu
        download "https://github.com/astral-sh/uv/releases/download/$UV_VERSION/$bundle.tar.gz" "$stage/uv.tar.gz"
        tar -xzf "$stage/uv.tar.gz" -C "$stage"
        mkdir -p "$uv_dir"
        chmod 0755 "$stage/$bundle/uv"
        mv -T -- "$stage/$bundle/uv" "$uv"
    fi
    if [[ ! -x "$python_env/bin/python" ]]; then
        "$uv" venv --managed-python --python "$PYTHON_VERSION" "$python_env"
    fi
    "$uv" pip sync --python "$python_env/bin/python" --only-binary :all: \
        "$repo_root/env/python-requirements.txt"
    "$uv" pip check --python "$python_env/bin/python"
)

r_has_expected_version() {
    command -v "$rscript_bin" >/dev/null 2>&1 &&
        run_rscript --vanilla -e 'quit(status = as.integer(getRversion() != Sys.getenv("R_VERSION")))'
}

can_install_with_apt() {
    if ! command -v apt-get >/dev/null 2>&1; then
        return 1
    fi
    if (( EUID == 0 )); then
        return 0
    fi
    command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null
}

install_system_r() {
    local profile="$1"
    local -a build_packages=(
        build-essential gfortran pkg-config
        libcurl4-openssl-dev libssl-dev libxml2-dev zlib1g-dev
        libfontconfig1-dev libharfbuzz-dev libfribidi-dev libfreetype6-dev
        libpng-dev libtiff-dev libjpeg-dev
    )
    if [[ "$profile" == tcga ]]; then
        build_packages+=(libglpk-dev libicu-dev)
    fi

    if r_has_expected_version; then
        apt_install "${build_packages[@]}"
    else
        local distribution stage package
        source /etc/os-release
        case "${ID:-}:${VERSION_ID:-}" in
            ubuntu:22.04|ubuntu:24.04|ubuntu:26.04)
                distribution="ubuntu-${VERSION_ID/./}" ;;
            debian:13) distribution=debian-13 ;;
            *)
                printf 'R %s is required on %s. Set WORKBENCH_RSCRIPT to a compatible binary.\n' \
                    "$R_VERSION" "${PRETTY_NAME:-this Linux distribution}" >&2
                exit 2 ;;
        esac
        stage="$(mktemp -d "$WORKBENCH_HOME/r-stage.XXXXXX")"
        trap 'rm -rf -- "$stage"' EXIT
        package="r-${R_VERSION}_1_amd64.deb"
        download "https://cdn.posit.co/r/$distribution/pkgs/$package" "$stage/$package"
        chmod 0755 "$stage"
        apt_install "$stage/$package" "${build_packages[@]}"
        select_r_runtime "/opt/R/$R_VERSION/bin/Rscript"
    fi
}

install_user_r() (
    if [[ ! -x "$micromamba_bin" ]]; then
        local stage
        stage="$(mktemp -d "$WORKBENCH_HOME/micromamba-stage.XXXXXX")"
        trap 'rm -rf -- "$stage"' EXIT
        download "https://github.com/mamba-org/micromamba-releases/releases/download/$MICROMAMBA_VERSION/micromamba-linux-64" \
            "$stage/micromamba"
        printf '%s  micromamba\n' "$MICROMAMBA_SHA256" | (cd "$stage" && sha256sum --check --strict)
        mkdir -p "$(dirname -- "$micromamba_bin")"
        chmod 0755 "$stage/micromamba"
        mv -T -- "$stage/micromamba" "$micromamba_bin"
    fi

    local action=create
    if [[ -f "$r_user_prefix/conda-meta/history" ]]; then
        action=install
    fi
    printf 'Installing R %s and build tools in %s\n' "$R_VERSION" "$r_user_prefix"
    "$micromamba_bin" --no-rc --root-prefix "$micromamba_root" "$action" \
        --yes --prefix "$r_user_prefix" --override-channels \
        --channel https://conda.anaconda.org/conda-forge \
        "r-base=$R_VERSION" c-compiler cxx-compiler fortran-compiler make pkg-config \
        libcurl openssl libxml2-devel zlib icu glpk
)

install_r() (
    local profile="$1"
    if [[ -n "${WORKBENCH_RSCRIPT:-}" ]] && ! r_has_expected_version; then
        printf 'WORKBENCH_RSCRIPT must resolve to R %s.\n' "$R_VERSION" >&2
        exit 2
    fi
    if [[ "$rscript_bin" != "$r_user_prefix/bin/Rscript" ]] && can_install_with_apt; then
        install_system_r "$profile"
    elif ! r_has_expected_version; then
        install_user_r
        select_r_runtime "$r_user_prefix/bin/Rscript"
    fi

    mkdir -p "$R_LIBS_USER"
    run_rscript --vanilla "$repo_root/env/install-r.R" "$profile"
)

install_fiji() (
    if ! command -v unzip >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
        apt_install unzip python3
    fi
    if [[ -x "$fiji_dir/fiji-linux-x64" ]]; then
        return 0
    fi
    local stage source_url expected_digest fiji_root launcher
    stage="$(mktemp -d "$WORKBENCH_HOME/fiji-stage.XXXXXX")"
    trap 'rm -rf -- "$stage"' EXIT
    source_url="https://downloads.imagej.net/fiji/archive/stable/$FIJI_BUILD/fiji-stable-linux64-jdk.zip"
    download "$source_url.sha256" "$stage/fiji.sha256"
    download "$source_url" "$stage/fiji.zip"
    expected_digest="$(tr -d '[:space:]' < "$stage/fiji.sha256")"
    if [[ ! "$expected_digest" =~ ^[a-fA-F0-9]{64}$ ]]; then
        printf 'Invalid SHA-256 for Fiji build %s.\n' "$FIJI_BUILD" >&2
        exit 1
    fi
    printf '%s  fiji.zip\n' "$expected_digest" | (cd "$stage" && sha256sum --check --strict)
    unzip -q "$stage/fiji.zip" -d "$stage/extracted"
    launcher="$(find "$stage/extracted" -maxdepth 3 -type f -name fiji-linux-x64 -print -quit)"
    if [[ -z "$launcher" ]]; then
        printf 'Fiji Linux launcher missing from build %s.\n' "$FIJI_BUILD" >&2
        exit 1
    fi
    fiji_root="$(dirname "$launcher")"
    chmod +x "$launcher"
    find "$fiji_root" -type f -name jaunch-linux-x64 -exec chmod +x {} +
    mv -T -- "$fiji_root" "$fiji_dir"
)

if (( $# > 1 )); then
    usage
    exit 2
fi
profile="${1:-all}"
case "$profile" in
    all|python|r|bioc|fiji|tcga) ;;
    *) usage; exit 2 ;;
esac

require_command curl
require_command flock
mkdir -p "$WORKBENCH_HOME"
exec 9>"$WORKBENCH_HOME/setup.lock"
flock -w 600 9
case "$profile" in
    python) install_python ;;
    r|bioc|tcga) install_r "$profile" ;;
    fiji) install_fiji ;;
    all)
        install_python
        install_r bioc
        install_fiji ;;
esac
