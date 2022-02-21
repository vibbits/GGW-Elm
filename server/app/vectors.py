from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app import deps, schemas, crud
from app.model import Vector

router = APIRouter()


@router.get("/vectors/level0", response_model=List[schemas.Vector])
def get_vectors(
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> List[Vector]:
    return crud.get_level0_for_user(database=database, user=current_user)


@router.get("/vectors/backbones", response_model=List[schemas.Vector])
def get_backbones(
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> List[Vector]:
    return crud.get_backbones_for_user(database=database, user=current_user)


@router.get("/vectors/level1", response_model=List[schemas.Vector])
def get_level1_constructs(
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> List[Vector]:
    return crud.get_level1_constructs_for_user(database=database, user=current_user)
