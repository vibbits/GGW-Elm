from typing import List, Optional
import io
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import deps, schemas, crud
from app.level import VectorLevel
from app.genbank import convert_gbk_to_vector

router = APIRouter()


def vector_to_world(vector: schemas.VectorInDB) -> schemas.VectorOut:
    """Returns a vector in the form sent over the wire:
          - replace the sequence by its length

    Args:
        vector: Vector as stored in DB

    Returns:
        schemas.VectorOut: Vector sent over the wire.
    """
    return schemas.VectorOut(**vector.dict(), sequence_length=len(vector.sequence))


@router.get("/vectors/", response_model=List[schemas.VectorOut])
def get_vectors(
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> List[schemas.VectorOut]:
    """Returns all of the vectors accessible by this user."""
    return [
        vector_to_world(schemas.VectorInDB.from_orm(vec))
        for vec in crud.get_vectors_for_user(database=database, user=current_user)
    ]


@router.post("/vectors/", response_model=schemas.VectorOut)
def add_vector(
    new_vec: schemas.VectorToAdd,
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> schemas.VectorOut:
    """Handles POST requests from the UI


    Raises:
        HTTPException: If the function encounters an error,
        it raises an HTTP Exception:
        HTTP_400_BAD_REQUEST

    Returns:
        schemas.VectorOut: Returns the Vector posted by the UI.
    """
    gbk = io.StringIO(new_vec.genbank_content)
    vec = new_vec.dict()

    print(f"New vec: {vec}")

    del vec["date"]
    vec_in_db = schemas.VectorInDB(
        **vec,
        **convert_gbk_to_vector(gbk).dict(),
        children=[],
        users=[],
        gateway_site="",
        vector_type="",
        bsmb1_overhang="",
        date=datetime.strptime(new_vec.date, "%Y-%M-%d"),
    )
    if (
        inserted := crud.add_vector(
            database=database, vector=vec_in_db, user=current_user
        )
    ) is not None:
        return vector_to_world(schemas.VectorInDB.from_orm(inserted))

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid vector"
    )
