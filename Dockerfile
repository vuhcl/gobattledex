ARG PYTHON_VERSION=3.12
ARG UID=1000
ARG GID=1000

FROM python:${PYTHON_VERSION}-slim as base
ARG UID
ARG GID
ENV DEBUG False
ENV PYTHONPATH /app
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
RUN mkdir -p /app /app/mediafiles
RUN echo 'deb http://deb.debian.org/debian/ bookworm main' >> /etc/apt/sources.list \
  && DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  git \
  ca-certificates \
  iptables \
  gosu \
  # cleanup
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
RUN addgroup -gid "${GID}" --system django \
  && adduser -uid "${UID}" -gid "${GID}" --home /home/django --system django
WORKDIR /app


FROM base as py
COPY requirements*.txt ./
RUN python -m pip install --upgrade pip \
  && python -m pip install -r requirements.txt

FROM base as app
COPY --from=py /usr/local /usr/local
COPY manage.py /app
COPY pvpogo_tools /app/pvpogo_tools
COPY templates /app/templates

FROM app as static
ENV DATABASE_URL sqlite://:memory:
COPY --from=py /usr/local /usr/local
COPY static/public /app/static/public
RUN python manage.py collectstatic --noinput --clear --skip-checks --no-default-ignore


FROM base as final
COPY --from=py /usr/local /usr/local
COPY --from=app /app /app
COPY --from=static /app/staticfiles /app/staticfiles
COPY .bin /
RUN chmod +x /release.sh /web.sh /worker.sh \
  && chown -R django:django /app \
  && DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge \
  build-essential \
  curl \
  git \
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*
EXPOSE 8000
