FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime deps INSIDE IMAGE (persistent across container restarts/recreates)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    git \
    ca-certificates \
    bash \
    tini \
  && rm -rf /var/lib/apt/lists/*

# App lives in image (persistent)
RUN mkdir -p /opt/ruvsarpur
RUN git clone --depth 1 https://github.com/sverrirs/ruvsarpur.git /opt/ruvsarpur

# Python env inside mounted /workspace so user data + venv persist
# (venv is created by entrypoint on first run)

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
