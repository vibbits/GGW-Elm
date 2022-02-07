" GGW HTTP API "

from fastapi import APIRouter

from app import auth, submit, hello
from app import vectors, backbones

router = APIRouter()
router.include_router(auth.router)
router.include_router(submit.router)
router.include_router(hello.router)
router.include_router(vectors.router)
router.include_router(backbones.router)
