from __future__ import annotations

from django.shortcuts import get_object_or_404
from ninja import Router, Schema

from gbd.gamemaster.models import GameMaster

router = Router()


class GameMasterOut(Schema):
    timestamp: int
    raw_content: str

@router.get("/gamemaster/{timestamp}")
def get_gamemaster(request, timestamp: int):
    return get_object_or_404(GameMaster, timestamp=timestamp)
