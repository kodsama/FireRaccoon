# syntax=docker/dockerfile:1
# Flutter web output is arch-independent; build it once on the host platform,
# then produce multi-arch nginx images (linux/amd64, linux/arm64).
FROM --platform=$BUILDPLATFORM ghcr.io/cirruslabs/flutter:stable AS build-env
RUN chown -R ubuntu:ubuntu /sdks/flutter /home/ubuntu && \
    mkdir -p /home/ubuntu/.pub-cache && \
    chown -R ubuntu:ubuntu /home/ubuntu
USER ubuntu
ENV HOME=/home/ubuntu
WORKDIR /app

# Copy package metadata first to optimize Docker layer caching for pub dependencies
COPY --chown=ubuntu:ubuntu pubspec.yaml pubspec.lock ./
COPY --chown=ubuntu:ubuntu packages/engine packages/engine
COPY --chown=ubuntu:ubuntu packages/mcp packages/mcp
RUN flutter pub get --no-example

# Copy remaining source code (modifications here skip 'flutter pub get')
COPY --chown=ubuntu:ubuntu . .
USER ubuntu
RUN git config --global --add safe.directory /sdks/flutter
RUN flutter build web --release --no-pub

# Precompress text/wasm payloads in batch mode so nginx (gzip_static) serves them with minimal CPU & latency
RUN find build/web -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.wasm' -o -name '*.json' -o -name '*.css' -o -name '*.html' \) -exec gzip -k -9 {} +

# Stage 2: Serve the app with Nginx
FROM nginx:alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html
COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
