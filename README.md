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
  - [2. Configuration Guide](#2-configuration-guide)
    - [2.1. Architecture Overview](#21-architecture-overview)
    - [2.2. Key Configuration Parameters](#22-key-configuration-parameters)
      - [RemoteIpValve Configuration](#remoteipvalve-configuration)
      - [Connector Configuration](#connector-configuration)
    - [2.3. JVM Tuning](#23-jvm-tuning)
  - [3. Reverse Proxy Configuration](#3-reverse-proxy-configuration)
    - [3.1. OpenResty Configuration Example](#31-openresty-configuration-example)
    - [3.2. Access Log Collection Strategy](#32-access-log-collection-strategy)
    - [3.3. Key HTTP Headers](#33-key-http-headers)
  - [4. Kubernetes Deployment Configuration](#4-kubernetes-deployment-configuration)
    - [4.1. Complete Deployment Example](#41-complete-deployment-example)
    - [4.2. JVM Parameter Configuration](#42-jvm-parameter-configuration)
    - [4.3. Resource Limits](#43-resource-limits)
    - [4.4. Graceful Shutdown](#44-graceful-shutdown)
    - [4.5. Health Checks](#45-health-checks)
  - [5. Monitoring and Troubleshooting](#5-monitoring-and-troubleshooting)
    - [5.1. Log Locations](#51-log-locations)
    - [5.2. Log Format](#52-log-format)
    - [5.3. Common Issues and Solutions](#53-common-issues-and-solutions)
      - [Issue: Incorrect Client IP in Application Logs](#issue-incorrect-client-ip-in-application-logs)
      - [Issue: Connection Timeouts](#issue-connection-timeouts)
      - [Issue: High Memory Usage](#issue-high-memory-usage)
      - [Issue: Slow Response Times](#issue-slow-response-times)
    - [5.4. Performance Monitoring](#54-performance-monitoring)
  - [6. Kubernetes Deployment Example - For graceful shutdown](#6-kubernetes-deployment-example---for-graceful-shutdown)

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

## 2. Configuration Guide

### 2.1. Architecture Overview

**Current Architecture**: Cloud SLB → Self-hosted Reverse Proxy (OpenResty) → Tomcat Container (Kubernetes Deployment)

This Tomcat image is designed to work behind a reverse proxy layer. The configuration has been optimized for this deployment pattern.

### 2.2. Key Configuration Parameters

#### RemoteIpValve Configuration

The `RemoteIpValve` is configured in `server.xml` to properly handle X-Forwarded-* headers from the reverse proxy:

- `remoteIpHeader="X-Forwarded-For"`: Extracts the real client IP
- `protocolHeader="X-Forwarded-Proto"`: Handles HTTPS protocol detection
- `protocolHeaderHttpsValue="https"`: Identifies HTTPS requests
- `portHeader="X-Forwarded-Port"`: Handles port forwarding information
- `internalProxies`: Regex pattern for internal proxy IPs (Kubernetes cluster internal IPs)
- `trustedProxies`: Regex pattern for trusted proxy IPs

**Note**: The `internalProxies` and `trustedProxies` patterns should be adjusted based on your actual Kubernetes cluster network configuration.

#### Connector Configuration

The HTTP connector is optimized for reverse proxy scenarios:

- `maxKeepAliveRequests="200"`: Increased for better connection reuse with reverse proxy
- `keepAliveTimeout="20000"`: Extended timeout for reverse proxy connections
- `protocol="org.apache.coyote.http11.Http11Nio2Protocol"`: NIO2 protocol for better performance
- Compression enabled for common content types

### 2.3. JVM Tuning

JVM parameters should be configured in Kubernetes Deployment through environment variables, not in the Dockerfile. This allows:

- Different configurations for different environments (dev, test, prod)
- Dynamic adjustment without rebuilding the image
- Easy parameter tuning based on actual load

See section 3 for Kubernetes Deployment configuration examples.

## 3. Reverse Proxy Configuration

### 3.1. OpenResty Configuration Example

```nginx
upstream tomcat_backend {
    server tomcat-service:8080;
    keepalive 32;
}

server {
    listen 80;
    server_name example.com;

    # Access log configuration (JSON format - best practice)
    # Using escape=json to automatically escape special characters in string values
    log_format tomcat_access_json escape=json
        '{'
        '"time":"$time_iso8601",'
        '"remote_addr":"$remote_addr",'
        '"remote_user":"$remote_user",'
        '"request":"$request",'
        '"status":$status,'
        '"body_bytes_sent":$body_bytes_sent,'
        '"request_time":$request_time,'
        '"upstream_response_time":"$upstream_response_time",'
        '"http_referer":"$http_referer",'
        '"http_user_agent":"$http_user_agent",'
        '"x_forwarded_for":"$http_x_forwarded_for",'
        '"x_forwarded_proto":"$http_x_forwarded_proto",'
        '"x_forwarded_port":"$http_x_forwarded_port",'
        '"x_real_ip":"$http_x_real_ip"'
        '}';

    access_log /var/log/nginx/tomcat_access.log tomcat_access_json;

    location / {
        proxy_pass http://tomcat_backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

### 3.2. Access Log Collection Strategy

**Best Practice (without cost consideration)**: Collect access logs at the SLB layer

**Advantages**:

- Most complete traffic view (including rejected requests)
- Unified entry point logs for global analysis
- Can see real client IP (before X-Forwarded-For)
- Better for troubleshooting and security auditing

**Recommended Practice (with cost consideration)**: Collect access logs at the reverse proxy layer (OpenResty)

**Layered Collection Strategy**:

- SLB layer (primary): Collect all ingress traffic
- Reverse proxy layer (secondary): Collect proxied requests, record application layer information
- Tomcat layer: Do not collect or use only for debugging

**Note**: Tomcat layer access logs are not configured by default to reduce resource consumption and disk I/O.

### 3.3. Key HTTP Headers

The reverse proxy should set the following headers:

- `X-Forwarded-For`: Client's real IP address
- `X-Forwarded-Proto`: Original protocol (http/https)
- `X-Forwarded-Port`: Original port number
- `X-Real-IP`: Client's real IP (alternative to X-Forwarded-For)

## 4. Kubernetes Deployment Configuration

### 4.1. Complete Deployment Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tomcat-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: tomcat
  template:
    metadata:
      labels:
        app: tomcat
    spec:
      containers:
      - name: tomcat
        image: registry.domain.name/reponame/tomcat:9-jdk17
        env:
        - name: CATALINA_OPTS
          value: "-Xms512m -Xmx2048m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+PrintGCDetails -XX:+PrintGCDateStamps -Xloggc:/usr/local/tomcat/logs/gc.log"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2.5Gi"
            cpu: "2000m"
        lifecycle:
          preStop:
            exec:
              command: ["catalina.sh", "stop", "20"]
        terminationGracePeriodSeconds: 30
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 5
          timeoutSeconds: 3
```

### 4.2. JVM Parameter Configuration

Configure JVM parameters through environment variables:

- `CATALINA_OPTS`: Tomcat-specific JVM options
- `JDK_JAVA_OPTIONS`: General JVM options

**Example JVM configurations**:

```yaml
env:
- name: CATALINA_OPTS
  value: "-Xms512m -Xmx2048m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

**Tuning recommendations**:
- Heap size: Adjust `-Xms` and `-Xmx` based on available memory and application requirements
- GC strategy: G1GC is recommended for most scenarios
- GC logging: Enable for production environments to monitor GC behavior

### 4.3. Resource Limits

Set appropriate resource requests and limits:

```yaml
resources:
  requests:
    memory: "1Gi"    # Minimum memory required
    cpu: "500m"      # Minimum CPU required
  limits:
    memory: "2.5Gi"  # Maximum memory allowed (should be > heap size)
    cpu: "2000m"     # Maximum CPU allowed
```

**Note**: Memory limit should be higher than JVM heap size to account for off-heap memory usage.

### 4.4. Graceful Shutdown

Configure graceful shutdown to ensure proper connection draining:

```yaml
lifecycle:
  preStop:
    exec:
      command: ["catalina.sh", "stop", "20"]
terminationGracePeriodSeconds: 30
```

This allows Tomcat to gracefully stop accepting new connections and complete existing requests before termination.

### 4.5. Health Checks

Configure liveness and readiness probes:

```yaml
livenessProbe:
  httpGet:
    path: /
    port: 8080
  initialDelaySeconds: 60
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 5
```

## 5. Monitoring and Troubleshooting

### 5.1. Log Locations

**Access Logs**:
- Reverse proxy layer (OpenResty): `/var/log/nginx/tomcat_access.log`
- SLB layer: Configured in cloud service provider console

**Application Logs**:
- Tomcat logs: `/usr/local/tomcat/logs/`
  - `catalina.out`: Main application log
  - `localhost.log`: Host-specific log
  - `gc.log`: GC log (if enabled)

### 5.2. Log Format

**OpenResty Access Log Format (JSON - Best Practice)**:

```json
{
  "time": "2024-01-01T12:00:00+00:00",
  "remote_addr": "192.168.1.100",
  "remote_user": "-",
  "request": "GET /api/test HTTP/1.1",
  "status": 200,
  "body_bytes_sent": 1024,
  "request_time": 0.123,
  "upstream_response_time": "0.100",
  "http_referer": "https://example.com",
  "http_user_agent": "Mozilla/5.0...",
  "x_forwarded_for": "10.0.0.1",
  "x_forwarded_proto": "https",
  "x_forwarded_port": "443",
  "x_real_ip": "10.0.0.1"
}
```

**Benefits of JSON format**:

- Structured data for easy parsing and analysis
- Easy integration with log analysis systems (ELK, Loki, SLS, etc.)
- Better querying and filtering capabilities
- Extensible for adding new fields

### 5.3. Common Issues and Solutions

#### Issue: Incorrect Client IP in Application Logs

**Symptom**: Application logs show proxy IP instead of real client IP.

**Solution**:

- Verify `RemoteIpValve` configuration in `server.xml`
- Check that `internalProxies` and `trustedProxies` include your Kubernetes cluster IP ranges
- Verify reverse proxy is setting `X-Forwarded-For` header correctly

#### Issue: Connection Timeouts

**Symptom**: Requests timeout or connections are dropped.

**Solution**:

- Check `keepAliveTimeout` and `maxKeepAliveRequests` settings
- Verify reverse proxy timeout settings match Tomcat settings
- Review network policies and service mesh configurations

#### Issue: High Memory Usage

**Symptom**: Container exceeds memory limits or OOMKilled.

**Solution**:

- Adjust JVM heap size (`-Xmx`) based on actual usage
- Review GC logs to identify memory leaks
- Consider increasing container memory limits
- Check for memory leaks in application code

#### Issue: Slow Response Times

**Symptom**: Application responds slowly under load.

**Solution**:

- Review JVM GC logs for GC pauses
- Adjust GC strategy and parameters
- Check connection pool settings
- Review application code for performance bottlenecks
- Monitor reverse proxy upstream response times

### 5.4. Performance Monitoring

**Key Metrics to Monitor**:

- Request rate and response times
- JVM heap usage and GC frequency
- Connection pool utilization
- Thread pool utilization
- Error rates (4xx, 5xx responses)

**Tools**:

- Kubernetes metrics (via Prometheus/Grafana)
- Application Performance Monitoring (APM) tools
- GC log analysis tools
- Reverse proxy access log analysis

## 6. Kubernetes Deployment Example - For graceful shutdown

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
