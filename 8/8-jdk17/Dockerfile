FROM tomcat:10-jdk17
MAINTAINER Analyser, analyser@gmail.com

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Asia/Shanghai

COPY sources.list        /etc/apt/sources.list
COPY server.xml          /usr/local/tomcat/conf/
COPY context.xml.default /usr/local/tomcat/conf/Catalina/localhost/

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        telnet tzdata unzip dumb-init; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /usr/local/tomcat/webapps.dist

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    dpkg-reconfigure --frontend noninteractive tzdata

