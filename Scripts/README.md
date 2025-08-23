# Upstream Sync Fix

This directory contains scripts to handle upstream synchronization with conflict resolution.

## Problem Solved

The GitHub Actions workflow was failing with merge conflicts when syncing from upstream LoopKit/LoopWorkspace:

```
Auto-merging fastlane/Fastfile
CONFLICT (content): Merge conflict in fastlane/Fastfile
Automatic merge failed; fix conflicts and then commit the result.
ERROR: exit 1
```

## Solution

Replaced `aormsby/Fork-Sync-With-Upstream-action@v3.4.1` with custom scripts that automatically resolve merge conflicts.

### Scripts

#### `sync_with_upstream.sh`
- **Purpose**: Full sync with automatic conflict resolution
- **Features**: 
  - Detects and resolves merge conflicts automatically
  - Prefers upstream versions for known conflict files
  - Handles submodule conflicts
  - Provides detailed logging with colors
- **Usage**: Called during the main build sync phase

#### `check_upstream_changes.sh`
- **Purpose**: Check for upstream changes without complex merging
- **Features**:
  - Detects new commits from upstream
  - Updates alive timestamp for repository maintenance
  - Lightweight operation for pre-sync checks
- **Usage**: Called during the initial check phase

### Conflict Resolution Strategy

The scripts automatically resolve conflicts by preferring upstream versions for:

- `fastlane/Fastfile` - Takes upstream version to stay current with Loop build process
- `.github/workflows/*` - Takes upstream version for latest workflow improvements  
- `Gemfile`, `Gemfile.lock` - Takes upstream version for dependency updates
- `VersionOverride.xcconfig` - Takes upstream version for configuration
- Workspace files - Takes upstream version for project structure
- Submodules - Takes upstream version for latest component updates

This ensures the fork stays synchronized with the latest LoopKit improvements while maintaining automation.

### Integration

The scripts are integrated into `.github/workflows/build_loop.yml` and maintain the same interface as the original action:

- Environment variables: `UPSTREAM_REPO`, `UPSTREAM_BRANCH`, `TARGET_BRANCH`, `GH_PAT`
- Outputs: `has_new_commits` (true/false)
- Error handling: Proper exit codes and logging

## Testing

The scripts have been tested with:
- ✅ Actual merge conflict scenarios
- ✅ GitHub Actions environment simulation  
- ✅ Multi-file conflict resolution
- ✅ Submodule conflict handling
- ✅ Output variable generation

## Result

The automated sync process now works reliably even when there are merge conflicts, ensuring the fork stays current with upstream LoopKit/LoopWorkspace updates.