#!/usr/bin/env bash
# Unified validate entrypoint — run every validator that guards the ycc
# source-of-truth directory and its generated Cursor/Codex/opencode bundles.
#
# Usage:
#   ./scripts/validate.sh                       # all targets
#   ./scripts/validate.sh --only inventory      # single target
#   ./scripts/validate.sh --only cursor,codex   # comma-separated subset
#
# Targets: inventory, cursor, codex, opencode, json
#   - inventory  validates ycc skill↔command pairing and the shared inventory
#   - json       validates .claude-plugin/marketplace.json plus ycc/.claude-plugin/plugin.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Make `python3` + UTF-8 output work cross-platform (no-op on Linux/CI).
# shellcheck source=lib/python-resolve.sh
source "${SCRIPT_DIR}/lib/python-resolve.sh"

VALID_TARGETS=(inventory cursor codex opencode json)
TARGETS=("${VALID_TARGETS[@]}")

usage() {
    cat <<EOF
Usage: $(basename "$0") [--only <targets>]

Run every validator for the ycc source-of-truth directory and its generated
Cursor / Codex / opencode bundles.

Options:
  --only <targets>   Comma-separated subset (valid: ${VALID_TARGETS[*]})
  -h, --help         Show this help

Examples:
  $(basename "$0")
  $(basename "$0") --only inventory
  $(basename "$0") --only cursor,codex
  $(basename "$0") --only json
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --only)
            [[ $# -lt 2 ]] && { echo "validate.sh: --only requires an argument" >&2; exit 1; }
            IFS=',' read -r -a TARGETS <<<"$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "validate.sh: unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

for target in "${TARGETS[@]}"; do
    valid=0
    for v in "${VALID_TARGETS[@]}"; do
        [[ "$target" == "$v" ]] && valid=1 && break
    done
    if [[ "$valid" -eq 0 ]]; then
        echo "validate.sh: unknown target '$target' (valid: ${VALID_TARGETS[*]})" >&2
        exit 1
    fi
done

fail() {
    echo "validate.sh: FAILED at '$1'" >&2
    exit 1
}

run_target() {
    case "$1" in
        inventory)
            echo "== validate: inventory =="
            "${REPO_ROOT}/scripts/validate-inventory.sh" || fail "validate-inventory.sh"
            echo "== validate: ycc skill↔command pairing =="
            "${REPO_ROOT}/scripts/validate-ycc-commands.sh" || fail "validate-ycc-commands.sh"
            echo "== validate: formatter bundle smoke =="
            "${REPO_ROOT}/scripts/validate-formatters-bundle.sh" || fail "validate-formatters-bundle.sh"
            ;;
        cursor)
            echo "== validate: cursor agents =="
            "${REPO_ROOT}/scripts/validate-cursor-agents.sh" || fail "validate-cursor-agents.sh"
            echo "== validate: cursor skills =="
            "${REPO_ROOT}/scripts/validate-cursor-skills.sh" || fail "validate-cursor-skills.sh"
            echo "== validate: cursor rules =="
            "${REPO_ROOT}/scripts/validate-cursor-rules.sh" || fail "validate-cursor-rules.sh"
            ;;
        codex)
            echo "== validate: codex skills =="
            "${REPO_ROOT}/scripts/validate-codex-skills.sh" || fail "validate-codex-skills.sh"
            echo "== validate: codex agents =="
            "${REPO_ROOT}/scripts/validate-codex-agents.sh" || fail "validate-codex-agents.sh"
            echo "== validate: codex plugin =="
            "${REPO_ROOT}/scripts/validate-codex-plugin.sh" || fail "validate-codex-plugin.sh"
            ;;
        opencode)
            echo "== validate: opencode skills =="
            "${REPO_ROOT}/scripts/validate-opencode-skills.sh" || fail "validate-opencode-skills.sh"
            echo "== validate: opencode agents =="
            "${REPO_ROOT}/scripts/validate-opencode-agents.sh" || fail "validate-opencode-agents.sh"
            echo "== validate: opencode commands =="
            "${REPO_ROOT}/scripts/validate-opencode-commands.sh" || fail "validate-opencode-commands.sh"
            echo "== validate: opencode plugin =="
            "${REPO_ROOT}/scripts/validate-opencode-plugin.sh" || fail "validate-opencode-plugin.sh"
            echo "== validate: opencode install coverage =="
            "${REPO_ROOT}/scripts/validate-opencode-install-coverage.sh" || fail "validate-opencode-install-coverage.sh"
            ;;
        json)
            echo "== validate: marketplace and plugin manifests =="
            python3 -m json.tool "${REPO_ROOT}/.claude-plugin/marketplace.json" > /dev/null \
                || fail ".claude-plugin/marketplace.json"
            python3 -m json.tool "${REPO_ROOT}/ycc/.claude-plugin/plugin.json" > /dev/null \
                || fail "ycc/.claude-plugin/plugin.json"
            echo "OK: manifest JSON is valid."
            echo "== validate: hooks symlink =="
            "${REPO_ROOT}/scripts/validate-hooks.sh" || fail "validate-hooks.sh"
            ;;
    esac
}

for target in "${TARGETS[@]}"; do
    run_target "${target}"
done

echo "validate.sh: done (${TARGETS[*]})"
