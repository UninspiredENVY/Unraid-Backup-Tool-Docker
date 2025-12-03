FROM alpine:3.19

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    rclone \
    tzdata \
    coreutils \
    ca-certificates

RUN mkdir -p /app /config /logs

COPY app/backup.sh /app/backup.sh
RUN chmod +x /app/backup.sh

WORKDIR /app

ENV TZ="America/Chicago"
ENV DISCORD_WEBHOOK=""
ENV SOURCE_PATHS=""
ENV DEST_PATH="/dest"
ENV CLOUD_DESTS=""
ENV EXCLUDES=""
ENV MIN_FREE_GB=10
ENV KEEP_LOCAL=7

ENTRYPOINT ["/app/backup.sh"]
