# AI Whisperers Repository Conventions

> **Read this before creating a new repo or auditing existing ones.**

## Repo Creation Rules

When creating a new repository, **all four** must be true:

1. **One-line description** is set immediately (GitHub repo description, not just README)
2. **GitHub topic** `ai-whisperers` is added (plus `paraguai`, `client`, `lead`, `research`, `personal`, or `tooling` as appropriate)
3. **Owner** is set (add a CODEOWNERS file or assign in GitHub settings)
4. **Canonical home** is decided — every project lives in exactly one org

## Description Format

```
<Project name> — <one-line what it does> (<location if relevant>)
```

Examples:
- ✓ "Dra. Gabriella González Pane dental practice strategy + site (Asunción, Paraguay)"
- ✓ "ParaguAI monorepo: site builder, client apps, Next.js 16 platform"
- ✗ "" (no description)
- ✗ "Stuff" (too vague)

## When to Use Which Org

| Org | Purpose |
|-----|---------|
| **Ai-Whisperers** | Company work: client sites, ParaguAI platform, infrastructure, Hermes Agent |
| **IvanWeissVanDerPol** | Personal projects, FPUNA coursework, Ivan-only research |
| **LosingLoonies-Youtube** | Stock trading / YouTube content (Ivan personal, separate brand) |

## Don't Duplicate

Before creating a new repo, check:
```bash
gh repo list Ai-Whisperers --search "<name>"
gh repo list IvanWeissVanDerPol --search "<name>"
```

If a similar repo exists, **migrate it** instead of creating a new one.

## Repo Size Budget

- Single repo: aim for 1-100 MB
- If repo exceeds 100 MB: split, use Git LFS, or move to artifact storage
- If you have 5+ repos in the same category: consolidate to a monorepo

## Audit

Run `hermes-repo-audit` monthly to catch drift:
- Repos without description
- Archived repos that could be deleted
- Cross-org duplicates
- Stale repos (no commits in 90+ days)

## Cleanup Process

For deleting repos:
1. Mark as archived first (visible to others)
2. Wait 30 days (in case someone needs it)
3. Then delete (requires `delete_repo` token scope — needs browser auth)

For consolidating:
1. Pick canonical home
2. Archive the duplicates
3. Add forwarding note in the archived README
4. Update any references in scripts/skills

## What Goes in README

Top of every README:
```markdown
# Project Name

One-line description.

**Status**: 🟢 Active | 🟡 Maintenance | 🔴 Archived
**Owner**: @username
**Last update**: YYYY-MM-DD
```

## Reference

- Repo audit tool: `hermes-repo-audit` (`~/.local/bin/`)
- Description tool: `hermes-repo-describe` (`~/.local/bin/`)
- Cleanup plan: regenerated each audit run
- This conventions doc: `paragu-ai-clients/REPO-CONVENTIONS.md`

Last reviewed: 2026-08-10
