ARG PYTHON_VERSION=3.12 \
  APP_HOME=/app \
  UID=1000 \
  GID=1000 \
  POETRY_CACHE_DIR='/var/cache/pypoetry' \
  POETRY_HOME='/usr/local' \
  TINI_VERSION=v0.19.0

FROM python:${PYTHON_VERSION}-slim-bookworm as base
ARG UID \
  GID \
  APP_HOME \
  POETRY_CACHE_DIR \
  POETRY_HOME \
  TINI_VERSION
ENV DEBUG False \
  PYTHONPATH /app \
  PYTHONDONTWRITEBYTECODE 1 \
  PYTHONUNBUFFERED 1\
  # poetry:
  POETRY_VERSION=1.8.2 \
  POETRY_NO_INTERACTION=1 \
  POETRY_VIRTUALENVS_CREATE=false

ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini

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

COPY pyproject.toml poetry.lock /

FROM base as app
COPY manage.py pvpogo_tools /app/
COPY templates /app/templates/

FROM base as final
WORKDIR ${APP_HOME}
RUN groupadd -g "${GID}" -r django \
  && useradd -d "${APP_HOME}" -g django -l -r -u "${UID}" django \
  && chown django:django -R "${APP_HOME}"
COPY --from=app /app /app
RUN --mount=type=cache,target="$POETRY_CACHE_DIR" \
  # Install deps:
  poetry run pip install -U pip \
  && poetry install --no-interaction --no-ansi --sync
COPY .bin /
RUN chmod +x /entrypoint /start /worker.sh \
  && chown -R django:django /app
ENTRYPOINT ["/tini", "--", "/entrypoint"]
