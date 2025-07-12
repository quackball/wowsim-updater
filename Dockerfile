FROM alpine:3.18

# Default timezone to Denver
ARG TZ=America/Denver
ENV TZ=$TZ

RUN apk add --no-cache busybox-openrc curl jq unzip wget gcompat tzdata && \
    cat /tmp/crontab > /etc/crontabs/root && \
    rm -rf /var/cache/apk/*

WORKDIR /home/root
COPY ./scripts/* ./tz.env profile /root/.profile /tmp/crontab ./

# Create non-root user
RUN adduser -D -u 1000 appuser
USER appuser

# Port 3333 is used for the application
EXPOSE 3333

# Healthcheck for the application
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3333/health || exit 1

ENTRYPOINT ["ash", "setup.sh"]
