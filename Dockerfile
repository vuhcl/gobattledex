# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.12 \
  APP_HOME=/app \
  UID=1000 \
  GID=1000
FROM python:${PYTHON_VERSION}-slim as base
ARG UID \
  GID \
  APP_HOME \
  POETRY_CACHE_DIR \
  POETRY_HOME
ENV DEBUG False \
  PYTHONDONTWRITEBYTECODE 1 \
  PYTHONUNBUFFERED 1 \
  POETRY_VERSION=1.8.2 \
  PIP_NO_CACHE_DIR=1 \
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
  PIP_DEFAULT_TIMEOUT=100 \
  PIP_ROOT_USER_ACTION=ignore \
  # poetry:
  POETRY_NO_INTERACTION=1 \
  POETRY_VIRTUALENVS_CREATE=false

COPY ./poetry.lock ./pyproject.toml /

RUN apt-get update && apt-get install --no-install-recommends -y \
  build-essential \
  curl \
  libpq-dev \
  # Installing `poetry` package manager:
  # https://github.com/python-poetry/poetry
  && curl -sSL 'https://install.python-poetry.org' | python3 - \
  && poetry install --only main --no-root --no-directory \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd -g "${GID}" -r django \
  && useradd -d "${APP_HOME}" -g django -l -r -u "${UID}" django

WORKDIR ${APP_HOME}
COPY --chown=django:django manage.py .
COPY --chown=django:django pvpogo_tools config ./

COPY --chown=django:django ./.bin/entrypoint /entrypoint
RUN sed -i 's/\r$//g' /entrypoint
RUN chmod +x /entrypoint

COPY --chown=django:django ./.bin/start /start
RUN sed -i 's/\r$//g' /start
RUN chmod +x /start

RUN poetry install --only main

USER django
EXPOSE 5000
ENTRYPOINT ["/entrypoint"]
