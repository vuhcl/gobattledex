# Creating a python base with shared environment variables
FROM python:3.12.2-slim-bookworm as python-base
ARG DJANGO_ENV \
  UID=1000 \
  GID=1000
ENV PYTHONUNBUFFERED=1 \
  PYTHONDONTWRITEBYTECODE=1 \
  PIP_NO_CACHE_DIR=1 \
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
  PIP_DEFAULT_TIMEOUT=100 \
  PIP_ROOT_USER_ACTION=ignore \
  # poetry:
  POETRY_NO_INTERACTION=1 \
  POETRY_VIRTUALENVS_CREATE=0 \
  POETRY_HOME="/usr/local" \
  PYSETUP_PATH="/opt/app"
RUN apt-get update && apt-get install --no-install-recommends -y \
  build-essential \
  curl \
  libpq-dev \
  && curl -sSL 'https://install.python-poetry.org' | POETRY_HOME=${POETRY_HOME} python - \
  && poetry --version \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/*
WORKDIR ${PYSETUP_PATH}

RUN groupadd -g "${GID}" -r django \
  && useradd -d "$PYSETUP_PATH" -g django -l -r -u "${UID}" django \
  && chown django:django -R "$PYSETUP_PATH" \
  # Static and media files:
  && mkdir -p '/var/www/django/static' '/var/www/django/media' \
  && chown django:django '/var/www/django/static' '/var/www/django/media'
COPY --chown=django:django poetry.lock pyproject.toml $PYSETUP_PATH/

FROM python-base as development
# 'development' stage installs all dev deps and can be used to develop code.
# For example using docker compose to mount local volume
ENV DJANGO_ENV='development'
# Copy only requirements, to cache them in docker layer
RUN poetry run pip install -U pip \
  && poetry install --with dev
ENTRYPOINT [ "uvicorn", "config.asgi", "--reload"]

FROM python-base as production
ENV DJANGO_ENV='production'
COPY --chown=django:django . $PYSETUP_PATH
RUN poetry run pip install -U pip \
  && poetry install --only main --sync \
  && apt-get remove -y --purge \
  build-essential \
  curl \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
USER django
COPY --chown=django:django docker/start /start
RUN chmod +x /start
ENTRYPOINT [ "/start" ]
