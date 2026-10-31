#!/bin/sh
# Applies the mouse fix to the current Savage Wind Recomp checkout. Usage: sh apply.sh [path-to-repo]
set -e
repo=${1:-.}
here=$(cd "$(dirname "$0")" && pwd)

cd "$repo"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "'$repo' is not a git checkout of SavageWindRecomp." >&2
    exit 1
}
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" = test ]; then order="test main"; else order="main test"; fi

for name in $order; do
    patch="$here/mouse-fix.$name.patch"
    if git apply --check "$patch" 2>/dev/null; then
        git apply "$patch"
        echo "Applied mouse-fix.$name.patch to branch '$branch'."
        echo "Rebuild the runtime next (see the upstream docs/BUILD*.md)."
        exit 0
    fi
done

echo "Neither patch applies cleanly here (branch '$branch')." >&2
echo "Try 'git apply -3 mouse-fix.main.patch' for a three-way merge, or open an issue." >&2
exit 1
