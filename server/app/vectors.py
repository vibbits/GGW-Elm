from ast import Str
from tokenize import String
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import deps, schemas, crud
from app.model import Vector

router = APIRouter()


@router.get("/vectors/level0", response_model=List[schemas.Vector])
def get_vectors(
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> List[Vector]:
    v_list = crud.get_level0_for_user(database=database, user=current_user)
    print("#" * 80)
    print("Returning these vectors:")
    [print(v) for v in v_list]
    print("#" * 80)

    return v_list
