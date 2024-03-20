# Creating a python base with shared environment variables
FROM python:3.12.2-slim-bookworm as python-base
ENV PYTHONUNBUFFERED=1 \
  PYTHONDONTWRITEBYTECODE=1 \
  PIP_NO_CACHE_DIR=off \
  PIP_DISABLE_PIP_VERSION_CHECK=on \
  PIP_DEFAULT_TIMEOUT=100 \
  POETRY_VIRTUALENVS_CREATE=false \
  POETRY_NO_INTERACTION=1 \
  POETRY_VERSION=1.8.2 \
  PYSETUP_PATH="/opt/app" \
  VENV_PATH="/opt/app/.venv"

# builder-base is used to build dependencies
FROM python-base as builder-base
WORKDIR $PYSETUP_PATH
RUN apt-get update && apt-get install --no-install-recommends -y \
  build-essential \
  curl \
  libpq-dev \
  && curl -sSL 'https://install.python-poetry.org' | python3 - \
  # Cleaning cache:
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# We copy our Python requirements here to cache them
# and install only runtime deps using poetry
COPY pyproject.toml .
RUN export PATH="/root/.local/bin:$PATH" \
  && poetry lock && poetry install --only main --no-root --no-directory

COPY manage.py .
COPY pvpogo_tools ./pvpogo_tools/
COPY config ./config/

RUN adduser --system --home=$PYSETUP_PATH \
  --no-create-home --disabled-password --group \
  --shell=/bin/bash django

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

RUN python manage.py migrate
ENTRYPOINT ["/entrypoint"]
CMD [ "uvicorn", "config.asgi:application", "--host", "0.0.0.0", "--reload", "--reload-include", "*.html"]

FROM python-base as production
# Copying poetry and venv into image
COPY --from=builder-base $POETRY_HOME $POETRY_HOME
COPY --from=builder-base $PYSETUP_PATH $PYSETUP_PATH
RUN chmod 750 django:django $PYSETUP_PATH

COPY --chown=django:django --from=builder-base docker .
USER django
WORKDIR /app
RUN poetry install --only main
RUN export PYTHONPATH=/etc/$PYSETUP_PATH:/$PYSETUP_PATH
ENTRYPOINT ["/entrypoint"]
CMD ["/start"]
