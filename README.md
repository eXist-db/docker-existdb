# docker-eXist
minimal exist-db docker image with FO support

[![Build Status](https://travis-ci.com/eXist-db/docker-existdb.svg?branch=master)](https://travis-ci.com/eXist-db/docker-existdb)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/ace7cb88e9934b5f9ae772e981db177f)](https://www.codacy.com/app/eXist-db/docker-existdb?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=eXist-db/docker-existdb&amp;utm_campaign=Badge_Grade)
[![License](https://img.shields.io/badge/license-AGPL%203.1-orange.svg)](https://www.gnu.org/licenses/agpl-3.0.html)
[![](https://images.microbadger.com/badges/image/existdb/existdb.svg)](https://microbadger.com/images/existdb/existdb "Get your own image badge on microbadger.com")
[![](https://images.microbadger.com/badges/version/existdb/existdb.svg)](https://microbadger.com/images/existdb/existdb "Get your own version badge on microbadger.com")
[![](https://images.microbadger.com/badges/commit/existdb/existdb.svg)](https://microbadger.com/images/existdb/existdb "Get your own commit badge on microbadger.com")

This repository holds the source files for building a minimal docker image of the [exist-db](https://www.exist-db.org) xml database, automatically building from eXist's source code repo. It uses Google Cloud Platforms ["Distroless" Docker Images](https://github.com/GoogleCloudPlatform/distroless).


## Requirements
*   [Docker](https://www.docker.com): `18-stable`

For test development only:
*   [bats-core](https://github.com/bats-core/bats-core): `1.1.0`

## How to use
Pre-build images are available on [DockerHub](https://hub.docker.com/r/existdb/existdb/). There are two channels:
*   `release` for the latest stable releases based on the [`master` branch](https://github.com/eXist-db/exist/tree/master)
*   `latest` for last commit to the [`develop` branch](https://github.com/eXist-db/exist/tree/develop).

To download the image run:
```bash
docker pull existdb/existdb:latest
```

once the download is complete, you can run the image
```bash
docker run -it -d -p 8080:8080 -p 8443:8443 --name exist existdb/existdb:latest
```

### What does this do?

*   `-it` allocates a TTY and keeps STDIN open.  This allows you to interact with the running Docker container via your console.
*   `-d` detaches the container from the terminal that started it. So your container won't stop when you close the terminal.
*   `-p` maps the Containers internal and external port assignments (we recommend sticking with matching pairs). This allows you to connect to the eXist-db Web Server running in the Docker container.
*   `--name` lets you provide a name (instead of using a randomly generated one)

The only required parts are `docker run existdb/existdb`. For a full list of available options see the official [Docker documentation](https://docs.docker.com/engine/reference/commandline/run/)

After running the `pull` and `run` commands, you can access eXist-db via [localhost:8080](localhost:8080) in your browser.

To stop the container issue:
```bash
docker stop exist
```

or if you omitted the `-d` flag earlier press `CTRL-C` inside the terminal showing the exist logs.

### Interacting with the running container
You can interact with a running container as if it were a regular Linux host (**without a shell** in our case). You can issue shell-like commands to the [Java admin client](http://exist-db.org/exist/apps/doc/java-admin-client.xml?field=all&id=D3.3.2#command-line), as we do throughout this readme, but you can't open the shell in interactive mode.

The name of the container in this readme is `exist`:

```bash
# Using java syntax on a running eXist-db instances
docker exec exist java -jar start.jar client --no-gui --xpath "system:get-memory-max()"

# Interacting with the JVM
docker exec exist java -version
```

Containers build from this image run a periodical health-check to make sure that eXist-db is operating normally. If `docker ps` reports `unhealthy` you can get a more detailed report with this command:  
```bash
docker inspect --format='{{json .State.Health}}' exist
```

### Logging
There is a slight modification to eXist's logger to ease access to the logs via:
```bash
docker logs exist
```
This works best when providing the `-t` flag when running an image.

## Use as base image
A common usage of these images is as a base image for your own applications. We'll take a quick look at three scenarios of increasing complexity, to demonstrate how to achieve common tasks from inside `Dockerfile`.

### A simple app image
The simplest and straightforward case assumes that you have a `.xar` app inside a `build` folder on the same level as the `Dockerfile`. To get an image of an eXist-db instance with your app installed and running, simply adopt the `docker cp ...` command to the appropriate `Dockerfile` syntax.
```
FROM existdb/existdb:4.5.0

COPY build/*.xar /exist/autodeploy

```
You should see something like this:

```bash
Sending build context to Docker daemon  4.337MB
Step 1/2 : FROM existdb/existdb:release
 ---> 3f4dbbce9afa
Step 2/2 : COPY build/*.xar /exist/autodeploy
 ---> ace38b0809de
```

The result is a new image of your app installed into eXist-db. Since you didn't provide further instructions it will simply reuse the `EXPOSE`, `CMD`, `HEALTHCHECK`, etc instructions defined by the base image. You can now publish this image to a docker registry and share it with others.

### A slightly more complex single stage image
The following example will install your app, but also modify the underlying eXist-db instance in which your app is running. Instead of a local build directory, we'll download the `.xar` from the web, and copy a modified `conf.xml` from a `src/` directory along side your `Dockerfile`. To execute any of the `docker exec …` style commands from this readme, we need to use `RUN`.

```
FROM existdb/existdb

# NOTE: this is for syntax demo purposes only
RUN ["java", "-jar", "start.jar", "client", "--no-gui", "-l", "-u", "admin", "-P", "", "-x", "sm:passwd('admin','123')"]

# use a modified conf.xml
COPY src/conf.xml /exist

ADD https://github.com/eXist-db/documentation/releases/download/4.0.4/exist-documentation-4.0.4.xar /exist/autodeploy
```

The above is intended to demonstrate the kind of operations available to you in a single stage build. For security reasons [more elaborate techniques](https://docs.docker.com/engine/swarm/secrets/) for not sharing your password in the clear are highly recommended, such as the use of secure variables inside your CI environment. However, the above shows you how to execute the [Java Admin Client](http://www.exist-db.org/exist/apps/doc/java-admin-client.xml) from inside a `Dockerfile`, which in turn allows you to run any XQuery code you want when modifying the eXist-db instance that will ship with your images. You can also chain multiple `RUN` commands.

As for the sequence of the commands, those with the most frequent changes should come last to avoid cache busting. Chances are, you wouldn't change the admin password very often, but the `.xar` might change more frequently.

### Multi-stage builds
Lastly, you can eliminate external dependencies even further by using a multi-stage build. To ensure compatibility between different Java engines we recommend sticking with debian based images for the builder stage.

The following 2-stage build will download and install `ant` and `nodeJS` into a builder stage which then downloads frontend dependencies before building the `.xar` file.
The second stage (each `FROM` begins a stage) is just the simple example from above. Such a setup ensures that non of your collaborators has to have `java` or `nodeJS` installed, and is great for fully automated builds and deployment.

```
# START STAGE 1
FROM openjdk:8-jdk-slim as builder

USER root

ENV ANT_VERSION 1.10.5
ENV ANT_HOME /etc/ant-${ANT_VERSION}

WORKDIR /tmp

RUN wget http://www-us.apache.org/dist/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz \
    && mkdir ant-${ANT_VERSION} \
    && tar -zxvf apache-ant-${ANT_VERSION}-bin.tar.gz \
    && mv apache-ant-${ANT_VERSION} ${ANT_HOME} \
    && rm apache-ant-${ANT_VERSION}-bin.tar.gz \
    && rm -rf ant-${ANT_VERSION} \
    && rm -rf ${ANT_HOME}/manual \
    && unset ANT_VERSION

ENV PATH ${PATH}:${ANT_HOME}/bin

WORKDIR /home/my-app
COPY . .
RUN apk add --no-cache --virtual .build-deps \
 nodejs \
 nodejs-npm \
 git \
 && npm i npm@latest -g \
 && ant


# START STAGE 2
FROM existdb/existdb:release

COPY --from=builder /home/my-app/build/*.xar /exist/autodeploy

EXPOSE 8080 8443

CMD [ "java", "-jar", "start.jar", "jetty" ]
```

The basic idea of the multi-staging is that everything you need for building your software should be managed by docker, so that all collaborators can rely on one stable environment. In the end, and after how ever many stages you need, only the files necessary to run your app should go into the final stage. The possibilities are virtually endless, but with this example and the `Dockerfile` in this repo you should get a pretty good idea of how you might apply this idea to your own projects.

## Development use via `docker-compose`
This repo provides a `docker-compose.yml` for use with [docker-compose](https://docs.docker.com/compose/). We highly recommend docker-compose for local development or integration into multi-container environments. For options on how to configure your own compose file, follow the link at the beginning of this paragraph.

To start exist using the compose file, type:
```bash
# starting eXist-db
docker-compose up -d
# stop eXist-db
docker-compose down
```

The compose file provided by this repo, declares two named [volumes](https://docs.docker.com/storage/volumes/):

*   `exist-data` so that any database changes persist through reboots.
*   `exist-config` so you can configure eXist startup options.

Both are declared as mount volumes. If you wish to modify an eXist-db configuration file, use e.g.:

```
# - use docker `cp` to copy file from the eXist container
docker cp exist:exist/config/conf.xml ./src/conf.xml

# - alter the configuration item in the file
# - use docker `cp` to copy file back into the exist container

docker cp ./src/conf.xml exist:exist/config

# - stop and restart container to see your config change take effect
docker-compose down && docker-compose up -d
```

You can configure additional volumes e.g. for backups, or additional services such as an nginx reverse proxy by modifying the `docker-compose.yml`, to suite your needs.

To update the exist-docker image from a newer version
```bash
docker-compose pull
```

### Caveat
As with normal installations, the password for the default dba user `admin` is empty. Change it via the [usermanager](http://localhost:8080/exist/apps/usermanager/index.html) or set the password to e.g. `123` from docker CLI:
```bash
docker exec exist java -jar start.jar client -q -u admin -P '' -x 'sm:passwd("admin", "123")'
```

## Building the Image
To build the docker image run:
```bash
docker build .
```

This will build an eXist-db image with sensible defaults as specified in the `Dockerfile`. The image uses a multi-stage building approach, so you can customize the compilation of eXist-db, or the final image.

To interact with the compilation of eXist-db you should build the first stage, make your changes and commit them, i.e.:

```bash
docker build --target builder .
# Do your thing…
docker commit…
```

### Available Arguments and Defaults
eXist-db's cache size and maximum brokers can be configured at build time using the following syntax.
```bash
docker build --build-arg MAX_CACHE=312 MAX_BROKER=15 .
```

NOTE: Due to the fact that the final images does not provide a shell, setting ENV variables for eXist-db has no effect.
```bash
# !This has no effect!
docker run -it -d -p8080:8080 -e MAX_BROKER=10 ae4d6d653d30
```

If you wish to permanently adopt a customized cache or broker configuration, you can simply make a local copy of the `Dockerfile` and edit the default values there.

```bash
ARG MAX_BROKER=10
```

There are two ways to modify eXist-db's configuration files:
-   The recommended method is to use [xmlstarlet](http://xmlstar.sourceforge.net) in the first build stage, as in the example below, which changes the default logging configuration to a more suitable setting for use with docker. By using this method you can be sure to always be up-to-date with changes to the officially released configuration files.
```bash
# Config files are modified here
RUN echo 'modifying conf files'\
&& cd $EXIST_MIN/config \
&& xmlstarlet ed  -L -s '/Configuration/Loggers/Root' -t elem -n 'AppenderRefTMP' -v '' \
 -i //AppenderRefTMP -t attr -n 'ref' -v 'STDOUT'\
 -r //AppenderRefTMP -v AppenderRef \
 log4j2.xml
```

-   As a convenience, we have added the main configuration files to the `/src` folder of this repo. To use them, make your changes and uncomment the following lines in the `Dockerfile`. To edit additional files, e.g. `conf.xml`, simple add another `COPY` line. While it is easier to keep track of these files during development, there is a risk that the local file is no longer in-sync with those released by eXist-db. It is up to users to ensure their modifications are applied to the correct version of the files, or if you cloned this repo, that they are not overwritten by upstream changes.
```bash
# Optionally add customised configuration files
#  COPY ./src/log4j2.xml $EXIST_MIN/config
```

These files only serve as a template. While upstream updates from eXist-db to them are rare, such upstream changes will be immediately mirrored here. Users are responsible to ensure that local changes in their forks / clones persist when syncing with this repo, e.g. by rebasing their own changes after pulling from upstream.

#### JVM configuration
This image uses an advanced JVM configuration, via the  `JAVA_TOOL_OPTIONS` env variable inside the Dockerfile. You should avoid the traditional way of setting the heap size via `-Xmx` arguments, this can lead to frequent crashes since Java and Docker are (literally) not on the same page concerning available memory.

Instead, use the `-XX:MaxRAMFraction=1` argument to modify the memory available to the JVM *inside* the container. For production use we recommend to increase the value to `2` or even `4`. This value expresses a ratio, so setting it to `2` means half the container's memory will be available to the JVM, '4' means ¼,  etc.

To allocate e.g. 600mb to the container *around* the JVM use:
```bash
docker run -m 600m …
```

Lastly, this image uses a new garbage collection mechanism [garbage first (G1)](https://docs.oracle.com/javase/9/gctuning/garbage-first-garbage-collector.htm#JSGCT-GUID-ED3AB6D3-FD9B-4447-9EDF-983ED2F7A573) `-XX:+UseG1GC` and [string deduplication](http://openjdk.java.net/jeps/192) `-XX:+UseStringDeduplication` to improve performance.

To disable or further tweak these features edit the relevant parts of the `Dockerfile`, or when running the image. As always when using the latest and greatest, YMMV. Feedback about real world experiences with this features in connection with eXist-db is very much welcome.
