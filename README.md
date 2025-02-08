# Tomcat Container Base Image Guideline

<!-- MarkdownTOC -->

- 1/ Cross platform container image building
  - 1/1 for Podman
  - 1/2 for Docker
    - 1/2/0 Cross platform building
    - 1/2/1 Method 1 - Use buildx builder
      - 1/2/1/1 Prepare buildx builder
      - 1/2/1/2 Build and push
    - 1/2/2 Method 2 - The hard way
      - 1/2/2/1 Build didicated platform image
      - 1/2/2/2 Create manifest list and add manifest
      - 1/2/2/3 Push manifest
- 2/ Kubernetes Deployment Example - For graceful shutdown

<!-- /MarkdownTOC -->

## 1. Cross platform container image building

### 1.1. for Podman

```bash
podman login \
  --username=username@your.domain.name \
  registry.domain.name

podman manifest create \
  registry.domain.name/reponame/tomcat:9-jdk17

podman build \
  --platform linux/amd64,linux/arm64 \
  --manifest registry.domain.name/reponame/tomcat:9-jdk17 \
  --file Dockerfile \
  .

podman manifest push \
  --all registry.domain.name/reponame/tomcat:9-jdk17
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
docker build \
  --builder container \
  --platform linux/amd64,linux/arm64 \
  --push \
  --build-arg HTTP_PROXY=http://192.168.199.21:1087 \
  --build-arg HTTPS_PROXY=http://192.168.199.21:1087 \
  --build-arg NO_PROXY=192.168.*,10.*,172.*,your.domain.name \
  --tag registry.domain.name/reponame/tomcat:9-jdk17 \
  --file Dockerfile \
  .
```

#### 1.2.2. Method 2 - The hard way

##### 1.2.2.1. Build didicated platform image

```bash
# AMD64
docker build \
  --tag registry.domain.name/reponame/tomcat:9-jdk17-amd64 \
  --build-arg ARCH=amd64/ \
  .
docker push registry.domain.name/reponame/tomcat:9-jdk17-amd64

# ARM64
docker build \
  --tag registry.domain.name/reponame/tomcat:9-jdk17-arm64 \
  --build-arg ARCH=arm64/ \
  .
docker push registry.domain.name/reponame/tomcat:9-jdk17-arm64
```

##### 1.2.2.2. Create manifest list and add manifest

```bash
docker manifest create \
  registry.domain.name/reponame/tomcat:9-jdk17 \
  --amend registry.domain.name/reponame/tomcat:9-jdk17-amd64 \
  --amend registry.domain.name/reponame/tomcat:9-jdk17-arm64
```

##### 1.2.2.3. Push manifest

```bash
docker manifest push registry.domain.name/reponame/tomcat:9-jdk17
```

## 2. Kubernetes Deployment Example - For graceful shutdown

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openapi-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: openapi
  template:
    metadata:
      labels:
        app: openapi
    spec:
      containers:
      - name: openapi
        lifecycle:
          preStop:
            exec:
              command: ["catalina.sh", "stop", "20"]
      terminationGracePeriodSeconds: 30
```
