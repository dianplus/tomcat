# Changelog

All notable changes to this repository are documented in this file.

## [Unreleased]

### Added

- Added a new `tomcat:11-jdk25` image profile under `11/`, including:
  - `11/Dockerfile.renovate`
  - `11/common/server.xml`
  - `11/common/context.xml.default`
  - `11/11-jdk25/11-jdk25-temurin-ubuntu/Dockerfile`
- Added a `tomcat11-jdk25` build variant to the CI matrix, publishing plain, `-temurin`, and `-temurin-ubuntu` tags.
- Added a Renovate packageRule that automerges upstream base image tag bumps (docker/tomcat, patch/minor, in the `9/`/`10/`/`11/` `Dockerfile.renovate` anchors) via Renovate's own merge path (`platformAutomerge: false`, `automergeStrategy: "merge-commit"`, `ignoreTests: true`).

### Changed

- Updated `.github/workflows/continuous-image-build-pipeline.yml` from a computed matrix (`java_version` + `type`) to an explicit `matrix.include` list that defines `context`, `file`, `base_image`, and `tags` per build variant.
- Rewrote the image build step to consume matrix fields directly (`context`, `file`, `BASE_IMAGE`, and `tags`) for both Tomcat 9 and Tomcat 10 variants.
- Added GitHub Actions job naming via `name: Build ${{ matrix.name }}` and per-variant `matrix.name` values for clearer run visibility.
- Set `strategy.fail-fast: false` so one failed variant does not cancel all remaining matrix builds.
- Updated `renovate.json` to detect `9/Dockerfile.renovate`, `10/Dockerfile.renovate`, and `11/Dockerfile.renovate` with directory-specific regex rules.
- Added Renovate `packageRules.allowedVersions` constraints to keep Tomcat updates within each major line (`9.x` for `9/`, `10.x` for `10/`, `11.x` for `11/`).
- Extended `ignorePaths` in `renovate.json` to include `10/**/Dockerfile-*`, `10/**/Dockerfile`, `11/**/Dockerfile-*`, and `11/**/Dockerfile`.
- Migrated `renovate.json` to the current Renovate config schema (`fileMatch` → `managerFilePatterns` with `/regex/` string patterns).

### Fixed

- Disabled buildx provenance attestations (`provenance: false`) in the CI build step — Alibaba Cloud Container Registry rejects the OCI attestation manifests recent buildx versions emit by default, which failed every variant push with `denied: unknown manifest class for application/vnd.oci.empty.v1+json`.

### Removed

- Removed the `tomcat11-jre25` build variant from the CI matrix and deleted the `11-jre25`, `11-jre25-temurin`, and `11-jre25-temurin-ubuntu` tags from the registry (Tomcat 11 ships JDK form only).
