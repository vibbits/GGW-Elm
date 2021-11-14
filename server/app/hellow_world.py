from fastapi import APIRouter, Depends, HTTPException, status
from app import deps

router = APIRouter()

@router.get("/hello")
def hello_world(user=Depends(deps.get_current_user())):
    return "Hello World!"

