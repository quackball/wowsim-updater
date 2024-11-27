FROM alpine:latest

# Default timezone to Denver
ARG TZ=America/Denver
ENV TZ=$TZ

RUN apk add --no-cache busybox-openrc curl jq unzip wget gcompat tzdata
RUN rc-update add crond

WORKDIR /home/root
RUN touch setup.log wowsim.log update.log /root/.profile

COPY ./scripts/* ./
COPY tz.env ./tz.env

EXPOSE 3333

ENTRYPOINT [ "ash", "setup.sh" ]
