FROM erlang:28.2-alpine AS build

RUN apk add --no-cache make gcc musl-dev
COPY --from=ghcr.io/gleam-lang/gleam:v1.15.2-erlang-alpine /bin/gleam /bin/gleam
COPY . /app/
RUN cd /app && gleam export erlang-shipment

FROM erlang:28.2-alpine
RUN \
  addgroup --system webapp && \
  adduser --system webapp -g webapp
USER webapp
COPY --from=build /app/build/erlang-shipment /app
WORKDIR /app
ENV ERL_AFLAGS="-proto_dist inet6_tcp"
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
