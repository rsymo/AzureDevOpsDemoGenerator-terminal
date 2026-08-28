#!/usr/bin/env bash
#
# Verify that each template's source repositories are still reachable anonymously.
#
# Template source repos are hosted on third-party Azure DevOps organizations and
# GitHub accounts, so they disappear over time. This regenerates the data behind
# templates-archive.txt.
#
# Usage:
#   ./verify-template-sources.sh              # report only
#   ./verify-template-sources.sh --write      # rewrite templates-archive.txt

set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEMPLATES_DIR="$SCRIPT_DIR/AzureDevOpsDemoGenerator-original/src/VstsDemoBuilder/Templates"
ARCHIVE_FILE="$SCRIPT_DIR/templates-archive.txt"

WRITE=false
[ "${1:-}" = "--write" ] && WRITE=true

# Never prompt for credentials: a private repo must fail, not hang.
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/echo
export GCM_INTERACTIVE=never

command -v jq >/dev/null || { echo "jq is required"; exit 1; }
[ -d "$TEMPLATES_DIR" ] || { echo "Templates directory not found: $TEMPLATES_DIR"; exit 1; }

template_urls() {
    find "$1" -ipath '*ImportSourceCode*' -name '*.json' \
        -exec jq -r '..|.url? // empty' {} \; 2>/dev/null \
        | grep -Ei '^https?://' | sort -u
}

reachable=()
unreachable=()

for template_dir in "$TEMPLATES_DIR"/*; do
    [ -d "$template_dir" ] || continue
    [ -f "$template_dir/ProjectTemplate.json" ] || continue
    name=$(basename "$template_dir")

    ok=0; total=0
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        total=$((total + 1))
        if git ls-remote --heads "$url" >/dev/null 2>&1; then
            ok=$((ok + 1))
        fi
    done < <(template_urls "$template_dir")

    if [ "$total" -eq 0 ]; then
        echo "NOSOURCE  $name"
        unreachable+=("$name")
    elif [ "$ok" -eq 0 ]; then
        echo "DEAD      $name ($total repo(s) unreachable)"
        unreachable+=("$name")
    elif [ "$ok" -lt "$total" ]; then
        echo "PARTIAL   $name ($ok/$total repo(s) reachable)"
        reachable+=("$name")
    else
        echo "OK        $name"
        reachable+=("$name")
    fi
done

echo ""
echo "Reachable:   ${#reachable[@]}"
echo "Unreachable: ${#unreachable[@]}"

if [ "$WRITE" = true ]; then
    {
        echo "# Archived templates - hidden from \`--list\`"
        echo "#"
        echo "# Source repositories are not reachable anonymously: deleted, made private,"
        echo "# or behind an authentication wall. Importing one of these creates a project"
        echo "# with work items but no source code, branches, pull requests, or pipelines."
        echo "#"
        echo "# Regenerate with: ./verify-template-sources.sh --write"
        echo "# Last verified: $(date +%Y-%m)"
        echo ""
        printf '%s\n' "${unreachable[@]}"
    } > "$ARCHIVE_FILE"
    echo "Wrote $ARCHIVE_FILE"
fi
