# syntax=docker/dockerfile:experimental
# Portions Copyright (C) 2018 The eXist-db Project
# Portions Copyright (C) 2017 Evolved Binary Ltd
# Released under the AGPL v3.0 license

# @arg VERSION - can be stable or RC e.g. '4.3.1'
# - this a requirement of hooks/build, see notes below
# @arg BRANCH - branch can be a
# - branch name e.g release,develop, name-of-branch
# - tagged commit e.g. eXist-4.3.1
# @arg COMMIT - can be any commit hash ( short or long )
#   e.g 3b19579, 3b195797a2c2f35913891412859b06d94f189229
# @arg BUILD_DATE
# @arg VCS_REF
# @arg CACHE_MEM
# @arg MAX_BROKER
# NOTES:
# VERSION, BUILD_DATE, VCS_REF build-args are created
# via a dockerhub build hook in hooks/build
# CACHE_MEM, MAX_BROKER build args are available,
# if you want to override the defaults
# Build process - build-args provided via 'docker build' are optional.
#   if build-arg VERSION is empty, then version is ignored
#   if build-arg BRANCH is empty then defaults to develop


FROM openjdk:8-jdk-slim as builder

# Provide docker images for each commit

ARG VERSION
ARG BRANCH=master
ENV EXIST_MIN  "/exist"
ENV EXIST_MAX  "/usr/local/exist"

# Install tools required to build the project
WORKDIR /usr/local
RUN apt-get update && apt-get install -y --no-install-recommends \
  xmlstarlet \
  expat \
  fontconfig \
  git \
  libfreetype6 \
  liblcms2-2 \
  libpng16-16 \
  ttf-dejavu-core \
  && if [ -n "${VERSION}" ] ; then export BRANCH=eXist-${VERSION}; fi \
  && echo " - cloning eXist" \
  && if [ -n "${COMMIT}" ] ; then git clone --depth=2000 --progress https://github.com/exist-db/exist.git \
  && cd $EXIST_MAX \
  && git checkout ${COMMIT}; \
  else git clone --depth=1 --branch ${BRANCH} --progress https://github.com/exist-db/exist.git ; fi \
  && cd $EXIST_MAX \
  && ./build.sh \
  && cd $EXIST_MAX && ./build.sh

WORKDIR $EXIST_MAX

