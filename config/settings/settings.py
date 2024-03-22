from __future__ import annotations

import multiprocessing
import re
import socket
import sys
from pathlib import Path

import environ

# from sentry_sdk.integrations.django import DjangoIntegration
# from sentry_sdk.integrations.logging import LoggingIntegration

# from .core.sentry import sentry_profiles_sampler
# from .core.sentry import sentry_traces_sampler

# 0. Setup

BASE_DIR = Path(__file__).resolve(strict=True).parent
APPS_DIR = BASE_DIR / "gbd"
env = environ.Env()

READ_DOT_ENV_FILE = env.bool("DJANGO_READ_DOT_ENV_FILE", default=True)
if READ_DOT_ENV_FILE:
    # OS environment variables take precedence over variables from .env
    env.read_env(str(BASE_DIR / ".env"))

SECRET_KEY = env(
    "DJANGO_SECRET_KEY",
    default="eZPdvuAaLrVY8Kj3DG2QNqJaJc4fPp6iDgYneKN3fkNmqgkcNnoNLkFe3NCRXqW",
)

# We should strive to only have two possible runtime scenarios: either `DEBUG`
# is True or it is False. `DEBUG` should be only true in development, and
# False when deployed, whether or not it's a production environment.
DEBUG = env.bool("DEBUG", default=False)

# `STAGING` is here to allow us to tweak things like urls, smtp servers, etc.
# between staging and production environments, **NOT** for anything that
# `DEBUG` would be used for.
STAGING = env.bool("STAGING", default=False)

CAPROVER = env.bool("CAPROVER", default=True)

# 1. Django Core Settings
# https://docs.djangoproject.com/en/4.0/ref/settings/

if CAPROVER:
    ALLOWED_HOSTS = env.list("CAPROVER_HOSTS", default=["localhost"])
else:
    ALLOWED_HOSTS = env.list("ALLOWED_HOSTS", default=["localhost"])

ROOT_URLCONF = "config.urls"

SITE_ID = 1

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

DATABASES = {"default": env.db("DATABASE_URL")}
DATABASES["default"]["ATOMIC_REQUESTS"] = True

DEFAULT_AUTO_FIELD = "django.db.models.AutoField"

FORM_RENDERER = "django.forms.renderers.TemplatesSetting"

INSTALLED_APPS = [
    # First Party
    "gbd.core",
    "gbd.users",
    # Third Party
    "allauth",
    "django_simple_nav",
    "allauth.account",
    "allauth.socialaccount",
    "django_htmx",
    "ninja",
    "corsheaders",
    "sri",
    "reversion",
    # "django_q_registry",
    # "health_check",
    # "health_check.db",
    # "health_check.cache",
    # "health_check.storage",
    # "health_check.contrib.migrations",
    "heroicons",
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
    "django.contrib.flatpages",
]
if DEBUG:
    import django_stubs_ext

    # Monkeypatching Django, so stubs will work for all generics,
    # see: https://github.com/typeddjango/django-stubs
    django_stubs_ext.monkeypatch()

    # Monkeypatching Django templates, to support multiline template tags
    from django.template import base
    base.tag_re = re.compile(base.tag_re.pattern, re.DOTALL)
    INSTALLED_APPS = [
        "debug_toolbar",
        "whitenoise.runserver_nostatic",
        "django_extensions",
        "django_browser_reload",
    ] + INSTALLED_APPS
    hostname, _, ips = socket.gethostbyname_ex(socket.gethostname())
    INTERNAL_IPS = [ip[: ip.rfind(".")] + ".1" for ip in ips] + [
        "127.0.0.1",
        "10.0.2.2",
    ]

MIGRATION_MODULES = {"sites": "gbd.contrib.sites.migrations"}

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
        "gbd": {
            "handlers": ["stdout"],
            "level": env("gbd_LOG_LEVEL", default="INFO"),
        },
    },
}

MEDIA_ROOT = str(APPS_DIR / "media")
# https://docs.djangoproject.com/en/dev/ref/settings/#media-url
MEDIA_URL = "/media/"

# https://docs.djangoproject.com/en/dev/topics/http/middleware/
# https://docs.djangoproject.com/en/dev/ref/middleware/#middleware-ordering
MIDDLEWARE = [
    # should be first
    "django.middleware.cache.UpdateCacheMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    # order doesn't matter
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "allauth.account.middleware.AccountMiddleware",
    "django_htmx.middleware.HtmxMiddleware",
]

# SECURITY
# ------------------------------------------------------------------------------
# https://docs.djangoproject.com/en/dev/ref/settings/#secure-proxy-ssl-header
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
# https://docs.djangoproject.com/en/dev/ref/settings/#secure-ssl-redirect
SECURE_SSL_REDIRECT = env.bool("DJANGO_SECURE_SSL_REDIRECT", default=True)
# https://docs.djangoproject.com/en/dev/ref/settings/#session-cookie-secure
SESSION_COOKIE_SECURE = True
# https://docs.djangoproject.com/en/dev/ref/settings/#csrf-cookie-secure
CSRF_COOKIE_SECURE = True
# https://docs.djangoproject.com/en/dev/topics/security/#ssl-https
# https://docs.djangoproject.com/en/dev/ref/settings/#secure-hsts-seconds
# https://docs.djangoproject.com/en/dev/ref/middleware/#x-content-type-options-nosniff
SECURE_CONTENT_TYPE_NOSNIFF = env.bool(
    "DJANGO_SECURE_CONTENT_TYPE_NOSNIFF",
    default=True,
)


