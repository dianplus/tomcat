# Tomcat Container Base Image Guideline

<!-- MarkdownTOC -->

- [Tomcat Container Base Image Guideline](#tomcat-container-base-image-guideline)
  - [1. Cross platform container image building](#1-cross-platform-container-image-building)
    - [1.1. for Podman](#11-for-podman)
    - [1.2. for Docker](#12-for-docker)
      - [1.2.0. Cross platform building](#120-cross-platform-building)
      - [1.2.1. Method 1 - Use buildx builder](#121-method-1---use-buildx-builder)
        - [1.2.1.1. Prepare buildx builder](#1211-prepare-buildx-builder)
        - [1.2.1.2. Build and push](#1212-build-and-push)
      - [1.2.2. Method 2 - The hard way](#122-method-2---the-hard-way)
        - [1.2.2.1. Build dedicated platform image](#1221-build-dedicated-platform-image)
        - [1.2.2.2. Create manifest list and add manifest](#1222-create-manifest-list-and-add-manifest)
        - [1.2.2.3. Push manifest](#1223-push-manifest)

<!-- /MarkdownTOC -->

## 1. Cross platform container image building

### 1.1. for Podman

```bash
podman login \
  --username=username@your.domain.name \
  registry.domain.name

# Build JDK version (default)
podman manifest create \
  registry.domain.name/reponame/tomcat:9-jdk17

podman build \
  --platform linux/amd64,linux/arm64 \
  --manifest registry.domain.name/reponame/tomcat:9-jdk17 \
  --build-arg BASE_IMAGE=tomcat:9-jdk17 \
  --file Dockerfile \
  .

podman manifest push \
  --all registry.domain.name/reponame/tomcat:9-jdk17

# Build JRE version
podman manifest create \
  registry.domain.name/reponame/tomcat:9-jre17

podman build \
  --platform linux/amd64,linux/arm64 \
  --manifest registry.domain.name/reponame/tomcat:9-jre17 \
  --build-arg BASE_IMAGE=tomcat:9-jre17 \
  --file Dockerfile \
  .

podman manifest push \
  --all registry.domain.name/reponame/tomcat:9-jre17
```

### 1.2. for Docker

#### 1.2.0. Cross platform building

Ensure qemu is installed on the system for cross-platform container image building.

#### 1.2.1. Method 1 - Use buildx builder

##### 1.2.1.1. Prepare buildx builder

```toml
# buildkitd.toml
debug = true
[registry."docker.io"]
    mirrors = [
        "mirror01.domain.name",
        "mirror02.domain.name"
    ]
```

```bash
docker buildx rm container && \
docker buildx create \
  --name container \
  --driver docker-container \
  --config buildkitd.toml \
  --driver-opt image=registry.domain.name/reponame/buildkit:v0.15.1 \
  --use --bootstrap && \
docker buildx ls
```

##### 1.2.1.2. Build and push

```bash
# Build JDK version (default)
docker buildx build \
  --builder container \
  --platform linux/amd64,linux/arm64 \
  --push \
  --build-arg BASE_IMAGE=tomcat:9-jdk17 \
  --build-arg HTTP_PROXY=http://192.168.199.21:1087 \
  --build-arg HTTPS_PROXY=http://192.168.199.21:1087 \
  --build-arg NO_PROXY=192.168.*,10.*,172.*,your.domain.name \
  --tag registry.domain.name/reponame/tomcat:9-jdk17 \
  --file Dockerfile \
  .

# Build JRE version
docker buildx build \
  --builder container \
  --platform linux/amd64,linux/arm64 \
  --push \
  --build-arg BASE_IMAGE=tomcat:9-jre17 \
  --build-arg HTTP_PROXY=http://192.168.199.21:1087 \
  --build-arg HTTPS_PROXY=http://192.168.199.21:1087 \
  --build-arg NO_PROXY=192.168.*,10.*,172.*,your.domain.name \
  --tag registry.domain.name/reponame/tomcat:9-jre17 \
  --file Dockerfile \
  .
```

#### 1.2.2. Method 2 - The hard way

##### 1.2.2.1. Build dedicated platform image

```bash
# AMD64 - JDK version
docker build \
  --tag registry.domain.name/reponame/tomcat:9-jdk17-amd64 \
  --build-arg BASE_IMAGE=tomcat:9-jdk17 \
  --file Dockerfile \
  .
docker push registry.domain.name/reponame/tomcat:9-jdk17-amd64

# ARM64 - JDK version
docker build \
  --tag registry.domain.name/reponame/tomcat:9-jdk17-arm64 \
  --build-arg BASE_IMAGE=tomcat:9-jdk17 \
  --file Dockerfile \
  .
docker push registry.domain.name/reponame/tomcat:9-jdk17-arm64

# AMD64 - JRE version
docker build \
  --tag registry.domain.name/reponame/tomcat:9-jre17-amd64 \
  --build-arg BASE_IMAGE=tomcat:9-jre17 \
  --file Dockerfile \
  .
docker push registry.domain.name/reponame/tomcat:9-jre17-amd64

# ARM64 - JRE version
docker build \
  --tag registry.domain.name/reponame/tomcat:9-jre17-arm64 \
  --build-arg BASE_IMAGE=tomcat:9-jre17 \
  --file Dockerfile \
  .
docker push registry.domain.name/reponame/tomcat:9-jre17-arm64
```

##### 1.2.2.2. Create manifest list and add manifest

```bash
# JDK version
docker manifest create \
  registry.domain.name/reponame/tomcat:9-jdk17 \
  --amend registry.domain.name/reponame/tomcat:9-jdk17-amd64 \
  --amend registry.domain.name/reponame/tomcat:9-jdk17-arm64

# JRE version
docker manifest create \
  registry.domain.name/reponame/tomcat:9-jre17 \
  --amend registry.domain.name/reponame/tomcat:9-jre17-amd64 \
  --amend registry.domain.name/reponame/tomcat:9-jre17-arm64
```

##### 1.2.2.3. Push manifest

```bash
# JDK version
docker manifest push registry.domain.name/reponame/tomcat:9-jdk17

# JRE version
docker manifest push registry.domain.name/reponame/tomcat:9-jre17
```
