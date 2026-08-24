# dianplus/tomcat — Custom Tomcat Base Images

Multi-arch custom Tomcat base images built on the official `tomcat` images, hardened with a tuned server configuration and operational tooling. Images are built by GitHub Actions and published to Alibaba Cloud Container Registry (ACR).

- Registry: `registry.cn-hangzhou.aliyuncs.com/dianplus/tomcat`
- Platforms: `linux/amd64`, `linux/arm64`
- Lines: Tomcat 9 / 10 / 11

## Image Variants

| Line | Base image | Published tags |
| --- | --- | --- |
| 9 / JDK 17 | `tomcat:9-jdk17` | `9-jdk17`, `9-jdk17-temurin`, `9-jdk17-temurin-ubuntu` |
| 9 / JRE 17 | `tomcat:9-jre17` | `9-jre17`, `9-jre17-temurin`, `9-jre17-temurin-ubuntu` |
| 9 / JDK 21 | `tomcat:9-jdk21` | `9-jdk21` |
| 9 / JRE 21 | `tomcat:9-jre21` | `9-jre21` |
| 9 / JDK 25 | `tomcat:9-jdk25` | `9-jdk25` |
| 9 / JRE 25 | `tomcat:9-jre25` | `9-jre25` |
| 10 / JDK 21 | `tomcat:10-jdk21` | `10-jdk21`, `10-jdk21-temurin`, `10-jdk21-temurin-ubuntu` |
| 11 / JDK 25 | `tomcat:11-jdk25` | `11-jdk25`, `11-jdk25-temurin`, `11-jdk25-temurin-ubuntu` |

All variants within a line share the same directory and `<line>/common` configuration; each variant Dockerfile is parameterized by `BASE_IMAGE`.

## What Is Customized

Layered on top of the official image:

- `common/server.xml` — tuned NIO2 connector (`maxThreads=4096`, `maxConnections=8000`, `acceptCount=800`, HTTP compression, relaxed query/path chars, `RemoteIpValve` for `X-Forwarded-*`), `unpackWARs=false`, `autoDeploy=false`, and an explicit root `<Context docBase="ROOT">`.
- `common/context.xml.default` — resource caching defaults for all webapps (`cacheMaxSize=100000`).
- Packages: `telnet`, `tzdata`, `unzip`, `dumb-init`, `net-tools`, `iproute2`; stock `webapps.dist` removed.
- Timezone: `Asia/Shanghai`.
- `JDK_JAVA_OPTIONS` — a broad set of `--add-opens` / `--add-exports` for common library reflection needs.
- Process model: `dumb-init` as PID 1 (`ENTRYPOINT ["/usr/bin/dumb-init", "--"]`, `CMD ["catalina.sh", "run"]`).

## Usage — Application Images Build on Top

Base images ship with an **empty `webapps` by design**: `server.xml` declares `docBase="ROOT"`, so a bare container is expected to fail startup. Downstream application images provide the webapp:

```dockerfile
FROM registry.cn-hangzhou.aliyuncs.com/dianplus/tomcat:11-jdk25
COPY webapps/ROOT /usr/local/tomcat/webapps/ROOT
```

## Repository Layout

```
9/ 10/ 11/                     # one directory per Tomcat major line
  Dockerfile.renovate          # version anchor consumed by Renovate (FROM tomcat:X.Y.Z)
  common/server.xml            # shared server configuration for the line
  common/context.xml.default
  <line>-jdkXX/<line>-jdkXX-temurin-ubuntu/Dockerfile   # variant Dockerfile (ARG BASE_IMAGE)
.github/workflows/
  continuous-image-build-pipeline.yml                    # build & publish pipeline
renovate.json                  # Renovate managers, per-line version locks, automerge rule
CHANGELOG.md
```

## Build & Release

CI (`.github/workflows/continuous-image-build-pipeline.yml`) builds all 8 variants for `linux/amd64,linux/arm64` and pushes to ACR on every push to `master`, on `v*.*.*` tags, and via manual dispatch. Buildx provenance attestations are disabled (`provenance: false`) because ACR rejects OCI attestation manifests.

Manual cross-platform builds (maintainer reference):

```bash
# Docker buildx
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --push \
  --build-arg BASE_IMAGE=tomcat:11-jdk25 \
  --tag registry.cn-hangzhou.aliyuncs.com/dianplus/tomcat:11-jdk25 \
  --file 11/11-jdk25/11-jdk25-temurin-ubuntu/Dockerfile \
  11/

# Podman
podman manifest create registry.cn-hangzhou.aliyuncs.com/dianplus/tomcat:11-jdk25
podman build \
  --platform linux/amd64,linux/arm64 \
  --manifest registry.cn-hangzhou.aliyuncs.com/dianplus/tomcat:11-jdk25 \
  --build-arg BASE_IMAGE=tomcat:11-jdk25 \
  --file 11/11-jdk25/11-jdk25-temurin-ubuntu/Dockerfile \
  11/
podman manifest push --all registry.cn-hangzhou.aliyuncs.com/dianplus/tomcat:11-jdk25
```

## Version Maintenance (Renovate)

- Each line's `Dockerfile.renovate` pins `FROM tomcat:X.Y.Z` as a **detection anchor only** — actual builds use floating aliases (`tomcat:11-jdk25`), so image content always tracks the latest upstream patch release on the next CI run.
- `renovate.json` constrains each line to its major (`allowedVersions` `/^9\./`, `/^10\./`, `/^11\./`).
- Upstream base-image tag bumps (docker/tomcat, patch/minor, in the three anchor files) are **automerged**: Renovate opens the PR and merges it itself (`platformAutomerge: false`, `merge-commit`, `ignoreTests: true` since PRs produce no status checks). Master-push CI rebuild is the downstream safety net.
- GitHub Actions updates (`actions/*`) and any major bumps remain manual.

## License

[MIT](LICENSE)
