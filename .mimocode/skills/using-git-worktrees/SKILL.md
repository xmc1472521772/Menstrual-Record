---
name: using-git-worktrees
description: Use before starting implementation work to create an isolated workspace on a new branch
---

# Using Git Worktrees

## Overview

Create isolated workspace on new branch, run project setup, verify clean test baseline.

**Announce at start:** "I'm using the using-git-worktrees skill to create an isolated workspace."

## The Process

### Step 1: Create Worktree

```bash
# Create a new branch and worktree
git worktree add ../project-feature-name -b feature-name
```

### Step 2: Verify Clean State

```bash
cd ../project-feature-name
git status
# Should show clean working tree
```

### Step 3: Run Project Setup

```bash
# Install dependencies
npm install  # or appropriate package manager

# Run initial tests to verify baseline
npm test
```

### Step 4: Verify Test Baseline

All tests should pass. If they don't, fix the baseline before proceeding.

## When to Use

- Before starting any multi-task implementation
- Before executing a plan with multiple tasks
- When you need isolated workspace for parallel development

## When NOT to Use

- Single-file changes that don't need isolation
- Quick bug fixes that are clearly scoped
- Documentation-only changes

## Remember

- Always verify clean test baseline before starting work
- Work in the worktree, not the main repository
- Clean up worktrees when done
- Never force push to shared branches