ARG APP_HOME='/app' \
  POETRY_CACHE_DIR='/var/cache/pypoetry' \
  POETRY_HOME='/usr/local'

FROM python:3.12.2-slim-bookworm as base
ARG UID=${UID} \
  GID=${GID} \
  APP_HOME=${APP_HOME} \
  POETRY_CACHE_DIR=${POETRY_CACHE_DIR} \
  POETRY_HOME=${POETRY_HOME}

# Set environment variables:
ENV DEBUG False \
  PYTHONDONTWRITEBYTECODE 1 \
  PYTHONUNBUFFERED 1\
  # pip:
  PIP_NO_CACHE_DIR=1 \
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
  PIP_DEFAULT_TIMEOUT=100 \
  PIP_ROOT_USER_ACTION=ignore \
  # poetry:
  POETRY_VERSION=1.8.2 \
  POETRY_NO_INTERACTION=1 \
  POETRY_VIRTUALENVS_CREATE=false

RUN apt-get update && apt-get install --no-install-recommends -y \
  build-essential \
  curl \
  libpq-dev \
  # Installing `poetry` package manager:
  # https://github.com/python-poetry/poetry
  && curl -sSL 'https://install.python-poetry.org' | POETRY_HOME=${POETRY_HOME} python3 - \
  # Cleaning cache:
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/*

WORKDIR ${APP_HOME}

FROM base as app

COPY poetry.lock pyproject.toml ${APP_HOME}/
COPY manage.py pvpogo_tools/ ${APP_HOME}/
COPY templates/ /app/templates/

FROM base as final
RUN addgroup --system django \
  && adduser --system --ingroup django django
COPY --from=app /app ${APP_HOME}
COPY ./.bin .
RUN --mount=type=cache,target="$POETRY_CACHE_DIR" \
  # Install deps:
  poetry run pip install -U pip \
  && poetry install --no-interaction --no-ansi --sync
RUN chmod +x /entrypoint /start /worker.sh \
  && chown -R django:django /app
ENTRYPOINT ["/entrypoint"]
