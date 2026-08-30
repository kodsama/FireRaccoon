# syntax=docker/dockerfile:1
# Flutter web is arch-independent — build it once on the host (BUILDPLATFORM).
# Dart AOT must match the image arch — compile on TARGETPLATFORM (QEMU when
# cross-building arm64 on an amd64 runner).

FROM --platform=$BUILDPLATFORM ghcr.io/cirruslabs/flutter:stable AS web-build
RUN chown -R ubuntu:ubuntu /sdks/flutter /home/ubuntu && \
    mkdir -p /home/ubuntu/.pub-cache && \
    chown -R ubuntu:ubuntu /home/ubuntu
USER ubuntu
ENV HOME=/home/ubuntu
WORKDIR /app

COPY --chown=ubuntu:ubuntu pubspec.yaml pubspec.lock ./
COPY --chown=ubuntu:ubuntu packages/engine packages/engine
COPY --chown=ubuntu:ubuntu packages/mcp packages/mcp
COPY --chown=ubuntu:ubuntu packages/app_backend packages/app_backend
RUN flutter pub get --no-example

COPY --chown=ubuntu:ubuntu . .
USER ubuntu
RUN git config --global --add safe.directory /sdks/flutter
RUN flutter build web --release --no-pub --dart-define=FIRERACCOON_MODE=server

RUN find build/web -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.wasm' -o -name '*.json' -o -name '*.css' -o -name '*.html' \) -exec gzip -k -9 {} +

# Native (or QEMU) compile for linux/amd64 or linux/arm64.
FROM dart:stable AS server-build
WORKDIR /app
# app_backend depends on the engine by path, so ../engine has to exist before
# pub can resolve anything at all. Manifests first, both packages, so a change
# to source alone does not re-resolve the world.
COPY packages/engine/pubspec.yaml packages/engine/pubspec.lock /engine/
COPY packages/app_backend/pubspec.yaml packages/app_backend/pubspec.lock ./
RUN dart pub get
COPY packages/engine/ /engine/
COPY packages/app_backend/ ./
RUN dart pub get && dart compile exe bin/fireraccoon_server.dart -o /app/fireraccoon_server

# Runtime: Dart server + static web UI for the target arch.
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -u 10001 -m fireraccoon

COPY --from=server-build /app/fireraccoon_server /usr/local/bin/fireraccoon_server
COPY --from=web-build /app/build/web /app/web

RUN mkdir -p /data && chown -R fireraccoon:fireraccoon /data /app/web

USER fireraccoon
ENV FIRERACCOON_MODE=server \
    DATA_DIR=/data \
    WEB_ROOT=/app/web \
    PORT=8080

VOLUME ["/data"]
EXPOSE 8080
CMD ["fireraccoon_server"]