# build minimal exist
# move config files into config dir then symlink to origin
RUN mkdir -p $EXIST_MIN \
  && echo ' - copy sundries' \
  && for i in \
  'LICENSE' \
  'collection.xconf.init' \
  'client.properties'; \
  do cp $i $EXIST_MIN; done\
  && echo ' - copy base folders' \
  && cp -r autodeploy $EXIST_MIN \
  && echo ' - copy base libs' \
  && for i in \
  'exist-optional.jar'\
  'exist.jar' \
  'start.jar'; \
  do cp $i $EXIST_MIN; done \
  && mkdir $EXIST_MIN/lib \
  && for i in \
  'lib/core' \
  'lib/endorsed' \
  'lib/extensions' \
  'lib/optional' \
  'lib/test' \
  'lib/user'; \
  do cp -r $i $EXIST_MIN/lib  ; done \
  && echo ' - symlink root config files' \
  && mkdir $EXIST_MIN/config \
  && for i in \
  'conf.xml'\
  'descriptor.xml' \
  'log4j2.xml' \
  'mime-types.xml'; \
  do mv $i $EXIST_MIN/config;\
  ln -s -v -T $EXIST_MIN/config/$i $EXIST_MIN/$i; done \
  && echo ' - copy tools' \
  && mkdir $EXIST_MIN/tools \
  && for i in \
  'tools/ant' \
  'tools/aspectj' \
  'tools/jetty'; \
  do cp -r $i $EXIST_MIN/tools; done \
  && echo ' - copy extension libs' \
  && mkdir -p $EXIST_MIN/extensions/exquery/restxq \
  && mkdir -p $EXIST_MIN/extensions/betterform/main \
  && mkdir -p $EXIST_MIN/extensions/contentextraction \
  && mkdir -p $EXIST_MIN/extensions/expath \
  && mkdir -p $EXIST_MIN/extensions/indexes/lucene \
  && mkdir -p $EXIST_MIN/extensions/webdav \
  && mkdir -p $EXIST_MIN/extensions/xqdoc \
  && cp -r extensions/betterform/main/lib $EXIST_MIN/extensions/betterform/main \
  && cp -r extensions/contentextraction/lib $EXIST_MIN/extensions/contentextraction \
  && cp -r extensions/expath/lib $EXIST_MIN/extensions/expath \
  && cp -r extensions/exquery/lib $EXIST_MIN/extensions/exquery \
  && cp -r extensions/exquery/restxq/lib $EXIST_MIN/extensions/exquery/restxq \
  && cp -r extensions/indexes/lucene/lib $EXIST_MIN/extensions/indexes/lucene \
  && cp -r extensions/webdav/lib $EXIST_MIN/extensions/webdav \
  && cp -r extensions/xqdoc/lib $EXIST_MIN/extensions/xqdoc \
  && echo ' - copy ivy libs' \
  && for dir in extensions/modules/**/lib; \
  do mkdir -p $EXIST_MIN/$dir; done \
  && for f in extensions/modules/**/lib/*; \
  do cp -r $f $EXIST_MIN/$f; done \
  && echo ' - copy webapp' \
  && cp -r webapp  $EXIST_MIN \
  && echo ' - move and symlink webapp config files' \
  && mv $EXIST_MIN/tools/jetty/webapps/exist-webapp-context.xml $EXIST_MIN/config \
  && ln -s -v -T \
  $EXIST_MIN/config/exist-webapp-context.xml \
  $EXIST_MIN/tools/jetty/webapps/exist-webapp-context.xml \
  && echo 'move and symlink jetty config files' \
  && mv $EXIST_MIN/webapp/WEB-INF/controller-config.xml $EXIST_MIN/config \
  && ln -s -v -T \
  $EXIST_MIN/config/controller-config.xml \
  $EXIST_MIN/webapp/WEB-INF/controller-config.xml \
  && cd ../ && rm -r $EXIST_MAX

# Config files are modified here
RUN echo 'modifying conf files'\
&& cd $EXIST_MIN/config \
&& xmlstarlet ed  -L -s '/Configuration/Loggers/Root' -t elem -n 'AppenderRefTMP' -v '' \
 -i //AppenderRefTMP -t attr -n 'ref' -v 'STDOUT'\
 -r //AppenderRefTMP -v AppenderRef \
 log4j2.xml

 # Optionally add customised configuration files
 #  COPY ./src/log4j2.xml $EXIST_MIN/config

# FROM gcr.io/distroless/java:debug
FROM gcr.io/distroless/java

# Build-time metadata as defined at http://label-schema.org
# and used by autobuilder @hooks/build
LABEL org.label-schema.build-date=${BUILD_DATE} \
      org.label-schema.description="Minimal exist-db docker image with FO support" \
      org.label-schema.name="existdb" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://exist-db.org" \
      org.label-schema.vcs-ref=${VCS_REF} \
      org.label-schema.vcs-url="https://github.com/exist-db/docker-existdb" \
      org.label-schema.vendor="exist-db"

ENV EXIST_HOME  "/exist"

# Copy compiled exist-db files
COPY --from=builder $EXIST_HOME  $EXIST_HOME
WORKDIR $EXIST_HOME

# # # Make sure JDK and gcr have matching java versions
# # COPY --from=jdk /usr/lib/jvm/java-1.8.0-openjdk-amd64/jre/lib/amd64/libfontmanager.so /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/amd64/
# # COPY --from=jdk /usr/lib/jvm/java-1.8.0-openjdk-amd64/jre/lib/amd64/libjavalcms.so /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/amd64/

# Copy over dependancies for Apache FOP, missing from gcr's JRE
COPY --from=builder /usr/lib/x86_64-linux-gnu/libfreetype.so.6 /usr/lib/x86_64-linux-gnu/libfreetype.so.6
COPY --from=builder /usr/lib/x86_64-linux-gnu/liblcms2.so.2 /usr/lib/x86_64-linux-gnu/liblcms2.so.2
COPY --from=builder /usr/lib/x86_64-linux-gnu/libpng16.so.16 /usr/lib/x86_64-linux-gnu/libpng16.so.16

# Copy dependancies for Apache Batik (used by Apache FOP to handle SVG rendering)
COPY --from=builder /etc/fonts /etc/fonts
COPY --from=builder /lib/x86_64-linux-gnu/libexpat.so.1 /lib/x86_64-linux-gnu/libexpat.so.1
COPY --from=builder /usr/lib/x86_64-linux-gnu/libfontconfig.so.1 /usr/lib/x86_64-linux-gnu/libfontconfig.so.1
COPY --from=builder /usr/share/fontconfig /usr/share/fontconfig
COPY --from=builder /usr/share/fonts/truetype/dejavu /usr/share/fonts/truetype/dejavu

# make CACHE_MEM and MAX_BROKER available to users
ARG CACHE_MEM
ARG MAX_BROKER

# Configure JVM for use in container (here there be dragons)
# also sets default values to previous two arguments
ENV JAVA_TOOL_OPTIONS \
  -Dfile.encoding=UTF8 \
  -Dsun.jnu.encoding=UTF-8 \
  -Djava.awt.headless=true \
  -Dorg.exist.db-connection.cacheSize=${CACHE_MEM:-256}M \
  -Dorg.exist.db-connection.pool.max=${MAX_BROKER:-20} \
  -XX:+UnlockExperimentalVMOptions \
  -XX:+UseCGroupMemoryLimitForHeap \
  -XX:+UseG1GC \
  -XX:+UseStringDeduplication \
  -XX:MaxRAMFraction=1

# Port configuration
EXPOSE 8080 8443

HEALTHCHECK CMD [ "java", "-jar", "start.jar", "client", "--no-gui",  "--xpath", "system:get-version()" ]

ENTRYPOINT [ "java", "-jar", "start.jar", "jetty" ]
