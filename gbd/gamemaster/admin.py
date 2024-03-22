from django.contrib import admin
from reversion.admin import VersionAdmin

from .models import GameMaster, Season, SeasonForm


@admin.register(Season)
class SeasonAdmin(admin.ModelAdmin):
    form = SeasonForm
    list_display = ('id', 'name', 'start_date', 'end_date')
    fieldsets = [
        ('id', {'fields': ['id']}),
        ('name', {'fields': ['name']}),
        ('start_date', {'fields': ['start_date']}),
        ('end_date', {'fields': ['end_date']}),
    ]


@admin.register(GameMaster)
class GameMasterAdmin(VersionAdmin):
    list_display = ("timestamp", "last_modified", "revision")
