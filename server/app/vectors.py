from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import deps, schemas, crud

router = APIRouter()


@router.get("/vectors/level0", response_model=List[schemas.Vector])
def get_vectors():
    pass
