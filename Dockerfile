###
### Elixir / Erlang / Alpine versions are pinned in one place so they are
### trivial to bump later. Both stages follow these ARGs.
###
ARG ELIXIR_VERSION=1.20.3
ARG ERLANG_VERSION=29.0.5
ARG ALPINE_VERSION=3.23.5

###
### First Stage - Building the Release
###
FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${ERLANG_VERSION}-alpine-${ALPINE_VERSION} AS build

# install build dependencies
RUN apk add --no-cache build-base git libsodium libsodium-dev

# prepare build dir
WORKDIR /app

# extend hex timeout
ENV HEX_HTTP_TIMEOUT=20

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV as prod
ENV MIX_ENV=prod

# Copy over the mix.exs and mix.lock files to load the dependencies. If those
# files don't change, then we don't keep re-fetching and rebuilding the deps.
COPY mix.exs mix.lock ./
COPY config config

RUN mix deps.get --only prod && \
    mix deps.compile

# copy source
COPY lib lib

# compile and build release
COPY rel rel
RUN mix do compile, release

###
### Second Stage - Setup the Runtime Environment
###

# prepare release docker image
FROM alpine:${ALPINE_VERSION} AS app
RUN apk add --no-cache libstdc++ openssl ncurses-libs libsodium

WORKDIR /app

COPY --from=build /app/_build/prod/rel/quagga ./

# The persistent Baobab spool lives on a fly volume mounted at /data
# (see the [mounts] section of fly.toml). The process runs as root so the
# volume is writable; fly.io isolates each app inside its own Firecracker
# microVM, so this is the standard trade-off for a volume-mounted app.
ENV HOME=/app
ENV MIX_ENV=prod
ENV PORT=8483

CMD ["bin/quagga", "start"]
