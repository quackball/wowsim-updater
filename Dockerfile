FROM alpine:3.18

# Default timezone to Denver
ARG TZ=America/Denver
ENV TZ=$TZ

RUN apk add --no-cache busybox-openrc curl jq unzip wget gcompat tzdata

WORKDIR /home/root
COPY ./scripts/* ./
COPY tz.env ./tz.env
COPY profile /root/.profile
COPY crontab /tmp/crontab
RUN cat /tmp/crontab > /etc/crontabs/root

# Port 3333 is used for the application
EXPOSE 3333

# Healthcheck for the application
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3333/health || exit 1

ENTRYPOINT ["ash", "setup.sh"]
