#!/bin/bash

# Sync with upstream script that handles merge conflicts gracefully
# This script is designed to replace the Fork-Sync-With-Upstream-action when merge conflicts occur

set -e

# Configuration
UPSTREAM_REPO="${UPSTREAM_REPO:-LoopKit/LoopWorkspace}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
GH_PAT="${GH_PAT}"

# Validate required environment variables
if [ -z "$GH_PAT" ]; then
    echo -e "${RED}Error: GH_PAT environment variable is required${NC}"
    exit 1
fi

# Set up git configuration
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting upstream sync process${NC}"
echo "Upstream repo: $UPSTREAM_REPO"
echo "Upstream branch: $UPSTREAM_BRANCH"
echo "Target branch: $TARGET_BRANCH"

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
echo "Found $NEW_COMMITS new commits to sync"

if [ "$NEW_COMMITS" -eq 0 ]; then
    echo -e "${GREEN}No new commits to sync${NC}"
    [ -n "$GITHUB_OUTPUT" ] && echo "has_new_commits=false" >> "$GITHUB_OUTPUT"
    exit 0
fi

[ -n "$GITHUB_OUTPUT" ] && echo "has_new_commits=true" >> "$GITHUB_OUTPUT"

# Attempt merge with upstream
echo -e "${YELLOW}Attempting to merge upstream changes${NC}"
if git merge "upstream/$UPSTREAM_BRANCH" --no-edit --allow-unrelated-histories; then
    echo -e "${GREEN}Successfully merged upstream changes without conflicts${NC}"
    echo -e "${GREEN}Pushing changes to origin${NC}"
    if [ "$GH_PAT" = "dummy" ]; then
        echo -e "${YELLOW}Skipping push (dummy PAT provided)${NC}"
    else
        git push origin "$TARGET_BRANCH"
    fi
    exit 0
fi

# If merge fails due to conflicts, handle them
echo -e "${YELLOW}Merge conflicts detected, attempting to resolve...${NC}"

# Get list of conflicted files
CONFLICTED_FILES=$(git diff --name-only --diff-filter=U)
echo "Conflicted files:"
echo "$CONFLICTED_FILES"

# Handle specific files with known conflict patterns
for file in $CONFLICTED_FILES; do
    case "$file" in
        "fastlane/Fastfile")
            echo -e "${YELLOW}Resolving conflicts in fastlane/Fastfile${NC}"
            # For Fastfile, prefer upstream version as it contains important updates
            git checkout --theirs "$file"
            git add "$file"
            echo -e "${GREEN}Resolved $file by taking upstream version${NC}"
            ;;
        ".github/workflows/"*)
            echo -e "${YELLOW}Resolving conflicts in workflow file: $file${NC}"
            # For workflow files, prefer upstream version to get latest improvements
            git checkout --theirs "$file"
            git add "$file"
            echo -e "${GREEN}Resolved $file by taking upstream version${NC}"
            ;;
        "Gemfile" | "Gemfile.lock")
            echo -e "${YELLOW}Resolving conflicts in $file${NC}"
            # For dependency files, prefer upstream version
            git checkout --theirs "$file"
            git add "$file"
            echo -e "${GREEN}Resolved $file by taking upstream version${NC}"
            ;;
        "VersionOverride.xcconfig")
            echo -e "${YELLOW}Resolving conflicts in $file${NC}"
            # For config files, prefer upstream version
            git checkout --theirs "$file"
            git add "$file"
            echo -e "${GREEN}Resolved $file by taking upstream version${NC}"
            ;;
        "LoopWorkspace.xcworkspace/contents.xcworkspacedata")
            echo -e "${YELLOW}Resolving conflicts in workspace file${NC}"
            # For workspace files, prefer upstream version
            git checkout --theirs "$file"
            git add "$file"
            echo -e "${GREEN}Resolved $file by taking upstream version${NC}"
            ;;
        *)
            echo -e "${RED}Unhandled conflict in $file${NC}"
            # Check if this is a submodule
            if git ls-files -s "$file" | grep -q "^160000"; then
                echo -e "${YELLOW}Resolving submodule conflict: $file${NC}"
                # For submodules, get the upstream commit hash and set it
                UPSTREAM_COMMIT=$(git ls-tree "upstream/$UPSTREAM_BRANCH" "$file" | awk '{print $3}')
                if [ -n "$UPSTREAM_COMMIT" ]; then
                    git update-index --add --cacheinfo 160000 "$UPSTREAM_COMMIT" "$file"
                    echo -e "${GREEN}Resolved submodule $file by taking upstream commit $UPSTREAM_COMMIT${NC}"
                else
                    echo -e "${RED}Could not resolve submodule $file - no upstream commit found${NC}"
                    exit 1
                fi
            else
                echo -e "${YELLOW}Taking upstream version as default${NC}"
                git checkout --theirs "$file"
                git add "$file"
                echo -e "${GREEN}Resolved $file by taking upstream version${NC}"
            fi
            ;;
    esac
done

# Handle submodule conflicts
echo -e "${YELLOW}Checking for remaining submodule conflicts${NC}"
SUBMODULE_CONFLICTS=$(git diff --name-only --diff-filter=U | head -20 || true)

if [ -n "$SUBMODULE_CONFLICTS" ]; then
    echo "Remaining conflicts found, resolving..."
    for file in $SUBMODULE_CONFLICTS; do
        if git ls-files -s "$file" | grep -q "^160000"; then
            echo -e "${YELLOW}Resolving remaining submodule conflict: $file${NC}"
            # For submodules, get the upstream commit hash and set it
            UPSTREAM_COMMIT=$(git ls-tree "upstream/$UPSTREAM_BRANCH" "$file" | awk '{print $3}')
            if [ -n "$UPSTREAM_COMMIT" ]; then
                git update-index --add --cacheinfo 160000 "$UPSTREAM_COMMIT" "$file"
                echo -e "${GREEN}Resolved submodule $file by taking upstream commit $UPSTREAM_COMMIT${NC}"
            else
                echo -e "${RED}Could not resolve submodule $file - no upstream commit found${NC}"
                exit 1
            fi
        fi
    done
fi

# Check if all conflicts are resolved
REMAINING_CONFLICTS=$(git diff --name-only --diff-filter=U || true)
if [ -n "$REMAINING_CONFLICTS" ]; then
    echo -e "${RED}Still have unresolved conflicts:${NC}"
    echo "$REMAINING_CONFLICTS"
    exit 1
fi

# Commit the merge
echo -e "${YELLOW}Committing merge${NC}"
git commit --no-edit || git commit -m "Merge upstream changes from $UPSTREAM_REPO@$UPSTREAM_SHA"

echo -e "${GREEN}Successfully resolved all conflicts and completed merge${NC}"

# Push changes
echo -e "${YELLOW}Pushing changes to origin${NC}"
if [ "$GH_PAT" = "dummy" ]; then
    echo -e "${YELLOW}Skipping push (dummy PAT provided)${NC}"
else
    git push origin "$TARGET_BRANCH"
fi

echo -e "${GREEN}Sync completed successfully${NC}"