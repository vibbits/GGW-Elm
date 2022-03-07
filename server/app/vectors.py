from typing import List, Optional

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app import deps, schemas, crud
from app.model import Vector
from app.level import VectorLevel

router = APIRouter()


def vector_to_world(vector: schemas.VectorInDB) -> schemas.VectorOut:
    return schemas.VectorOut(**vector.dict(), sequence_length=len(vector.sequence))


@router.get("/vectors/", response_model=List[schemas.VectorOut])
def get_vectors(
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> List[schemas.VectorOut]:
    return [
        vector_to_world(schemas.VectorInDB.from_orm(vec))
        for vec in crud.get_vectors_for_user(database=database, user=current_user)
    ]


@router.post("/vectors", response_model=Optional[schemas.VectorInDB])
def add_level0_construct(
    new_vec: schemas.VectorInDB,
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> Optional[Vector]:
    return crud.add_vector(database=database, vector=new_vec, user=current_user)


@router.delete("/vectors/{vector_id}")
def delete_vector(
    vec_id: int,
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
):
    vector = database.get(Vector, vec_id)
