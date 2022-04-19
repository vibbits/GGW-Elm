"""
API endpoints for dealing with Golden Gate 2 constructs (vectors).
"""

from typing import List, Optional
import io
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app import deps, schemas, crud
from app.level import VectorLevel
from app.genbank import convert_gbk_to_vector, convert_LevelN_to_genbank
from app.model import Vector

router = APIRouter()


def vector_to_world(vector: Vector) -> schemas.VectorOut:
    """Returns a vector in the form sent over the wire:
          - replace the sequence by its length

    Args:
        vector: Vector as stored in DB

    Returns:
        schemas.VectorOut: Vector sent over the wire.
    """

    inserts_out: List[schemas.VectorOut] = []
    backbone_out: Optional[schemas.VectorOut] = None

    for child in vector.children:
        if child.level == VectorLevel.LEVEL0:
            inserts_out.append(vector_to_world(child))
        elif child.level == VectorLevel.BACKBONE:
            backbone_out = vector_to_world(child)

    return schemas.VectorOut(
        id=vector.id,
        sequence_length=len(vector.sequence),
        children=inserts_out + ([] if backbone_out is None else [backbone_out]),
        annotations=vector.annotations,
        features=vector.features,
        references=vector.references,
        bsmb1_overhang=vector.bsmb1_overhang,
        gateway_site=vector.gateway_site,
        experiment=vector.experiment,
        date=vector.date,
        location=vector.location,
        name=vector.name,
        bsa1_overhang=vector.bsa1_overhang,
        cloning_technique=vector.cloning_technique,
        bacterial_strain=vector.bacterial_strain,
        group=vector.group,
        selection=vector.selection,
        responsible=vector.responsible,
        is_BsmB1_free=vector.is_BsmB1_free,
        notes=vector.notes,
        REase_digest=vector.REase_digest,
        level=vector.level,
    )


@router.get("/vectors/", response_model=List[schemas.VectorOut])
def get_vectors(
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> List[schemas.VectorOut]:
    """Returns all of the vectors accessible by this user."""
    return [
        vector_to_world(vec)
        for vec in crud.get_vectors_for_user(database=database, user=current_user)
    ]


@router.post("/submit/genbank/", response_model=schemas.VectorOut)
def add_vector(
    new_vec: schemas.VectorIn,
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> schemas.VectorOut:
    """
    Submission of building-block vector data (backbones and level 0's)
    where a genbank file defines content (such as sequence).


    Raises:
        HTTPException: If the function encounters an error,
        it raises an HTTP Exception:
        HTTP_400_BAD_REQUEST

    Returns:
        schemas.VectorOut: Returns the Vector posted by the UI.
    """
    gbk = io.StringIO(new_vec.genbank)

    print(f"New vec: {new_vec.dict()}")

    if (
        inserted := crud.add_vector(
            database=database,
            vector=new_vec,
            genbank=convert_gbk_to_vector(gbk, level=new_vec.level),
            user=current_user,
        )
    ) is not None:
        return vector_to_world(inserted)

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid vector"
    )


@router.post("/submit/vector/", response_model=schemas.VectorOut)
def add_leveln(
    new_vec: schemas.VectorIn,
    database: Session = Depends(deps.get_db),
    current_user: schemas.User = Depends(deps.get_current_user),
) -> schemas.VectorOut:
    """
    Submission of vector data to save where the vector is defined in terms of
    lower-order vectors (e.g. level 1 is defined in terms of a backbone + level0's).
    In this case, the user _cannot_ submit a genbank representation so they
    instead submit the building blocks.


    Raises:
        HTTPException: If the function encounters an error,
        it raises an HTTP Exception:
        HTTP_400_BAD_REQUEST

    Returns:
        schemas.VectorOut: Returns the Vector posted by the UI.
    """
    # TODO: It is possible to _incorrectly_ add invalid inserts
    # Get sequence information
    # TODO: We trust the client to submit children in the correct order
    # This should be validated
    features: List[schemas.Feature] = []
    sequence = ""
    for ch_id in new_vec.children:
        if (child := crud.get_vector_by_id(database, ch_id)) is not None:
            sequence += child.sequence
            features += child.features

    genbank = schemas.GenbankData(
        sequence=sequence,
        features=features,
        annotations=new_vec.annotations,
        references=new_vec.references,
    )

    if (
        inserted := crud.add_vector(
            database=database, vector=new_vec, genbank=genbank, user=current_user
        )
    ) is not None:
        return vector_to_world(inserted)

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid vector"
    )


@router.post("/level1/genbank/", response_model=str)
def get_level1_genbank(
    new_vec: schemas.LevelNToAdd,
    database: Session = Depends(deps.get_db),
    # current_user: schemas.User = Depends(deps.get_current_user),
) -> str:
    """
    This function handles a POST request from the UI
    for getting a genbank file of a submitted Level 1.

    - Accepts schemas.LevelNToAdd as input
    - Queries the database for the model.Vector object
    - Parses the model.Vector object to a genbank file
    - Returns a genbank file as a string
    """

    # Get the model.Vector object from the database
    vec_from_db = crud.get_vector_by_name_level_location(
        database=database,
        name=new_vec.name,
        level=new_vec.level,
        location=new_vec.location,
    )

    # Parse the vector, using the genbank.convert_LevelN_to_genbank function
    gbk_str = convert_LevelN_to_genbank(vector=vec_from_db, database=database)

    if gbk_str is not None:
        return gbk_str
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not generate genbank file!",
        )
