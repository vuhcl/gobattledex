# Dockerfile
# Uses multi-stage builds requiring Docker 17.05 or higher
# See https://docs.docker.com/develop/develop-images/multistage-build/

# Creating a python base with shared environment variables
FROM python:3.12.2-slim as python-base
ENV PYTHONUNBUFFERED=1 \
  PYTHONDONTWRITEBYTECODE=1 \
  PIP_NO_CACHE_DIR=off \
  PIP_DISABLE_PIP_VERSION_CHECK=on \
  PIP_DEFAULT_TIMEOUT=100 \
  POETRY_HOME="/opt/poetry" \
  POETRY_VIRTUALENVS_IN_PROJECT=true \
  POETRY_NO_INTERACTION=1 \
  POETRY_VERSION=1.8.2 \
  PYSETUP_PATH="/opt/pysetup" \
  VENV_PATH="/opt/pysetup/.venv"

ENV PATH="$POETRY_HOME/bin:$VENV_PATH/bin:$PATH"

# builder-base is used to build dependencies
FROM python-base as builder-base
RUN apt-get update \
  && apt-get install --no-install-recommends -y \
  curl \
  libpq-dev \
  build-essential

# Install Poetry - respects $POETRY_VERSION & $POETRY_HOME
RUN curl -sSL 'https://install.python-poetry.org' | POETRY_HOME=${POETRY_HOME} python3 -

# We copy our Python requirements here to cache them
# and install only runtime deps using poetry
WORKDIR $PYSETUP_PATH
COPY ./pyproject.toml .
RUN poetry lock && poetry install --only main --no-root --no-directory

# 'development' stage installs all dev deps and can be used to develop code.
# For example using docker-compose to mount local volume under /app
FROM python-base as development
# Copying poetry and venv into image
COPY --from=builder-base $POETRY_HOME $POETRY_HOME
COPY --from=builder-base $PYSETUP_PATH $PYSETUP_PATH

# Copying in our entrypoint
COPY ./docker/entrypoint /entrypoint
RUN chmod +x /entrypoint

# venv already has runtime deps installed we get a quicker install
WORKDIR $PYSETUP_PATH
RUN poetry install --with dev

WORKDIR /app
COPY . .

EXPOSE 8000
ENTRYPOINT ["/entrypoint"]

FROM python-base as production
RUN addgroup --system django \
  && adduser --system --ingroup django django

COPY --chown=django:django --from=builder-base $VENV_PATH $VENV_PATH
COPY --chown=django:django ./docker/entrypoint /entrypoint
RUN chmod +x /entrypoint

COPY --chown=django:django ./docker/start /start
RUN chmod +x /start

COPY --chown=django:django manage.py /app/
COPY --chown=django:django pvpogo_tools config /app/
USER django
WORKDIR /app
ENTRYPOINT ["/entrypoint"]
CMD ["/start"]
