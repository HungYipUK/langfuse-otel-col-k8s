#!/bin/bash

docker compose \
  --env-file .env \
  up \
  --detach --build

docker compose cp \
  ./otel_config.json cursor-cli:/root/.local/share/opentelemetry-hooks/otel_config.json

docker compose cp \
  ./hooks.json cursor-cli:/root/.cursor/hooks.json

docker compose \
  exec -it cursor-cli \
  /bin/bash

# agent --trust