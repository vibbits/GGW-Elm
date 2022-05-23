" Provides low-level Create, Read, Update, and Delete functions for API resources. "

from statistics import mode
from typing import List, Optional
from datetime import datetime

from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from app import model, schemas
from app.level import VectorLevel

# Users


def get_user(database: Session, user_id: int) -> Optional[model.User]:
    "Read a user from the database."
    return database.query(model.User).filter(model.User.id == user_id).first()


def get_users(database: Session, offset: int = 0, limit: int = 10) -> List[model.User]:
    "Get all users with pagination"
    return database.query(model.User).offset(offset).limit(limit).all()


def is_admin(user: model.User) -> bool:
    "Check if a user is an admin."
    return user.role == "admin"


def get_user_by_identity(
    database: Session, issuer: str, subject: str
) -> Optional[model.User]:
    "Get a user with a specific issuer and subject."
    return (
        database.query(model.User)
        .filter(model.User.iss == issuer, model.User.sub == subject)
        .first()
    )


def create_user(database: Session, user: schemas.UserCreate) -> model.User:
    "Create a new user."
    new_user = model.User(**user.dict(), created=datetime.now())

    try:
        database.add(new_user)
    except SQLAlchemyError:
        database.rollback()
        raise
    else:
        database.commit()

    database.refresh(new_user)
    return new_user


def get_groups(database: Session, offset: int = 0, limit: int = 10):
    return (
        database.query(model.Vector.group).distinct().offset(offset).limit(limit).all()
    )


# Auth


def get_identity_providers(database: Session) -> List[model.IdentityProvider]:
    "Get all available identity providers."
    return database.query(model.IdentityProvider).all()


def get_provider_by_id(
    database: Session, provider_id: Optional[int]
) -> Optional[model.IdentityProvider]:
    "Get an identity provider given an identifier."
    if provider_id is None:
        return None

    return (
        database.query(model.IdentityProvider)
        .filter(model.IdentityProvider.id == provider_id)
        .first()
    )


# Vectors


def add_vector(
    database: Session, vector: schemas.VectorInDB, user: schemas.User
) -> Optional[model.Vector]:
    new_vector = model.Vector(
        location=vector.location,
        name=vector.name,
        bacterial_strain=vector.bacterial_strain,
        responsible=vector.responsible,
        group=vector.group,
        bsa1_overhang=vector.bsa1_overhang,
        selection=vector.selection,
        cloning_technique=vector.cloning_technique,
        is_BsmB1_free=vector.is_BsmB1_free,
        notes=vector.notes,
        REase_digest=vector.REase_digest,
        level=vector.level,
        bsmb1_overhang=vector.bsmb1_overhang,
        gateway_site=vector.gateway_site,
        vector_type=vector.vector_type,
        date=vector.date,
        sequence=vector.sequence,
        genbank=vector.genbank,
    )
    try:
        database.add(new_vector)
        database.flush()
        database.refresh(new_vector)

        # Adding the User-Vector Mapping to the database
        database.add(model.UserVectorMapping(user=user.id, vector=new_vector.id))

        # Adding the annotations to the database
        database.add_all(
            [
                model.Annotation(key=ann.key, value=ann.value, vector=new_vector.id)
                for ann in vector.annotations
            ]
        )

        # Adding the features and qualifiers to the database
        for feat in vector.features:
            new_feature = model.Feature(
                type=feat.type,
                start_pos=feat.start_pos,
                end_pos=feat.end_pos,
                strand=feat.strand,
                vector=new_vector.id,
            )
            database.add(new_feature)
            database.flush()
            database.refresh(new_feature)

            database.add_all(
                [
                    model.Qualifier(
                        key=qual.key, value=qual.value, feature=new_feature.id
                    )
                    for qual in feat.qualifiers
                ]
            )
        # Adding the references to the database
        database.add_all(
            [
                model.VectorReference(
                    authors=ref.authors,
                    title=ref.title,
                    vector=new_vector.id,
                )
                for ref in vector.references
            ]
        )

    except SQLAlchemyError as err:
        print(f"Error: {err}")
        database.rollback()
        return None
    else:
        database.commit()
        return new_vector


def add_vector_hierarchy(database: Session, child_id: int, parent_id: int):
    "Provides the relationship between children and parents"
    database.add(model.VectorHierarchy(child=child_id, parent=parent_id))
    database.flush()
    database.commit()


def get_vectors_for_user(database: Session, user: schemas.User) -> List[model.Vector]:
    "Query all Vector from the database that a given user has access to."
    return database.query(model.Vector).filter(model.Vector.users.any(id=user.id)).all()


def get_all_vectors(
    database: Session, offset: int = 0, limit: int = 0
) -> List[model.Vector]:
    """
    Returns every vector in the Vectors table (necessary for adding child-parent relations)
    Should only be used for importing the Level 1 elements from genbank files and csv!
    """
    return database.query(model.Vector).offset(offset).limit(limit).all()


def get_vector_by_id(database: Session, ids: List[int]) -> List[model.Vector]:
    """
    Retuns a list of vectors based on query on the vector ID's.
    """
    return database.query(model.Vector).filter(id in ids).all()


def get_vector_by_name_level_location(
    database: Session, name: str, level: VectorLevel, location: int
) -> model.Vector:
    """
    Returns a model.Vector object based on a query on:
    - name
    - VectorLevel
    - location

    This should return a single unique Vector
    """
    return (
        database.query(model.Vector)
        .filter(
            model.Vector.name == name,
            model.Vector.level == level,
            model.Vector.location == location,
        )
        .first()
    )


def get_annotations_from_vector(
    database: Session, vector_id: int
) -> List[model.Annotation]:
    return (
        database.query(model.Annotation)
        .filter(model.Annotation.vector == vector_id)
        .all()
    )


def get_references_from_vector(
    database: Session, vector_id: int
) -> List[model.VectorReference]:
    return (
        database.query(model.VectorReference)
        .filter(model.VectorReference.vector == vector_id)
        .all()
    )


def get_features_from_vector(database: Session, vector_id: int) -> List[model.Feature]:
    return database.query(model.Feature).filter(model.Feature.vector == vector_id).all()


def get_qualifiers_from_feature(
    database: Session, feature_id: int
) -> List[model.Qualifier]:
    return (
        database.query(model.Qualifier)
        .filter(model.Qualifier.feature == feature_id)
        .all()
    )
