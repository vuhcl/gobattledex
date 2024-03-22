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
  POETRY_VIRTUALENVS_CREATE=false \
  POETRY_CACHE_DIR="var/cache/pypoetry" \
  PYSETUP_PATH="/opt/app"
ENV PATH="$PYSETUP_PATH/bin:$PATH"
RUN apt-get update && apt-get upgrade -y \
  && apt-get install --no-install-recommends -y \
  bash \
  build-essential \
  curl \
  libpq-dev \
  && curl -sSL 'https://install.python-poetry.org' | POETRY_HOME=${PYSETUP_PATH} python3 - \
  && poetry install --only main --no-root --no-directory --sync \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/*

FROM python-base as builder-base
RUN groupadd -g "${GID}" -r django \
  && useradd -d "$PYSETUP_PATH" -g django -l -r -u "${UID}" django \
  && chown django:django -R "$PYSETUP_PATH" \
  # Static and media files:
  && mkdir -p '/var/www/django/static' '/var/www/django/media' \
  && chown django:django '/var/www/django/static' '/var/www/django/media'
WORKDIR $PYSETUP_PATH
# Copy only requirements, to cache them in docker layer
COPY --chown=django:django poetry.lock pyproject.toml $PYSETUP_PATH/
COPY manage.py $PYSETUP_PATH
COPY gbd $PYSETUP_PATH/gbd/
COPY config $PYSETUP_PATH/config/

# 'development' stage installs all dev deps and can be used to develop code.
# For example using docker-compose to mount local volume under /app
FROM python-base as development
ENV DJANGO_ENV='development'
# Copying poetry and venv into image
COPY --from=builder-base $PYSETUP_PATH $PYSETUP_PATH/
WORKDIR $PYSETUP_PATH
RUN --mount=type=cache,target="$POETRY_CACHE_DIR" \
  poetry run pip install -U pip \
  && poetry install --only dev
ENTRYPOINT [ "uvicorn", "config.asgi", "--reload"]

FROM python-base as production
ENV DJANGO_ENV='production'
COPY --from=builder-base $PYSETUP_PATH $PYSETUP_PATH
COPY --chown=django:django docker/start /start
RUN chmod +x /start
WORKDIR $PYSETUP_PATH
RUN --mount=type=cache,target="$POETRY_CACHE_DIR" \
  poetry run pip install -U pip \
  && poetry install --only main --sync \
  && apt-get remove -y --purge \
  build-essential \
  curl \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

FROM production as final
ENV PATH="/opt/venv/bin:$PATH"
COPY --chown=django:django . $PYSETUP_PATH
USER django
ENTRYPOINT [ "/start" ]
