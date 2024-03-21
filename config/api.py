from __future__ import annotations

from ninja import NinjaAPI

from pvpogo_tools.gamemaster.api import router as gm_router

api = NinjaAPI()
api.add_router("/gamemaster/", gm_router)
