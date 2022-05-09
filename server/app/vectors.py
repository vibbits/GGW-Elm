from typing import List, Optional
import io
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import deps, schemas, crud
from app.level import VectorLevel
from app.genbank import convert_gbk_to_vector
from app.model import Annotation, Feature, VectorReference

router = APIRouter()


def vector_to_world(vector: schemas.VectorInDB) -> schemas.VectorOut:
    """Returns a vector in the form sent over the wire:
          - replace the sequence by its length

    Args:
        vector: Vector as stored in DB

    Returns:
        schemas.VectorOut: Vector sent over the wire.
    """
    vec_in_db_dict = vector.dict()

    inserts_out = []
    backbone_out = None

    for child in vector.children:
        if child.level == VectorLevel.LEVEL0:
            inserts_out.append(
                schemas.VectorOut(
                    **child.dict(),
                    sequence_length=len(child.sequence),
                    inserts_out=[],
                    backbone_out=None,
                )
            )
        elif child.level == VectorLevel.BACKBONE:
            backbone_out = schemas.VectorOut(
                **child.dict(),
                sequence_length=len(child.sequence),
                inserts_out=[],
                backbone_out=None,
            )

    return schemas.VectorOut(
        **vec_in_db_dict,
        sequence_length=len(vector.sequence),
        inserts_out=inserts_out,
        backbone_out=backbone_out,
    )


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


@router.post("/submit/genbank/", response_model=schemas.VectorOut)
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


@router.post("/submit/vector/", response_model=schemas.VectorOut)
def add_leveln(
    new_vec: schemas.LevelNToAdd,
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> schemas.VectorOut:
    """
    Handles POST requests from the UI specific for Level 1 and higher.


    Raises:
        HTTPException: If the function encounters an error,
        it raises an HTTP Exception:
        HTTP_400_BAD_REQUEST

    Returns:
        schemas.VectorOut: Returns the Vector posted by the UI.
    """
    vec = new_vec.dict()

    del vec["date"]

    # Get Children
    inserts = [
        crud.get_vector_by_name_level_location(
            database=database,
            name=insert.name,
            level=VectorLevel.LEVEL0,
            location=insert.location,
        )
        for insert in new_vec.inserts
    ]
    backbone = crud.get_vector_by_name_level_location(
        database=database,
        name=new_vec.backbone.name,
        level=VectorLevel.BACKBONE,
        location=new_vec.backbone.location,
    )

    children = inserts
    children.append(backbone)

    annotations: List[Annotation] = []
    features: List[Feature] = []
    references: List[VectorReference] = []
    sequences: List[str] = []

    # inserts_out: List[schemas.VectorOut] = []

    total_sequence_length = 0

    for child in children:
        # Get annotations
        annotations = crud.get_annotations_from_vector(
            database=database, vector_id=child.id
        )

        # Get references
        references = crud.get_references_from_vector(
            database=database, vector_id=child.id
        )

        # Get features
        features = crud.get_features_from_vector(database=database, vector_id=child.id)

        # Get sequence information
        sequences.append(child.sequence)
        total_sequence_length = total_sequence_length + len(child.sequence)

    children_in_db: List[schemas.VectorInDB] = [
        schemas.VectorInDB.from_orm(child) for child in children
    ]

    vec_in_db = schemas.VectorInDB(
        **vec,
        users=[current_user],
        gateway_site="",
        vector_type="",
        annotations=annotations,
        features=features,
        references=references,
        sequence="".join(sequences),
        date=datetime.strptime(new_vec.date, "%Y-%M-%d"),
        children=children_in_db,
    )
    inserted = crud.add_vector(database=database, vector=vec_in_db, user=current_user)

    if inserted is not None:
        if len(children) > 0:
            [
                crud.add_vector_hierarchy(
                    database=database, child_id=child.id, parent_id=inserted.id
                )
                for child in children
            ]

        return vector_to_world(schemas.VectorInDB.from_orm(vec_in_db))

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid vector"
    )
