# syntax=docker/dockerfile:1
# Flutter web is arch-independent — build it once on the host (BUILDPLATFORM).
# Dart AOT must match the image arch — compile on TARGETPLATFORM (QEMU when
# cross-building arm64 on an amd64 runner).

# Flutter is installed rather than taken from a prebuilt image. The published
# images lag: the newest was still on Dart 3.12 when the SDK floor moved to
# 3.13, so nothing resolved. Cloning one tag pins the toolchain exactly and
# keeps this in step with FLUTTER_VERSION in the workflows.
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS web-build
ARG FLUTTER_VERSION=3.47.2
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -u 1000 builder
USER builder
ENV HOME=/home/builder
# --depth 1 on the tag: the build needs the tree at that version, not its
# history, and a full clone is most of the image.
RUN git clone --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git "$HOME/flutter"
ENV PATH="/home/builder/flutter/bin:/home/builder/.pub-cache/bin:${PATH}"
RUN git config --global --add safe.directory "$HOME/flutter" \
    && flutter config --no-analytics --enable-web \
    && flutter precache --web
WORKDIR /app

COPY --chown=builder:builder pubspec.yaml pubspec.lock ./
COPY --chown=builder:builder packages/engine packages/engine
COPY --chown=builder:builder packages/mcp packages/mcp
COPY --chown=builder:builder packages/app_backend packages/app_backend
RUN flutter pub get --no-example

COPY --chown=builder:builder . .
RUN flutter build web --release --no-pub --dart-define=FIRERACCOON_MODE=server

RUN find build/web -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.wasm' -o -name '*.json' -o -name '*.css' -o -name '*.html' \) -exec gzip -k -9 {} +

# Native (or QEMU) compile for linux/amd64 or linux/arm64.
# Pinned for the same reason, and to the Dart the pinned Flutter carries.
FROM dart:3.13 AS server-build
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
