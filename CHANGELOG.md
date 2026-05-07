# Changelog

All notable changes to this repository are documented in this file.

## [Unreleased]

### Added

- Added a new `tomcat:10-jdk21` image profile under `10/`, including:
  - `10/Dockerfile.renovate`
  - `10/common/server.xml`
  - `10/common/context.xml.default`
  - `10/10-jdk21/10-jdk21-temurin-ubuntu/Dockerfile`

### Changed

- Updated `.github/workflows/continuous-image-build-pipeline.yml` from a computed matrix (`java_version` + `type`) to an explicit `matrix.include` list that defines `context`, `file`, `base_image`, and `tags` per build variant.
- Rewrote the image build step to consume matrix fields directly (`context`, `file`, `BASE_IMAGE`, and `tags`) for both Tomcat 9 and Tomcat 10 variants.
- Added GitHub Actions job naming via `name: Build ${{ matrix.name }}` and per-variant `matrix.name` values for clearer run visibility.
- Set `strategy.fail-fast: false` so one failed variant does not cancel all remaining matrix builds.
- Updated `renovate.json` to detect both `9/Dockerfile.renovate` and `10/Dockerfile.renovate` with directory-specific regex rules.
- Added Renovate `packageRules.allowedVersions` constraints to keep Tomcat updates within each major line (`9.x` for `9/`, `10.x` for `10/`).
- Extended `ignorePaths` in `renovate.json` to include `10/**/Dockerfile-*` and `10/**/Dockerfile`.
