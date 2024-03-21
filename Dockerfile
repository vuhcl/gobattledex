# Creating a python base with shared environment variables
FROM python:3.12.2-slim-bookworm as python-base
ENV PYTHONUNBUFFERED=1 \
  PYTHONDONTWRITEBYTECODE=1 \
  PIP_NO_CACHE_DIR=off \
  PIP_DISABLE_PIP_VERSION_CHECK=on \
  PIP_DEFAULT_TIMEOUT=100 \
  POETRY_VIRTUALENV_IN_PROJECT=1 \
  POETRY_VIRTUALENVS_CREATE=0 \
  POETRY_NO_INTERACTION=1 \
  POETRY_HOME="/opt/app/poetry" \
  POETRY_VERSION=1.8.2 \
  PYSETUP_PATH="/opt/app" \
  POETRY_VIRTUALENVS_PREFER_ACTIVE_PYTHON=1
# We copy our Python requirements here to cache them
# and install only runtime deps using poetry
COPY pyproject.toml .
# builder-base is used to build dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
  build-essential \
  curl \
  libpq-dev \
  && curl -sSL 'https://install.python-poetry.org' | POETRY_HOME=${POETRY_HOME} python3 - \
  && $POETRY_HOME/bin/poetry install --only main --no-root --no-directory \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/*

FROM python-base as builder-base
WORKDIR $PYSETUP_PATH
COPY poetry.lock .
COPY manage.py .
COPY pvpogo_tools ./pvpogo_tools/
COPY config ./config/

# 'development' stage installs all dev deps and can be used to develop code.
# For example using docker-compose to mount local volume under /app
FROM python-base as development
# Copying poetry and venv into image
COPY --from=builder-base $POETRY_HOME $POETRY_HOME
COPY --from=builder-base $PYSETUP_PATH $PYSETUP_PATH
# Copying in our entrypoint
COPY ./docker/entrypoint /entrypoint
RUN chmod +x /entrypoint
COPY ./docker/start-dev /start-dev
RUN chmod +x /start-dev

WORKDIR $PYSETUP_PATH
RUN $POETRY_HOME/bin/poetry install --with dev

ENTRYPOINT ["/entrypoint"]

FROM python-base as production
RUN adduser --system --home=$PYSETUP_PATH \
  --no-create-home --disabled-password --group \
  --shell=/bin/bash django
COPY --from=builder-base $POETRY_HOME $POETRY_HOME
COPY --chown=django:django --chmod=750 --from=builder-base $PYSETUP_PATH $PYSETUP_PATH
COPY --chown=django:django docker/entrypoint /entrypoint
RUN chmod +x /entrypoint
COPY --chown=django:django docker/entrypoint /start
RUN chmod +x /start

RUN $POETRY_HOME/bin/poetry install --only main --no-cache

USER django
WORKDIR $PYSETUP_PATH
RUN export PYTHONPATH=/etc/$PYSETUP_PATH:/$PYSETUP_PATH
ENTRYPOINT [ "/entrypoint" ]
