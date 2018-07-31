FROM openjdk:8-jdk-slim as builder
# arguments can be referenced at build time chose master for the stable release channel
#  Provide docker images for each release
# Dont git pull just use tar
ARG RELEASE=3.4.1
ENV RELEASE "${RELEASE}"
ENV RELEASE_ARCHIVE "https://github.com/eXist-db/exist/archive/eXist-${RELEASE}.tar.gz"
ENV EXIST_MAX "/usr/local/exist-eXist-${RELEASE}"
ENV EXIST_MIN  "/usr/local/eXist"
# Install tools required to build the project
WORKDIR /usr/local
RUN apt-get update && apt-get install -y --no-install-recommends \
  wget \
  tar \
  expat \
  ttf-dejavu-core \
  libpng16-16 \
  liblcms2-2 \
  fontconfig \
  libfreetype6 \
 && wget --trust-server-name  -nc --quiet --show-progress --progress=bar:force:noscroll $RELEASE_ARCHIVE \
 && tar -xzf eXist-${RELEASE} \
 && cd $EXIST_MAX && ./build.sh

WORKDIR $EXIST_MAX

RUN mkdir -p $EXIST_MIN \
  && echo 'copy sundries' \
  && for i in \
  'LICENSE' \
  'client.properties'; \
  do cp $i $EXIST_MIN  ; done \
  && echo 'copy base folders' \
  && cp -r autodeploy $EXIST_MIN \
  && echo 'copy base libs' \
  && for i in \
  'start.jar' \
  'exist.jar' \
  'exist-optional.jar';\
  do cp $i $EXIST_MIN  ; done \
  && mkdir $EXIST_MIN/lib \
  && for i in \
  'lib/core' \
  'lib/endorsed' \
  'lib/optional' \
  'lib/user' \
  'lib/extensions' \
  'lib/test' ;\
  do cp -r $i $EXIST_MIN/lib  ; done \
  && echo 'copy config files' \
  && for i in \
  'descriptor.xml' \
  'log4j2.xml' \
  'mime-types.xml' \
  'conf.xml';\
  do cp $i $EXIST_MIN  ; done \
  && echo 'copy tools' \
  && mkdir $EXIST_MIN/tools \
  && for i in \
  'tools/ant' \
  'tools/aspectj' \
  'tools/jetty'; \
  do cp -r $i $EXIST_MIN/tools; done \
  && echo 'copy webapp' \
  && cp -r webapp  $EXIST_MIN \
  && echo 'copy extension libs' \
  && mkdir -p $EXIST_MIN/extensions/modules \
  && cp -r extensions/modules/lib  $EXIST_MIN/extensions/modules \
  && mkdir -p $EXIST_MIN/extensions/contentextraction \
  && cp -r extensions/contentextraction/lib $EXIST_MIN/extensions/contentextraction \
  && mkdir -p $EXIST_MIN/extensions/webdav \
  && cp -r extensions/webdav/lib $EXIST_MIN/extensions/webdav \
  && mkdir -p $EXIST_MIN/extensions/xqdoc \
  && cp -r extensions/xqdoc/lib $EXIST_MIN/extensions/xqdoc \
  && mkdir -p $EXIST_MIN/extensions/expath \
  && cp -r extensions/expath/lib $EXIST_MIN/extensions/expath \
  && mkdir -p $EXIST_MIN/extensions/betterform/main \
  && cp -r extensions/betterform/main/lib $EXIST_MIN/extensions/betterform/main \
  && mkdir -p $EXIST_MIN/extensions/xprocxq/main \
  && cp -r extensions/xprocxq/main/lib $EXIST_MIN/extensions/xprocxq/main \
  && mkdir -p $EXIST_MIN/extensions/indexes/lucene \
  && cp -r extensions/indexes/lucene/lib $EXIST_MIN/extensions/indexes/lucene \
  && mkdir -p $EXIST_MIN//extensions/exquery/restxq \
  && cp -r extensions/exquery/lib $EXIST_MIN/extensions/exquery \
  && cp -r extensions/exquery/restxq/lib $EXIST_MIN/extensions/exquery/restxq \
  && cd ../ && rm -r $EXIST_MAX

  # && mkdir -p $EXIST_MIN/webapp/WEB-INF \
  # && for i in \
  # 'webapp/404.html' \
  # 'webapp/controller.xql' \
  # 'webapp/logo.jpg'; \
  # do cp $i $EXIST_MIN/webapp ; done \
  # && cp -r webapp/resources $EXIST_MIN/webapp \
  # && for i in \
  # 'webapp/WEB-INF/betterform-version.info' \
  # 'webapp/WEB-INF/catalog.xml' \
  # 'webapp/WEB-INF/controller-config.xml' \
  # 'webapp/WEB-INF/web.xml'; \
  # do cp $i $EXIST_MIN/webapp/WEB-INF ; done \
  # && cp -r webapp/WEB-INF/entities $EXIST_MIN/webapp/WEB-INF \

