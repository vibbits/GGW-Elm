from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import deps, schemas, crud

router = APIRouter()


@router.get("/hello", response_model=Optional[schemas.User])
def hello(db: Session = Depends(deps.get_db)):
    return crud.get_user(db, 2)
