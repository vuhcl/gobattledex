ARG PYTHON_VERSION=3.12 \
  APP_HOME=/app \
  UID=1000 \
  GID=1000 \
  POETRY_CACHE_DIR='/var/cache/pypoetry' \
  POETRY_HOME='/usr/local'

FROM python:${PYTHON_VERSION}-slim as base
ARG UID \
  GID \
  APP_HOME \
  POETRY_CACHE_DIR \
  POETRY_HOME
ENV DEBUG False \
  PYTHONDONTWRITEBYTECODE 1 \
  PYTHONUNBUFFERED 1 \
  POETRY_VERSION=1.8.2

SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

COPY ./poetry.lock ./pyproject.toml /

RUN apt-get update && apt-get install --no-install-recommends -y \
  build-essential \
  curl \
  libpq-dev \
  gettext \
  # Installing `poetry` package manager:
  # https://github.com/python-poetry/poetry
  && curl -sSL 'https://install.python-poetry.org' | POETRY_HOME=${POETRY_HOME} python3 - \
  && poetry install --no-root --no-directory \
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd -g "${GID}" -r django \
  && useradd -d "${APP_HOME}" -g django -l -r -u "${UID}" django

WORKDIR ${APP_HOME}

FROM base as py
ENV PIP_NO_CACHE_DIR=1 \
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
  PIP_DEFAULT_TIMEOUT=100 \
  PIP_ROOT_USER_ACTION=ignore \
  # poetry:
  POETRY_NO_INTERACTION=1 \
  POETRY_VIRTUALENVS_CREATE=false

RUN --mount=type=cache,target="$POETRY_CACHE_DIR" \
  poetry run pip install -U pip \
  && poetry install --without docs --no-interaction --no-ansi --sync

FROM base as app
COPY manage.py .
COPY pvpogo_tools config ${APP_HOME}

FROM py as final
# copy application code to WORKDIR
COPY --chown=django:django --from=app . ${APP_HOME}

COPY --chown=django:django ./.bin/entrypoint /entrypoint
RUN sed -i 's/\r$//g' /entrypoint
RUN chmod +x /entrypoint

COPY --chown=django:django ./.bin/start /start
RUN sed -i 's/\r$//g' /start
RUN chmod +x /start

USER django
EXPOSE 80
ENTRYPOINT ["/entrypoint"]
