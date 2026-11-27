#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/runtime.sh"

usage() {
    printf 'Usage: bash scripts/check.sh [all|python|r|bioc|fiji|tcga] [output-parent]\n' >&2
}

profile="${1:-all}"
if (( $# > 2 )); then
    usage
    exit 2
fi
case "$profile" in
    all|python|r|bioc|fiji|tcga) ;;
    *) usage; exit 2 ;;
esac

output_parent="${2:-$repo_root/outputs/smoke}"
mkdir -p "$output_parent"
output_parent="$(cd -- "$output_parent" && pwd)"
output_dir="$(mktemp -d "$output_parent/$profile.XXXXXX")"
printf 'Checking %s. Output: %s\n' "$profile" "$output_dir"
if git -C "$repo_root" rev-parse --verify HEAD > "$output_dir/git-sha.txt" 2>/dev/null; then
    cat "$output_dir/git-sha.txt"
fi

if [[ "$profile" == all ]]; then
    failed=0
    for layer in python r bioc fiji; do
        if ! bash "$repo_root/scripts/check.sh" "$layer" "$output_dir"; then
            printf '%s failed\n' "$layer" >&2
            failed=1
        fi
    done
    exit "$failed"
fi

case "$profile" in
    python)
        require_command "$python_bin"
        "$python_bin" "$repo_root/scripts/checks/python_smoke.py" "$output_dir"
        ;;
    r|bioc|tcga)
        require_command "$rscript_bin"
        run_rscript --vanilla "$repo_root/scripts/checks/r_smoke.R" \
            "$profile" "$repo_root/examples/fixtures/measurements.csv" "$output_dir"
        ;;
    fiji)
        require_command "$fiji_bin"
        require_command python3
        require_command timeout
        env -u DISPLAY -u WAYLAND_DISPLAY \
            timeout --kill-after=10s 180s "$fiji_bin" -Dimagej.updater.disableAutocheck=true -- \
            --headless -macro "$repo_root/scripts/checks/fiji_smoke.ijm" "$output_dir" \
            > "$output_dir/fiji.log" 2>&1 || {
                status=$?
                cat "$output_dir/fiji.log" >&2
                exit "$status"
            }
        python3 "$repo_root/scripts/checks/fiji_output.py" "$output_dir"
        ;;
esac
printf '%s OK\n' "$profile"
