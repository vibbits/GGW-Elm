from fastapi import APIRouter, Depends, HTTPException, status

from app import deps

router = APIRouter()


@router.get("/hello")
def hello(user = Depends(deps.get_current_user)):
    return f"Hello {user.name}"
