---
name: finishing-a-development-branch
description: Use when all tasks in a plan are complete and you need to verify, merge, or create a PR
---

# Finishing a Development Branch

## Overview

Verify tests, present options (merge/PR/keep/discard), clean up worktree.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify All Tests Pass

```bash
# Run full test suite
npm test  # or appropriate command

# Verify no regressions
git status
```

### Step 2: Present Options

Ask your human partner which option they prefer:

1. **Merge to main** - Merge the feature branch into main
2. **Create PR** - Push branch and create pull request
3. **Keep branch** - Leave branch as-is for later review
4. **Discard branch** - Delete the branch and worktree

### Step 3: Execute Chosen Option

**If merging:**
```bash
git checkout main
git merge feature-branch
git worktree remove ../project-feature-name
```

**If creating PR:**
```bash
git push -u origin feature-branch
# Create PR via GitHub CLI or web interface
```

**If keeping:**
```bash
# Just report the branch and worktree location
```

**If discarding:**
```bash
git checkout main
git branch -D feature-branch
git worktree remove ../project-feature-name
```

### Step 4: Clean Up

Remove worktree if applicable:
```bash
git worktree remove ../project-feature-name
```

## When to Use

- After all tasks in a plan are complete
- When you've finished a feature or bugfix
- When you need to hand off work for review

## Remember

- Always verify tests pass before presenting options
- Never merge without explicit user consent
- Clean up worktrees when done
- Document what was done in commit messages