FROM gcr.io/distroless/java:debug
# Copy compiled exist-db files
COPY --from=builder /usr/local/eXist /eXist
WORKDIR /eXist

# ARG CACHE_MEM
# ARG MAX_BROKER

# # Build-time metadata as defined at http://label-schema.org
# ARG BUILD_DATE
# ARG VCS_REF
# ARG VERSION="5.0.0-SNAPSHOT"

# LABEL org.label-schema.build-date=${BUILD_DATE} \
#       org.label-schema.name="exist-docker" \
#       org.label-schema.description="minimal exist-db docker image with FO support" \
#       org.label-schema.url="https://exist-db.org" \
#       org.label-schema.vcs-ref=${VCS_REF} \
#       org.label-schema.vcs-url="https://github.com/duncdrum/exist-docker" \
#       org.label-schema.vendor="exist-db" \
#       org.label-schema.version=$VERSION \
#       org.label-schema.schema-version="1.0"


# # ENV for gcr
# ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
# ENV EXIST_HOME /eXist
# ENV DATA_DIR /exist-data

# # Make sure JDK and gcr have matching java versions
# COPY --from=jdk /usr/lib/jvm/java-1.8.0-openjdk-amd64/jre/lib/amd64/libfontmanager.so /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/amd64/
# COPY --from=jdk /usr/lib/jvm/java-1.8.0-openjdk-amd64/jre/lib/amd64/libjavalcms.so /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/amd64/

# # Copy over dependancies for Apache FOP, missing from gcr's JRE
COPY --from=builder /usr/lib/x86_64-linux-gnu/liblcms2.so.2.0.8 /usr/lib/x86_64-linux-gnu/liblcms2.so.2
COPY --from=builder /usr/lib/x86_64-linux-gnu/libfreetype.so.6.12.3 /usr/lib/x86_64-linux-gnu/libfreetype.so.6
COPY --from=builder /usr/lib/x86_64-linux-gnu/libpng16.so.16.28.0 /usr/lib/x86_64-linux-gnu/libpng16.so.16

# Copy dependancies for Apache Batik (used by Apache FOP to handle SVG rendering)
COPY --from=builder /usr/lib/x86_64-linux-gnu/libfontconfig.so.1.8.0 /usr/lib/x86_64-linux-gnu/libfontconfig.so.1
COPY --from=builder /usr/share/fontconfig /usr/share/fontconfig
COPY --from=builder /usr/share/fonts/truetype/dejavu /usr/share/fonts/truetype/dejavu
COPY --from=builder /lib/x86_64-linux-gnu/libexpat.so.1 /lib/x86_64-linux-gnu/libexpat.so.1
# COPY --from=jdk /etc/fonts /etc/fonts

# # Copy previously removed accessibility.properties from JDK, or it will throw errors in SVG processing
# COPY --from=jdk /etc/java-8-openjdk/accessibility.properties /etc/java-8-openjdk/accessibility.properties

# WORKDIR ${EXIST_HOME}

# COPY --from=builder /target/conf.xml ./conf.xml
# COPY --from=builder /target/exist/webapp/WEB-INF/data ${DATA_DIR}

# # Optionally add customised configuration files
# # ADD ./src/conf.xml .
# ADD ./src/log4j2.xml .
# # ADD ./src/mime-types.xml .
# # ADD ./src/exist-webapp-context.xml ./tools/jetty/webapps/
# # ADD ./src/controller-config.xml ./webapp/WEB-INF/controller-config.xml

# # Configure JVM for us in container (here there be dragons)
ENV JAVA_TOOL_OPTIONS -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:MaxRAMFraction=1 -XX:+UseG1GC -XX:+UseStringDeduplication 
# -Dfile.encoding=UTF8 -Djava.awt.headless=true -Dorg.exist.db-connection.cacheSize=${CACHE_MEM:-256}M -Dorg.exist.db-connection.pool.max=${MAX_BROKER:-20}

# # Port configuration
EXPOSE 8080 8443

# HEALTHCHECK CMD [ "java", "-jar", "start.jar", "client", "--no-gui",  "--xpath", "system:get-version()" ]

ENTRYPOINT [ "java", "-jar", "start.jar", "jetty" ]
