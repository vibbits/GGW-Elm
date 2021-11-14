" GGW HTTP API "

from fastapi import APIRouter

from app import auth, hellow_world

router = APIRouter()
router.include_router(auth.router)
router.include_router(hellow_world.router)
