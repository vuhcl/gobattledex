from __future__ import annotations

import multiprocessing
import re
import socket
import sys
from pathlib import Path

# import django_stubs_ext
import environ
import sentry_sdk
from django.template import base
from sentry_sdk.integrations.django import DjangoIntegration
from sentry_sdk.integrations.logging import LoggingIntegration

from .core.sentry import sentry_profiles_sampler, sentry_traces_sampler

# 0. Setup

BASE_DIR = Path(__file__).resolve(strict=True).parent.parent

env = environ.Env()
env.read_env(Path(BASE_DIR, ".env").as_posix())

# Monkeypatching Django, so stubs will work for all generics,
# see: https://github.com/typeddjango/django-stubs
# django_stubs_ext.monkeypatch()

# Monkeypatching Django templates, to support multiline template tags
# base.tag_re = re.compile(base.tag_re.pattern, re.DOTALL)

# We should strive to only have two possible runtime scenarios: either `DEBUG`
# is True or it is False. `DEBUG` should be only true in development, and
# False when deployed, whether or not it's a production environment.
DEBUG = env.bool("DEBUG", default=False)

# `STAGING` is here to allow us to tweak things like urls, smtp servers, etc.
# between staging and production environments, **NOT** for anything that `DEBUG`
# would be used for.
STAGING = env.bool("STAGING", default=False)

CAPROVER = env.bool("CAPROVER", default=False)

# 1. Django Core Settings
# https://docs.djangoproject.com/en/4.0/ref/settings/

if CAPROVER:
    ALLOWED_HOSTS = env("CAPROVER_HOSTS", default=["localhost"])
else:
    ALLOWED_HOSTS = env.list("ALLOWED_HOSTS", default=[
        "*"] if DEBUG else ["localhost"])


SITE_ID = 1

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

DATABASES = {"default": env.db("DATABASE_URL")}
DATABASES["default"]["ATOMIC_REQUESTS"] = True

DEFAULT_AUTO_FIELD = "django.db.models.AutoField"

DEFAULT_FROM_EMAIL = env(
    "DEFAULT_FROM_EMAIL",
    default="",
)

EMAIL_BACKEND = (
    "django.core.mail.backends.console.EmailBackend"
    if DEBUG
    else "email_relay.backend.RelayDatabaseEmailBackend"
)

FORM_RENDERER = "django.forms.renderers.TemplatesSetting"

INSTALLED_APPS = [
    # First Party
    "pvpogo_tools.core",
    "pvpogo_tools.users",
    # Second Party
    "django_simple_nav",
    "django_q_registry",
    # Third Party
    "allauth",
    "allauth.account",
    "allauth.socialaccount",
    "django_browser_reload",
    "django_extensions",
    "django_htmx",
    # "health_check",
    # "health_check.db",
    # "health_check.cache",
    # "health_check.storage",
    # "health_check.contrib.migrations",
    "heroicons",
    "simple_history",
    "template_partials",
    # Django
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.sites",
    "django.forms",
]
if DEBUG:
    INSTALLED_APPS = [
        "debug_toolbar",
        "whitenoise.runserver_nostatic",
    ] + INSTALLED_APPS

if DEBUG:
    hostname, _, ips = socket.gethostbyname_ex(socket.gethostname())
    INTERNAL_IPS = [ip[: ip.rfind(".")] + ".1" for ip in ips] + [
        "127.0.0.1",
        "10.0.2.2",
    ]

MIGRATION_MODULES = {"sites": "pogo_pvp_tools.contrib.sites.migrations"}

LANGUAGE_CODE = "en-us"

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "plain_console": {
            "format": "%(levelname)s %(message)s",
        },
        "verbose": {
            "format": "%(asctime)s %(name)-12s %(levelname)-8s %(message)s",
        },
    },
    "handlers": {
        "stdout": {
            "class": "logging.StreamHandler",
            "stream": sys.stdout,
            "formatter": "verbose",
        },
    },
    "loggers": {
        "django": {
            "handlers": ["stdout"],
            "level": env("DJANGO_LOG_LEVEL", default="INFO"),
        },
        "pvpogo_tools": {
            "handlers": ["stdout"],
            "level": env("PVPOGO_TOOLS_LOG_LEVEL", default="INFO"),
        },
    },
}

MEDIA_ROOT = Path(BASE_DIR, "mediafiles")

MEDIA_URL = "/mediafiles/"

# https://docs.djangoproject.com/en/dev/topics/http/middleware/
# https://docs.djangoproject.com/en/dev/ref/middleware/#middleware-ordering
MIDDLEWARE = [
    # should be first
    "django.middleware.cache.UpdateCacheMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    # order doesn't matter
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "allauth.account.middleware.AccountMiddleware",
    "simple_history.middleware.HistoryRequestMiddleware",
    "django_htmx.middleware.HtmxMiddleware",
    "django_flyio.middleware.FlyResponseMiddleware",
    "django_browser_reload.middleware.BrowserReloadMiddleware",
    # should be last
    "django.middleware.cache.FetchFromCacheMiddleware",
]
if DEBUG:
    MIDDLEWARE.remove("django.middleware.cache.UpdateCacheMiddleware")
    MIDDLEWARE.remove("django.middleware.cache.FetchFromCacheMiddleware")

    MIDDLEWARE.insert(
        MIDDLEWARE.index("django.middleware.common.CommonMiddleware") + 1,
        "debug_toolbar.middleware.DebugToolbarMiddleware",
    )

