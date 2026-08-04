#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./Scripts/create-and-push-tag.sh [--dry-run]

Show the latest tag, prompt for a new semantic version tag, and push an
annotated tag to origin. --dry-run validates the input without creating or
pushing a tag.
EOF
}

DRY_RUN=false
case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 64
        ;;
esac

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "Run this script from inside the Countpane Git repository." >&2
    exit 1
fi

ROOT_DIR="$(git rev-parse --show-toplevel)"
cd "$ROOT_DIR"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is not clean; commit or stash changes before tagging." >&2
    git status --short >&2
    exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    echo "Git remote 'origin' is not configured." >&2
    exit 1
fi

CURRENT_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
CURRENT_BRANCH="$(git symbolic-ref --quiet --short HEAD || echo detached-HEAD)"
if [[ -n "$CURRENT_TAG" ]]; then
    printf 'Current tag: %s\n' "$CURRENT_TAG"
else
    echo 'Current tag: none reachable from HEAD'
fi
printf 'Current ref: %s\n' "$CURRENT_BRANCH"

read -r -p 'New tag (for example v1.0.9): ' NEW_TAG
if [[ ! "$NEW_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    echo "Invalid tag '$NEW_TAG'. Use vMAJOR.MINOR.PATCH, optionally with a prerelease/build suffix." >&2
    exit 64
fi

if [[ "$NEW_TAG" == "$CURRENT_TAG" ]]; then
    echo "New tag must differ from the current tag '$CURRENT_TAG'." >&2
    exit 1
fi

if git rev-parse --verify --quiet "refs/tags/$NEW_TAG" >/dev/null; then
    echo "Tag '$NEW_TAG' already exists locally." >&2
    exit 1
fi

if git ls-remote --exit-code --refs origin "refs/tags/$NEW_TAG" >/dev/null 2>&1; then
    echo "Tag '$NEW_TAG' already exists on origin." >&2
    exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run: would create annotated tag '$NEW_TAG' at $(git rev-parse --short HEAD) and push it to origin."
    exit 0
fi

git tag --annotate "$NEW_TAG" --message "Release $NEW_TAG"
if ! git push origin "$NEW_TAG"; then
    echo "Push failed; removing the newly created local tag '$NEW_TAG'." >&2
    git tag --delete "$NEW_TAG" >/dev/null
    exit 1
fi

echo "Created and pushed '$NEW_TAG'. GitHub Actions release workflow should start shortly."
