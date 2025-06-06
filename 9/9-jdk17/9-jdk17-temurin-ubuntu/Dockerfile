FROM tomcat:9-jdk17
LABEL maintainer="Analyser, analyser@gmail.com"

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Asia/Shanghai

COPY server.xml          /usr/local/tomcat/conf/
COPY context.xml.default /usr/local/tomcat/conf/Catalina/localhost/

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        telnet tzdata unzip dumb-init && \
    rm -rf /var/lib/apt/lists/* /usr/local/tomcat/webapps.dist

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    dpkg-reconfigure --frontend noninteractive tzdata

ENV JDK_JAVA_OPTIONS="\
--add-opens=java.base/java.lang=ALL-UNNAMED \
--add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
--add-opens=java.base/java.io=ALL-UNNAMED \
--add-opens=java.base/java.util=ALL-UNNAMED \
--add-opens=java.base/java.util.concurrent=ALL-UNNAMED \
--add-opens=java.base/java.net=ALL-UNNAMED \
--add-opens=java.base/java.math=ALL-UNNAMED \
--add-opens=java.base/java.nio=ALL-UNNAMED \
--add-opens=java.base/java.text=ALL-UNNAMED \
--add-opens=java.base/jdk.internal.loader=ALL-UNNAMED \
--add-opens=java.desktop/java.awt.font=ALL-UNNAMED \
--add-opens=java.naming/com.sun.jndi.ldap=ALL-UNNAMED \
--add-opens=java.rmi/sun.rmi.transport=ALL-UNNAMED \
--add-exports=java.base/sun.net.www=ALL-UNNAMED \
--add-exports=java.base/sun.util.calendar=ALL-UNNAMED"

ENTRYPOINT ["/usr/bin/dumb-init", "--"]

CMD ["catalina.sh", "run"]
