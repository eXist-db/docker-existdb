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

What does this do?

*   `-it` allocates a TTY and keeps STDIN open
*   `-d` detaches the container from the terminal that started it
*   `-p` maps the Containers internal and external port assignments (we recommend sticking with matching pairs)
*   `--name` lets you provide a name (instead of using a randomly generated one)

The only required parts are `docker run existdb/existdb`. For a full list of available options see the official [docker documentation](https://docs.docker.com/engine/reference/commandline/run/)

After running the pull and run commands. You can now access eXist via [localhost:8080](localhost:8080) in your browser.

To stop the container issue:
```bash
docker stop exist
```

or if you omitted the `-d` flag earlier press `CTRL-C` inside the terminal showing the exist logs.

### Interacting with the running container
You can interact with a running container as if it were a regular linux host (without a shell in our case). The name of the container in these examples is `exist`:

```bash
# Using java syntax on a running eXist instances
docker exec exist java -jar start.jar client --no-gui --xpath "system:get-memory-max()"

# Interacting with the JVM
docker exec exist java -version
```

Containers build from this image run a periodical healtcheck to make sure that eXist is operating normally. If `docker ps` reports `unhealthy` you can see a more detailed report  
```bash
docker inspect --format='{{json .State.Health}}' exist
```

### Logging
There is a slight modification to eXist's logger to ease access to the logs via:
```bash
docker logs exist
```
This works best when providing the `-t` flag when running an image.

### Development use via `docker-compose`
This repo provides a `docker-compose.yml` for use with [docker compose](https://docs.docker.com/compose/). We recommend docker-compose for local development or integration into multi-container environments. For options on how to configure your own compose file, follow the link at the beginning of this paragraph.

To start exist using the compose file, type:
```bash
# starting eXist
docker-compose up -d
# stop eXist
docker-compose down
```

The compose file provided by this repo, declares two named [volumes](https://docs.docker.com/storage/volumes/):

*   `exist-data` so that any database changes persist through reboots.
*   `exist-config` so you can modify eXist configuration startup options.

Both are declared as mount volumes. If you wish to modify an eXist configuration file

```
# - use docker `cp` to copy file from the eXist container
docker cp exist:eXist/config/conf.xml ./src/conf.xml
# - alter the configuration item in the file
# - use docker `cp` to copy file back into the eXist container
docker cp ./src/conf.xml exist:eXist/config
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

This will build an eXist image with sensible defaults as specified in the `Dockerfile`. The image uses a multi-stage building approach, so you can customize the compilation of eXist, or the final image.

To interact with the compilation of eXist you should build the first stage, make your changes and commit them, i.e.:

```bash
docker build --target builder .
# Do your thing…
docker commit…
```

### Available Arguments and Defaults
eXist's cache size and maximum brokers can be configured at build time using the following syntax.
```bash
docker build --build-arg MAX_CACHE=312 MAX_BROKER=15 .
```

NOTE: Due to the fact that the final images does not provide a shell setting ENV variables for eXist has no effect.
```bash
# !This has no effect!
docker run -it -d -p8080:8080 -e MAX_BROKER=10 ae4d6d653d30
```

If you wish to permanently adopt a customized cache or broker configuration, you can simply make a local copy of the  `Dockerfile` and edit the default values there.

```bash
ARG MAX_BROKER=10
```

Alternatively you can edit, the configuration files in the `/src` folder to customize the eXist instance. Make your customizations and uncomment the following lines in the `Dockerfile`.
```bash
# Add customized configuration files
# ADD ./src/conf.xml .
# ADD ./src/log4j2.xml .
# ADD ./src/mime-types.xml .
```

These files only serve as a template. While upstream updates from eXist to them are rare, such upstream changes will be immediately mirrored here. Users are responsible to ensure that local changes in their forks / clones persist when syncing with this repo, e.g. by rebasing their own changes after pulling from upstream.

#### JVM configuration
This image uses an advanced JVM configuration, via the  `JAVA_TOOL_OPTIONS` env variable inside the Dockerfile. You should avoid the traditional way of setting the heap size via `-Xmx` arguments, this can lead to frequent crashes since Java and Docker are (literally) not on the same page concerning available memory.

Instead, use the `-XX:MaxRAMFraction=1` argument to modify the memory available to the JVM *inside* the container. For production use we recommend to increase the value to `2` or even `4`. The values express ratios, so setting it to `2` means half the container's memory will be available to the JVM, '4' means ¼,  etc.

To allocate e.g. 600mb to the container *around* the JVM use:
```bash
docker run -m 600m …
```

Lastly, this images uses a new garbage collection mechanism [garbage first (G1)](https://docs.oracle.com/javase/9/gctuning/garbage-first-garbage-collector.htm#JSGCT-GUID-ED3AB6D3-FD9B-4447-9EDF-983ED2F7A573) `-XX:+UseG1GC` and enables [string deduplication](http://openjdk.java.net/jeps/192) `-XX:+UseStringDeduplication` to improve performance.

To disable or further tweak these features edit the relevant parts of the `Dockerfile`, or when running the image. As always when using the latest and greatest, YMMV. Feedback about real world experiences with this features in connection with eXist is very much welcome.
