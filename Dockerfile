#####################
### Server Build Step
#####################
FROM golang:1.16.2-buster AS server-builder 

ARG buildnumber=local
ARG TARGETPLATFORM

WORKDIR /server

COPY . .
RUN BUILDNUMBER=${buildnumber} \
    GOARCH="$(echo $TARGETPLATFORM | cut -d '/' -f 2)"  \
    GOARM="$(echo $TARGETPLATFORM | cut -d '/' -f 3 | tail -c 2)" \
    CGO_ENABLED=0 GOOS=linux make build-server

#################
### UI Build Step
#################
FROM node:14-buster AS ui-builder 

WORKDIR /ui

COPY . .
RUN npm ci
RUN make build-ssr
RUN make build-ui

################
### Runtime Step
################
FROM debian:buster-slim

RUN apt-get update
RUN apt-get install -y ca-certificates

WORKDIR /app

COPY --from=server-builder /server/migrations /app/migrations
COPY --from=server-builder /server/views /app/views
COPY --from=server-builder /server/LICENSE /app
COPY --from=server-builder /server/fider /app

COPY --from=ui-builder /ui/favicon.png /app
COPY --from=ui-builder /ui/dist /app/dist
COPY --from=ui-builder /ui/robots.txt /app
COPY --from=ui-builder /ui/ssr.js /app

EXPOSE 3000

HEALTHCHECK --timeout=5s CMD ./fider ping

CMD ./fider migrate && ./fider
