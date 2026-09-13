FROM python:3.14-slim@sha256:cad9a2c871761c413caa6fdd6441c783451e740a48aaeba60ae62a8b53525ef6

COPY --from=ghcr.io/astral-sh/uv:latest@sha256:b485bd65cc2cf1c9a93b3554012c9c3778cf7b1b5fd3d3096ce9e1226c97e1e6 /uv /uvx /bin/

WORKDIR /app

# Install dependencies (cached layer)
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

# Copy source code
COPY . .

ENV KAFKA_ENV=local

CMD ["uv", "run", "--no-dev", "python", "data_generator.py"]