SECURE_HSTS_INCLUDE_SUBDOMAINS = not DEBUG

SECURE_HSTS_PRELOAD = not DEBUG

# 10 minutes to start with, will increase as HSTS is tested
SECURE_HSTS_SECONDS = 60 if DEBUG else 518400

SESSION_COOKIE_HTTPONLY = True
# https://docs.djangoproject.com/en/dev/ref/settings/#csrf-cookie-httponly
CSRF_COOKIE_HTTPONLY = True
# https://docs.djangoproject.com/en/dev/ref/settings/#x-frame-options
X_FRAME_OPTIONS = "DENY"

# https://noumenal.es/notes/til/django/csrf-trusted-origins/
# https://fly.io/docs/reference/runtime-environment/#x-forwarded-proto
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

SESSION_COOKIE_SECURE = not DEBUG

# STATIC & MEDIA
# ------------------------
STORAGES = {
    "default": {
        "BACKEND": "django.core.files.storage.FileSystemStorage",
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
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
        "DIRS": [str(APPS_DIR / "templates")],
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.template.context_processors.media",
                "django.template.context_processors.static",
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
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"}, #noqa E501
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

AUTH_USER_MODEL = "users.User"

# STATIC
# ------------------------------------------------------------------------------
# https://docs.djangoproject.com/en/dev/ref/settings/#static-root
STATIC_ROOT = str(BASE_DIR / "staticfiles")
# https://docs.djangoproject.com/en/dev/ref/settings/#static-url
STATIC_URL = "/static/"
# https://docs.djangoproject.com/en/dev/ref/contrib/staticfiles/#std:setting-STATICFILES_DIRS
STATICFILES_DIRS = [str(APPS_DIR / "static")]
# https://docs.djangoproject.com/en/dev/ref/contrib/staticfiles/#staticfiles-finders
STATICFILES_FINDERS = [
    "django.contrib.staticfiles.finders.FileSystemFinder",
    "django.contrib.staticfiles.finders.AppDirectoriesFinder",
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

# django-compressor
# ------------------------------------------------------------------------------
INSTALLED_APPS += ["compressor"]
STATICFILES_FINDERS += ["compressor.finders.CompressorFinder"]
# https://django-compressor.readthedocs.io/en/latest/settings/#django.conf.settings.COMPRESS_ENABLED
COMPRESS_ENABLED = env.bool("COMPRESS_ENABLED", default=True)
# https://django-compressor.readthedocs.io/en/latest/settings/#django.conf.settings.COMPRESS_STORAGE
COMPRESS_STORAGE = "compressor.storage.GzipCompressorFileStorage"
# https://django-compressor.readthedocs.io/en/latest/settings/#django.conf.settings.COMPRESS_URL
COMPRESS_URL = STATIC_URL
# https://django-compressor.readthedocs.io/en/latest/settings/#django.conf.settings.COMPRESS_OFFLINE
COMPRESS_OFFLINE = True  # Offline compression is required when using Whitenoise
# https://django-compressor.readthedocs.io/en/latest/settings/#django.conf.settings.COMPRESS_FILTERS
COMPRESS_FILTERS = {
    "css": [
        "compressor.filters.css_default.CssAbsoluteFilter",
        "compressor.filters.cssmin.rCSSMinFilter",
    ],
    "js": ["compressor.filters.jsmin.JSMinFilter"],
}
# django-cors-headers - https://github.com/adamchainz/django-cors-headers#setup
CORS_URLS_REGEX = r"^/api/.*$"

# # sentry
# if not DEBUG or env.bool("ENABLE_SENTRY", default=False):
#     sentry_sdk.init(
#         dsn=env("SENTRY_DSN", default=None),
#         environment=env("SENTRY_ENV", default=None),
#         integrations=[
#             DjangoIntegration(),
#             LoggingIntegration(event_level=None, level=None),
#         ],
#         traces_sampler=sentry_traces_sampler,
#         profiles_sampler=sentry_profiles_sampler,
#         send_default_pii=True,
#     )

# 4. Project Settings
ADMIN_URL = "admin/"
# https://docs.djangoproject.com/en/dev/ref/settings/#admins
ADMINS = [("""Vu H. Chu-Le""", "vu@uni.minerva.edu")]
# https://docs.djangoproject.com/en/dev/ref/settings/#managers
MANAGERS = ADMINS


if DEBUG:
    MIDDLEWARE += ["django_browser_reload.middleware.BrowserReloadMiddleware"]
    MIDDLEWARE.remove("django.middleware.cache.UpdateCacheMiddleware")

    MIDDLEWARE.insert(
        MIDDLEWARE.index("django.middleware.common.CommonMiddleware") + 1,
        "debug_toolbar.middleware.DebugToolbarMiddleware",
    )
else:
    # should be last
    MIDDLEWARE.append("django.middleware.cache.FetchFromCacheMiddleware")
