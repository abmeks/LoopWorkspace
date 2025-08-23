#!/bin/bash

# Script to check for upstream changes without attempting to merge
# Used for the alive branch checks

set -e

# Configuration
UPSTREAM_REPO="${UPSTREAM_REPO:-LoopKit/LoopWorkspace}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
GH_PAT="${GH_PAT}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Checking for upstream changes${NC}"
echo "Upstream repo: $UPSTREAM_REPO"
echo "Upstream branch: $UPSTREAM_BRANCH"
echo "Target branch: $TARGET_BRANCH"

# Validate required environment variables
if [ -z "$GH_PAT" ]; then
    echo -e "${RED}Error: GH_PAT environment variable is required${NC}"
    exit 1
fi

# Set up git configuration
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# Add upstream remote if it doesn't exist
if ! git remote get-url upstream >/dev/null 2>&1; then
    echo -e "${YELLOW}Adding upstream remote${NC}"
    git remote add upstream "https://github.com/$UPSTREAM_REPO.git"
fi

# Fetch latest changes from upstream
echo -e "${YELLOW}Fetching upstream changes${NC}"
git fetch upstream "$UPSTREAM_BRANCH"

# Get the latest commit SHA from upstream
UPSTREAM_SHA=$(git rev-parse "upstream/$UPSTREAM_BRANCH")
CURRENT_SHA=$(git rev-parse HEAD)

echo "Current SHA: $CURRENT_SHA"
echo "Upstream SHA: $UPSTREAM_SHA"

# Check if we're already up to date
if [ "$CURRENT_SHA" = "$UPSTREAM_SHA" ]; then
    echo -e "${GREEN}Already up to date with upstream${NC}"
    [ -n "$GITHUB_OUTPUT" ] && echo "has_new_commits=false" >> "$GITHUB_OUTPUT"
    exit 0
fi

# Check if there are new commits
NEW_COMMITS=$(git rev-list --count "$CURRENT_SHA".."$UPSTREAM_SHA")
echo "Found $NEW_COMMITS new commits available"

if [ "$NEW_COMMITS" -eq 0 ]; then
    echo -e "${GREEN}No new commits available${NC}"
    [ -n "$GITHUB_OUTPUT" ] && echo "has_new_commits=false" >> "$GITHUB_OUTPUT"
    exit 0
fi

echo -e "${GREEN}Found $NEW_COMMITS new commits available for sync${NC}"
[ -n "$GITHUB_OUTPUT" ] && echo "has_new_commits=true" >> "$GITHUB_OUTPUT"

# For alive branch, we don't actually sync, just update a timestamp file
ALIVE_TIMESTAMP_FILE=".github/alive_timestamp"
echo "Alive check: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" > "$ALIVE_TIMESTAMP_FILE"
git add "$ALIVE_TIMESTAMP_FILE"

# Only commit if there are changes
if ! git diff --cached --quiet; then
    git commit -m "Keep alive: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    git push origin "$TARGET_BRANCH"
    echo -e "${GREEN}Updated alive timestamp${NC}"
fi

echo -e "${GREEN}Check completed successfully${NC}"