ROOT_URLCONF = "pvpogo_tools.urls"

SECRET_KEY = env(
    "SECRET_KEY",
    default="eZPdvuAaLrVY8Kj3DG2QNqJaJc4fPp6iDgYneKN3fkNmqgkcNnoNLkFe3NCRXqW",
)

SECURE_HSTS_INCLUDE_SUBDOMAINS = not DEBUG

SECURE_HSTS_PRELOAD = not DEBUG

# 10 minutes to start with, will increase as HSTS is tested
SECURE_HSTS_SECONDS = 0 if DEBUG else 600

# https://noumenal.es/notes/til/django/csrf-trusted-origins/
# https://fly.io/docs/reference/runtime-environment/#x-forwarded-proto
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

SERVER_EMAIL = env("SERVER_EMAIL", default=DEFAULT_FROM_EMAIL)

SESSION_COOKIE_SECURE = not DEBUG

SITE_ID = 1

STORAGES = {
    "default": {
        "BACKEND": "storages.backends.s3boto3.S3Boto3Storage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}
if DEBUG and not env.bool("USE_S3", default=False):
    STORAGES["default"] = {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    }

# https://nickjanetakis.com/blog/django-4-1-html-templates-are-cached-by-default-with-debug-true
DEFAULT_LOADERS = [
    "django.template.loaders.filesystem.Loader",
    "django.template.loaders.app_directories.Loader",
]

CACHED_LOADERS = [("django.template.loaders.cached.Loader", DEFAULT_LOADERS)]

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [
            Path(BASE_DIR, "templates"),
        ],
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
            "debug": DEBUG,
            "loaders": [
                (
                    "template_partials.loader.Loader",
                    DEFAULT_LOADERS if DEBUG else CACHED_LOADERS,
                )
            ],
        },
    },
]

TIME_ZONE = "America/Los_Angeles"

USE_I18N = False

USE_TZ = True

WSGI_APPLICATION = "pvpogo_tools.wsgi.application"

# 2. Django Contrib Settings

# django.contrib.auth
AUTHENTICATION_BACKENDS = [
    "django.contrib.auth.backends.ModelBackend",
    "allauth.account.auth_backends.AuthenticationBackend",
]
PASSWORD_HASHERS = [
    # https://docs.djangoproject.com/en/dev/topics/auth/passwords/#using-argon2-with-django
    "django.contrib.auth.hashers.Argon2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2SHA1PasswordHasher",
    "django.contrib.auth.hashers.BCryptSHA256PasswordHasher",
]
# https://docs.djangoproject.com/en/dev/ref/settings/#auth-password-validators
AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

AUTH_USER_MODEL = "users.User"

# django.contrib.staticfiles
STATIC_ROOT = BASE_DIR / "staticfiles"

STATIC_URL = "/static/"

STATICFILES_DIRS = [
    BASE_DIR / "static" / "dist",
    BASE_DIR / "static" / "public",
]

# 3. Third Party Settings

# django-allauth
ACCOUNT_AUTHENTICATION_METHOD = "email"

ACCOUNT_DEFAULT_HTTP_PROTOCOL = "http" if DEBUG else "https"

ACCOUNT_EMAIL_REQUIRED = True

ACCOUNT_LOGOUT_REDIRECT_URL = "account_login"

ACCOUNT_SESSION_REMEMBER = True

ACCOUNT_SIGNUP_PASSWORD_ENTER_TWICE = False

ACCOUNT_UNIQUE_EMAIL = True

ACCOUNT_USERNAME_REQUIRED = False

LOGIN_REDIRECT_URL = "index"

# django-debug-toolbar
DEBUG_TOOLBAR_CONFIG = {
    "ROOT_TAG_EXTRA_ATTRS": "hx-preserve",
}

# django-storages
AWS_ACCESS_KEY_ID = env("AWS_ACCESS_KEY_ID", default=None)

AWS_SECRET_ACCESS_KEY = env("AWS_SECRET_ACCESS_KEY", default=None)

AWS_STORAGE_BUCKET_NAME = env("AWS_STORAGE_BUCKET_NAME", default=None)

AWS_S3_ADDRESSING_STYLE = env("AWS_S3_ADDRESSING_STYLE", default="virtual")

AWS_S3_REGION_NAME = env("AWS_S3_REGION_NAME", default=None)

AWS_S3_SIGNATURE_VERSION = env("AWS_S3_SIGNATURE_VERSION", default="s3v4")

# sentry
if not DEBUG or env.bool("ENABLE_SENTRY", default=False):
    sentry_sdk.init(
        dsn=env("SENTRY_DSN", default=None),
        environment=env("SENTRY_ENV", default=None),
        integrations=[
            DjangoIntegration(),
            LoggingIntegration(event_level=None, level=None),
        ],
        traces_sampler=sentry_traces_sampler,
        profiles_sampler=sentry_profiles_sampler,
        send_default_pii=True,
    )

# 4. Project Settings