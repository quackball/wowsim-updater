#!/bin/bash
source tz.env
docker build --platform linux/amd64 --rm -t wowsim .
