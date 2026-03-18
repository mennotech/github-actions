# Release Guide

This repository uses semantic version tags for published GitHub Actions.

## What You Need

For a solid release process, keep both of these:

- A GitHub release tag such as `v1.0.0`
- A `CHANGELOG.md` entry summarizing what changed

The tag is what workflow consumers use in `uses:` statements. The changelog is what humans read when deciding whether to adopt or upgrade.

## First Stable Release

For the first public stable release, publish:

- `v1.0.0` as the immutable release tag
- `v1` as the moving major tag pointing at the same commit

Consumers can then use either:

- `uses: mennotech/github-actions/codesign-files-windows@v1.0.0`
- `uses: mennotech/github-actions/codesign-files-windows@v1`

Use `@v1.0.0` for pinning to an exact release. Use `@v1` when consumers should receive non-breaking updates automatically.

## Release Checklist

1. Merge the release-ready branch into `main`.
2. Confirm CI is green on `main`.
3. Update `CHANGELOG.md` with the release date and summary.
4. Create the immutable release tag:

```powershell
git checkout main
git pull origin main
git tag v1.0.0
git push origin v1.0.0
```

5. Create or move the major tag:

```powershell
git tag -f v1
git push -f origin v1
```

6. Create a GitHub release from tag `v1.0.0`.
7. Paste the `CHANGELOG.md` entry into the GitHub release notes.
8. Test one consuming workflow against `@v1.0.0` or `@v1`.

## GitHub Release Notes Template

```markdown
## v1.0.0

Initial stable release of Mennotech reusable GitHub Actions for Windows.

### Included
- Import code-signing certificates into the Windows certificate store
- Sign PowerShell files with cleanup support for imported certificates
- Deploy files with robocopy-based exclusions
- CI validation for YAML, PowerShell syntax, linting, smoke tests, and integration tests

### Notes
- Intended for Windows self-hosted runners
- Use `cleanup_certificate: true` when signing files on persistent runners
```

## When to Bump Versions

- Patch: bug fix only, no breaking behavior change
- Minor: new feature or backward-compatible enhancement
- Major: breaking change in action name, inputs, outputs, or behavior