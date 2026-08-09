FROM python:3.14-trixie

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PATH="/bin:${PATH}"

COPY --from=astral/uv:0.12-trixie /usr/local/bin/uv /usr/local/bin/uvx /bin/

SHELL [ "/bin/bash", "-euxo", "pipefail", "-c" ]

WORKDIR /app
