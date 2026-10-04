FROM oven/bun:1.4

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_ENV=development
ENV PATH="/bin:${PATH}"

COPY --from=infisical/cli:latest /bin/infisical /bin

SHELL [ "/bin/bash", "-euxo", "pipefail", "-c" ]

WORKDIR /app
