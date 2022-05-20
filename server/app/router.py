" GGW HTTP API "

from fastapi import APIRouter

from app import auth, hello
from app import vectors
from app import admin

router = APIRouter()
router.include_router(auth.router)
router.include_router(hello.router)
router.include_router(vectors.router)
router.include_router(admin.router)
