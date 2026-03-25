# Changelog

All notable changes to this repository will be documented in this file.

The format is based on Keep a Changelog and the project follows Semantic Versioning.

## [Unreleased]

## [1.2.0] - 2026-03-25

### Added
- `build-repo-matrix` composite action: converts a newline-separated list of `owner/repo` strings into a compact JSON array suitable for a GitHub Actions matrix strategy. Outputs a single `matrix` value consumed directly by `strategy.matrix`.
- `dispatch-repository-event` composite action: sends a `repository_dispatch` event to a target repository via the GitHub API. Exposes `status_code` and `success` outputs so callers can gate subsequent steps on acceptance.
- `wait-for-downstream-run` composite action: polls a target repository for a `repository_dispatch`-triggered workflow run created at or after a supplied timestamp and waits for it to reach a terminal state. Exposes `run_id`, `run_url`, `conclusion`, and `timed_out` outputs.

## [1.1.2] - 2026-03-24

### Fixed
- `deploy-files-windows` no longer throws `The property 'Count' cannot be found on this object` when `exclude_dirs`, `exclude_files`, or `robocopy_options` inputs are empty or contain a single value. Under `Set-StrictMode -Version Latest`, PowerShell silently unwraps single-element and empty arrays returned via the pipeline, causing downstream `.Count` calls to fail against a bare string or `$null`. The shared `Get-StringArrayParameterFromEnvironment` helper now uses `Write-Output -NoEnumerate` on every return path to preserve array identity.

### Added
- `ConvertTo-StringArray` exported from `shared/GitHubActions.Common.psm1`: coerces any null, string, or array input into a trimmed, non-empty `[string[]]`. Used internally by `Get-StringArrayParameterFromEnvironment` to guarantee a non-null `string[]` on every code path.
- Pester 5 unit tests in `shared/GitHubActions.Common.Tests.ps1` covering the null, blank, single-value, and multi-value coercion paths for both `ConvertTo-StringArray` and `Get-StringArrayParameterFromEnvironment`.
- `unit-tests` CI job in `.github/workflows/validate-syntax.yml` runs the Pester test suite on every push and pull request.

## [1.1.1] - 2026-03-19

### Security
- `codesign-files-windows` now defaults `cleanup_certificate` to `true`. Imported signing certificates are removed from the Windows certificate store after signing unless the caller explicitly opts out. This prevents certificate persistence on self-hosted runners.
- `import-codesigning-cert-windows` no longer logs the temporary PFX file path during import.
- `deploy-files-windows` now logs a warning when the permission-test temporary file cannot be removed instead of silently continuing.

### Documentation
- Trimmed verbose and redundant content from `INSTRUCTIONS.md`, `README.md`, and `EXAMPLE_USAGE.md`.
- Fixed broken reference to non-existent `CROSS_PLATFORM_MIGRATION.md` in `INSTRUCTIONS.md`.
- Updated `INSTRUCTIONS.md` security guidelines to reflect the new `cleanup_certificate` default.
- Simplified certificate handling guidance throughout to remove repetition.

### Notes
- Callers that previously relied on `cleanup_certificate` defaulting to `false` must now pass `cleanup_certificate: false` explicitly if they need the certificate to persist after signing (e.g., for a subsequent verification step in the same job).

## [1.1.0] - 2026-03-19

### Release Notes Highlight

- `v1.1.0` is a minor release because the default deployment and signing exclusion behavior changed.
- `exclude_dirs` and `exclude_files` are now caller-controlled additive exclusions rather than broad built-in defaults.
- Only `.git` remains enforced automatically, so consumers should review and explicitly provide exclusions such as `.github`, `logs`, `_work`, and any generated output directories they do not want deployed or signed.
- Most consuming repositories should prefer `mennotech/github-workflows`, where Mennotech can provide sane defaults and safer orchestration guidance. Direct `mennotech/github-actions` usage should be treated as an advanced integration path.

### Added
- `shared/GitHubActions.Common.psm1` to centralize common PowerShell helper logic used across reusable actions.
- Repository line-ending rules for YAML files so local `yamllint` runs and CI expect the same LF formatting.

### Changed
- `codesign-files-windows` and `deploy-files-windows` now treat `exclude_dirs` and `exclude_files` inputs as additional caller-supplied exclusions instead of shipping broad default exclusion lists.
- Array-valued action parameters now resolve environment variables through shared helper logic instead of maintaining duplicated parsing in each script.
- User-facing documentation now recommends `mennotech/github-workflows` as the default consumer path for most repositories, with direct `mennotech/github-actions` usage positioned as an advanced option.
- Self-signed CI test certificates remain untrusted by default; test workflows must opt into the narrow untrusted-root verification override explicitly instead of mutating trust stores.

### Fixed
- Local PowerShell validation now ignores `.venv` content and runs `PSScriptAnalyzer` reliably per repository file.
- YAML files were normalized to LF line endings so repository `yamllint` runs pass consistently.

### Documentation
- Updated README, example usage, and release guidance to highlight the `v1.1.0` exclusion behavior change and explain when consumers should prefer `mennotech/github-workflows`.
- Clarified that direct action consumers must pass repository-specific exclusions explicitly when they do not want CI, log, runner, or generated output directories processed.
- Documented that `allow_untrusted_root_in_test` is test-only, requires the expected signer thumbprint, and does not relax production certificate verification defaults.

### Notes
- This release changes the effective default exclusion set for consumers who relied on built-in defaults.
- Review consuming workflows and set explicit exclusions before upgrading if your repositories contain CI, log, runner, or generated artifact directories.
- Prefer upgrading through `mennotech/github-workflows` when possible so repository-specific defaults and guardrails can be managed at the workflow layer.
- Compared to `v1.0.2`, certificate handling guidance is now stricter: self-signed test certificates are handled through explicit test-only verification overrides rather than any broad acceptance of `UnknownError` or trust-store modification.

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

[1.2.0]: https://github.com/mennotech/github-actions/releases/tag/v1.2.0
[1.1.2]: https://github.com/mennotech/github-actions/releases/tag/v1.1.2
[1.1.1]: https://github.com/mennotech/github-actions/releases/tag/v1.1.1
[1.1.0]: https://github.com/mennotech/github-actions/releases/tag/v1.1.0
[1.0.2]: https://github.com/mennotech/github-actions/releases/tag/v1.0.2
[1.0.1]: https://github.com/mennotech/github-actions/releases/tag/v1.0.1
[1.0.0]: https://github.com/mennotech/github-actions/releases/tag/v1.0.0
