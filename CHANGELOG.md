# Changelog

All notable changes to this repository will be documented in this file.

The format is based on Keep a Changelog and the project follows Semantic Versioning.

## [Unreleased]

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

[1.0.2]: https://github.com/mennotech/github-actions/releases/tag/v1.0.2
[1.0.1]: https://github.com/mennotech/github-actions/releases/tag/v1.0.1
[1.0.0]: https://github.com/mennotech/github-actions/releases/tag/v1.0.0