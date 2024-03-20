from ninja import NinjaAPI

from pogo_pvp_tools.gamemaster.api import router as gm_router

api = NinjaAPI()
api.add_router("/gamemaster/", gm_router)
