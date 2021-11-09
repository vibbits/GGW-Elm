" GGW HTTP API "

from fastapi import APIRouter

from app import auth

router = APIRouter()
router.include_router(auth.router)
