#!/usr/bin/env bash
# python-resolve.sh — make the bundled Python tooling portable across platforms.
#
# Source (do not exec) this from an entrypoint:
#   # shellcheck source=lib/python-resolve.sh
#   source "${SCRIPT_DIR}/lib/python-resolve.sh"
#
# It does two things, both no-ops where `python3` already works (Linux/macOS/CI):
#   1. Forces UTF-8 I/O so generators/validators that print non-ASCII (e.g. the
#      skill-command arrow, warning banners) don't crash on a Windows cp1252
#      console.
#   2. If `python3` is missing or is the Windows Store app-execution-alias stub,
#      locates a real interpreter (`python`, then `py -3`) and shims a `python3`
#      onto PATH so the inner `exec python3 ...` wrappers resolve correctly.
#
# Exits non-zero (fails the sourcing script under `set -e`) if no Python 3 found.

# 1. UTF-8 everywhere — harmless on Linux, essential on a Windows cp1252 console.
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

# Does "$@ -c ..." run a real Python 3? The Windows Store stub fails this.
_pr_python_works() { "$@" -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; }

if ! _pr_python_works python3; then
    _pr_shim_dir="${TMPDIR:-/tmp}/ycc-python-shim"
    mkdir -p "${_pr_shim_dir}"
    # Prefer a direct interpreter (fast) over the `py` launcher (slow startup,
    # and these scripts invoke python3 hundreds of times).
    if _pr_python_works python; then
        printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$(command -v python)" > "${_pr_shim_dir}/python3"
    elif command -v py >/dev/null 2>&1 && _pr_python_works py -3; then
        printf '#!/usr/bin/env bash\nexec py -3 "$@"\n' > "${_pr_shim_dir}/python3"
    else
        echo "python-resolve: no working Python 3 found (tried python3, python, py -3)." >&2
        echo "  Install Python 3, or disable the Windows Store 'python3' app-execution alias" >&2
        echo "  (Settings > Apps > Advanced app settings > App execution aliases)." >&2
        return 1 2>/dev/null || exit 1
    fi
    chmod +x "${_pr_shim_dir}/python3"
    PATH="${_pr_shim_dir}:${PATH}"
    export PATH
    unset _pr_shim_dir
fi

unset -f _pr_python_works
