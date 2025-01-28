# syntax=docker/dockerfile:1
# check=error=true

ARG RUBY_VERSION=3.4.1
FROM docker.io/library/ruby:$RUBY_VERSION AS base

RUN apt-get update -qq
RUN apt-get install -y curl
RUN apt-get install -y libjemalloc2
RUN apt-get install -y libvips
RUN apt-get install -y libpq-dev

CMD ["echo", "Whalecome!"]
