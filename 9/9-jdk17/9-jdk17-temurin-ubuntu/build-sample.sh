#!/bin/bash

docker buildx build \
	--builder container \
	--platform linux/amd64,linux/arm64 \
	--push \
	-f Dockerfile \
	--build-arg HTTP_PROXY=http://192.168.199.21:1087 \
	--build-arg HTTPS_PROXY=http://192.168.199.21:1087 \
	--build-arg NO_PROXY=192.168.*,10.*,172.*,mirrors.tuna.tsinghua.edu.cn,mirrors.aliyun.com,*.aliyun.com,*.aliyuncs.com,*.dianplus.cn,*.dianjia.io,*.taobao.com \
	-t registry.cn-hangzhou.aliyuncs.com/dianplus/tomcat:9-jdk17-temurin-noble ./
