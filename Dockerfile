FROM alpine:latest

# Default timezone to Denver
ARG TZ=America/Denver
ENV TZ=$TZ

RUN apk add --no-cache busybox-openrc curl jq unzip wget gcompat tzdata

WORKDIR /home/root

COPY ./scripts/* ./
COPY tz.env ./tz.env

EXPOSE 3333

ENTRYPOINT [ "ash", "setup.sh" ]
