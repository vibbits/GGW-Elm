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


@router.post("/vectors/", response_model=Optional[schemas.VectorOut])
def add_level0_construct(
    new_vec: schemas.VectorToAdd,
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> Optional[schemas.VectorOut]:
    gbk = io.StringIO(new_vec.genbank_content)
    new_vec.date = datetime.strptime(new_vec.date, "%Y-%M-%d")
    lvl0 = schemas.VectorInDB(
        **new_vec.dict(),
        **convert_gbk_to_vector(gbk).dict(),
        children=[],
        users=[],
        level=VectorLevel.LEVEL0,
        gateway_site="",
        vector_type="",
        bsmb1_overhang="",
    )
    if (
        inserted := crud.add_vector(database=database, vector=lvl0, user=current_user)
    ) is not None:
        return vector_to_world(schemas.VectorInDB.from_orm(inserted))

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid vector"
    )


@router.delete("/vectors/{vector_id}")
def delete_vector(
    vec_id: int,
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
):
    # vector = database.get(Vector, vec_id)
    pass
