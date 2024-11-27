FROM alpine:latest

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

EXPOSE 3333

CMD ["ash", "setup.sh"]
