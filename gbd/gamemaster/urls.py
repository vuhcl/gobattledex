from __future__ import annotations

from django.urls import path

from gbd.gamemaster.views import latest_view, update

app_name = "gamemaster"
urlpatterns = [
    path("latest/", view=latest_view, name="latest"),
    path("update/", view=update),
]
