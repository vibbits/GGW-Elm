" GGW HTTP API "

from fastapi import APIRouter

from app import auth, submit, hello

router = APIRouter()
router.include_router(auth.router)
router.include_router(submit.router)
router.include_router(hello.router)
