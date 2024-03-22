from __future__ import annotations

import contextlib

from django.apps import AppConfig


class GamemasterConfig(AppConfig):
    name = "gbd.gamemaster"
    verbose_name = "GameMaster"

    def ready(self):
        with contextlib.suppress(ImportError):
            from . import signals  # noqa
