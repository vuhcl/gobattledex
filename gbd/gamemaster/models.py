import orjson
from django.db import models
from django.forms import ModelForm
from django.utils.translation import gettext_lazy as _
from reversion.models import Revision

from gbd.core.models import Status, Timestampable


# Create your models here.
class Season(Status):
    id = models.PositiveSmallIntegerField(_("ID"), primary_key=True)
    name = models.CharField(_("Name"), max_length=255)
    start_date = models.DateField(_("Start date"))
    end_date = models.DateField(_("End date"))

    def __str__(self):
        return f"{self.verbose_name}"

    class Meta:
        verbose_name = _("Season")


class GameMaster(Timestampable):
    raw_content = models.JSONField(_("Gamemaster file content"),
                                   encoder=orjson.dumps,
                                   decoder=orjson.loads)
    revision = models.OneToOneField(
        Revision, verbose_name=_("Revision"), on_delete=models.CASCADE)

    class Meta(Timestampable.Meta):
        verbose_name = _("Gamemaster")


class SeasonForm(ModelForm):
    class Meta:
        model = Season
        fields = ["id", "name", "start_date", "end_date"]
        model = Season
        fields = ["id", "name", "start_date", "end_date"]
        model = Season
        fields = ["id", "name", "start_date", "end_date"]
