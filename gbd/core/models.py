from __future__ import annotations

import datetime
from time import time_ns

from django.db import models


class Timestampable(models.Model):
    timestamp = models.BigIntegerField(
        unique=True, editable=False, primary_key=True)
    last_modified = models.BigIntegerField()

    class Meta:
        abstract = True
        get_latest_by = "timestamp"

    def save(self, *args, **kwargs):
        self.last_modified = time_ns()
        super().save(*args, **kwargs)


class Status(models.Model):
    status = models.BooleanField(default=True)
    from_date = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True

    @property
    def is_current(self):
        return datetime.datetime.now(tz=datetime.UTC).date() > self.from_date

    @property
    def is_active(self):
        return self.status == self.is_current
