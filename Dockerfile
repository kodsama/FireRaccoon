# syntax=docker/dockerfile:1
# Flutter web + Dart app backend for server mode.
FROM --platform=$BUILDPLATFORM ghcr.io/cirruslabs/flutter:stable AS build-env
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
RUN flutter build web --release --no-pub --dart-define=FIRERACOON_MODE=server

RUN find build/web -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.wasm' -o -name '*.json' -o -name '*.css' -o -name '*.html' \) -exec gzip -k -9 {} +

WORKDIR /app/packages/app_backend
RUN dart pub get && dart compile exe bin/fireracoon_server.dart -o /app/fireracoon_server

# Runtime: Dart server serves encrypted store + static web UI
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -r -u 10001 -m fireracoon

COPY --from=build-env /app/fireracoon_server /usr/local/bin/fireracoon_server
COPY --from=build-env /app/build/web /app/web

RUN mkdir -p /data && chown -R fireracoon:fireracoon /data /app/web

USER fireracoon
ENV FIRERACOON_MODE=server \
    DATA_DIR=/data \
    WEB_ROOT=/app/web \
    PORT=8080

VOLUME ["/data"]
EXPOSE 8080
CMD ["fireracoon_server"]
