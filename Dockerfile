ARG PYTHON_VERSION=3.12 \
  UID=1000 \
  GID=1000 \
  POETRY_CACHE_DIR='/var/cache/pypoetry' \
  POETRY_HOME='/usr/local' \
  TINI_VERSION=v0.19.0

FROM python:${PYTHON_VERSION}-slim as base
ARG UID \
  GID \
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

RUN mkdir -p /app /app/mediafiles \
  && echo 'deb http://deb.debian.org/debian/ bookworm main' >> /etc/apt/sources.list \
  && DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  git \
  ca-certificates \
  iptables \
  gosu \
  # cleanup
  && curl -sSL 'https://install.python-poetry.org' | python3 - \
  # Cleaning cache:
  && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
  && apt-get clean -y && rm -rf /var/lib/apt/lists/*
RUN groupadd -g "${GID}" -r django \
  && useradd -d "${APP_HOME}" -g django -l -r -u "${UID}" django \
  && chown django:django -R /app
WORKDIR /app

FROM base as py
COPY poetry.lock pyproject.toml /app/
RUN --mount=type=cache,target="$POETRY_CACHE_DIR" \
  echo "$DJANGO_ENV" \
  # Install deps:
  && poetry run pip install -U pip \
  && poetry install --no-interaction --no-ansi --sync

FROM base as app
COPY --from=py /usr/local /usr/local
COPY manage.py /app
COPY pvpogo_tools /app/pvpogo_tools
COPY templates /app/templates

FROM base as final
COPY --from=py /usr/local /usr/local
COPY --from=app /app /app
COPY .bin /
RUN chmod +x /entrypoint /start /worker.sh \
  && DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge \
  build-essential \
  curl \
  git \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
ENTRYPOINT ["tini", "--", "entrypoint"]
