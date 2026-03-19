# Changelog

All notable changes to this repository will be documented in this file.

The format is based on Keep a Changelog and the project follows Semantic Versioning.

## [Unreleased]

## Release Notes Highlight

- `v1.1.0` is a minor release because the default deployment and signing exclusion behavior changed.
- `exclude_dirs` and `exclude_files` are now caller-controlled additive exclusions rather than broad built-in defaults.
- Only `.git` remains enforced automatically, so consumers should review and explicitly provide exclusions such as `.github`, `logs`, `_work`, and any generated output directories they do not want deployed or signed.
- Most consuming repositories should prefer `mennotech/github-workflows`, where Mennotech can provide sane defaults and safer orchestration guidance. Direct `mennotech/github-actions` usage should be treated as an advanced integration path.

## [1.1.0] - 2026-03-19

### Changed
- `codesign-files-windows` and `deploy-files-windows` now treat `exclude_dirs` and `exclude_files` inputs as additional caller-supplied exclusions instead of shipping broad default exclusion lists.

### Notes
- This release changes the effective default exclusion set for consumers who relied on built-in defaults.
- Review consuming workflows and set explicit exclusions before upgrading if your repositories contain CI, log, runner, or generated artifact directories.
- Prefer upgrading through `mennotech/github-workflows` when possible so repository-specific defaults and guardrails can be managed at the workflow layer.

## [1.0.2] - 2026-03-19

### Security
- `codesign-files-windows` and `deploy-files-windows` now enforce `.git` as a mandatory exclusion even if callers override `exclude_dirs`.

## [1.0.1] - 2026-03-19

### Fixed
- `codesign-files-windows` now evaluates excluded directories against repository-relative paths instead of full runner workspace paths, preventing false exclusions on GitHub Actions runners.

## [1.0.0] - 2026-03-12

### Added
- Three GitHub Actions for Windows runners:
  - `import-codesigning-cert-windows`
  - `codesign-files-windows`
  - `deploy-files-windows`
- CI workflows for YAML validation, PowerShell syntax validation, per-action smoke tests, and end-to-end integration tests.
- PowerShell linting with `PSScriptAnalyzer` and repository-specific analyzer settings.
- Example workflow usage and contributor instructions for maintaining the action set.

### Changed
- Consolidated duplicated test helper scripts into a smaller reusable test toolkit.
- Improved workflow reliability around certificate handling, step outputs, and integration test setup.
- Simplified the code signing script structure while keeping helper functions internal to the script.

### Security
- Added certificate cleanup support and explicit guidance to remove imported signing certificates after use.

[1.1.0]: https://github.com/mennotech/github-actions/releases/tag/v1.1.0
[1.0.2]: https://github.com/mennotech/github-actions/releases/tag/v1.0.2
[1.0.1]: https://github.com/mennotech/github-actions/releases/tag/v1.0.1
[1.0.0]: https://github.com/mennotech/github-actions/releases/tag/v1.0.0