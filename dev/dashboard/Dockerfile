FROM node:22-alpine

# docker-cli-compose: `docker compose` for instance.sh (get_compose_cmd); curl for wait_for_url on host CLI
RUN apk add --no-cache bash docker-cli docker-cli-compose curl

# Runtime: compose mounts the repo at /znuny-dev — server + public UI files are read from the host (no COPY).
WORKDIR /znuny-dev

EXPOSE 3000

ENV NODE_ENV=production
ENV PORT=3000

CMD ["node", "dev/dashboard/server.mjs"]
