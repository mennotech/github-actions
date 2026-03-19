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
4. Create the immutable annotated release tag:

```powershell
git checkout main
git pull --ff-only origin main
git tag -a v1.0.0 -m "github-actions v1.0.0"
git push origin v1.0.0
```

5. Create or move the major annotated tag:

```powershell
git tag -f -a v1 -m "github-actions v1"
git push -f origin v1
```

6. Create a GitHub release from tag `v1.0.0`.
7. Paste the `CHANGELOG.md` entry into the GitHub release notes.
8. Test one consuming workflow against `@v1.0.0` or `@v1`.

For a patch release such as `v1.0.1` or a minor release such as `v1.1.0`, repeat the same process with the new version tag and update the moving `v1` tag to the same release commit.

When a release changes default action behavior without changing inputs or action names, treat it as a minor release and call the behavior change out prominently in the GitHub release notes and changelog summary.

When the repository is intended to be consumed primarily through `mennotech/github-workflows`, say that explicitly in the release notes so application teams do not assume direct action usage is the recommended default.

Example for the current minor release:

```powershell
git checkout main
git pull --ff-only origin main
git tag -a v1.1.0 -m "github-actions v1.1.0"
git push origin v1.1.0

git tag -f -a v1 -m "github-actions v1"
git push -f origin v1
```

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

For releases like `v1.1.0` that change default exclusions, add an explicit warning near the top of the release notes, for example:

```markdown
## Important Upgrade Note

`deploy-files-windows` and `codesign-files-windows` no longer ship broad default exclusion lists.
Only `.git` is excluded automatically.

If consuming repositories need to exclude `.github`, `logs`, `_work`, or generated output directories, those exclusions must now be passed explicitly by the caller.

Most application repositories should prefer `mennotech/github-workflows`, where Mennotech can centralize sane defaults and safer orchestration.
Direct `mennotech/github-actions` usage remains available for advanced custom workflows.
```

If a release changes certificate-handling behavior or guidance, call that out explicitly as well. For example:

```markdown
## Certificate Handling Note

Production verification remains strict by default.

For CI tests that use self-signed certificates, `codesign-files-windows` can accept the specific untrusted-root `UnknownError` case only when the workflow opts in explicitly and supplies the expected signer thumbprint.

Do not use this as a production bypass or as a general acceptance of all `UnknownError` results.
```

## When to Bump Versions

- Patch: bug fix only, no breaking behavior change
- Minor: new feature, backward-compatible enhancement, or a non-breaking default behavior change that consumers need to notice
- Major: breaking change in action name, inputs, outputs, or behavior