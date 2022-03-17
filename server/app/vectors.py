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
    """Returns a vector readable by the UI

    Args:
        vector (schemas.VectorInDB): Vector as stored in DB

    Returns:
        schemas.VectorOut: Vector readable by UI
    """
    return schemas.VectorOut(**vector.dict(), sequence_length=len(vector.sequence))


@router.get("/vectors/", response_model=List[schemas.VectorOut])
def get_vectors(
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> List[schemas.VectorOut]:
    """Processes GET request from the UI

    Args:
        database (Session, optional): Database Session.
        Defaults to Depends(deps.get_db).
        current_user (schemas.User, optional): User from UI.
        Defaults to Depends(deps.get_current_user).

    Returns:
        List[schemas.VectorOut]: List of Vectors readable for the UI.
    """
    return [
        vector_to_world(schemas.VectorInDB.from_orm(vec))
        for vec in crud.get_vectors_for_user(database=database, user=current_user)
    ]


@router.post("/vectors/", response_model=schemas.VectorOut)
def add_level0_construct(
    new_vec: schemas.VectorToAdd,
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> schemas.VectorOut:
    """Handles POST requests from the UI

    Args:
        new_vec (schemas.VectorToAdd):
        A Vector object when posted from UI.
        database (Session, optional): Database Session.
        Defaults to Depends(deps.get_db).
        current_user (schemas.User, optional): Current User.
        Defaults to Depends(deps.get_current_user).

    Raises:
        HTTPException: If the function encounters an error,
        it raises an HTTP Exception:
        HTTP_400_BAD_REQUEST

    Returns:
        schemas.VectorOut: Returns the Vector posted by the UI.
    """
    gbk = io.StringIO(new_vec.genbank_content)
    vec = new_vec.dict()
    del vec["date"]
    lvl0 = schemas.VectorInDB(
        **vec,
        **convert_gbk_to_vector(gbk).dict(),
        children=[],
        users=[],
        level=VectorLevel.LEVEL0,
        gateway_site="",
        vector_type="",
        bsmb1_overhang="",
        date=datetime.strptime(new_vec.date, "%Y-%M-%d"),
    )
    if (
        inserted := crud.add_vector(database=database, vector=lvl0, user=current_user)
    ) is not None:
        return vector_to_world(schemas.VectorInDB.from_orm(inserted))

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid vector"
    )
