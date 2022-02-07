" Provides low-level Create, Read, Update, and Delete functions for API resources. "

from typing import List, Optional
from datetime import datetime

from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError

from app import model, schemas

# Users


def get_user(database: Session, user_id: int) -> Optional[model.User]:
    "Read a user from the database."
    return database.query(model.User).filter(model.User.id == user_id).first()


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
    database: Session, vector: schemas.Vector, user: schemas.User
) -> Optional[model.Vector]:
    new_vector = model.Vector(
        mpg_number=vector.mpg_number,
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
        sequence=vector.sequence,
        level=vector.level,
        BsmB1_site=vector.BsmB1_site,
        bsmb1_overhang=vector.bsmb1_overhang,
        gateway_site=vector.gateway_site,
        vector_type=vector.vector_type,
        date=vector.date,
    )
    try:
        database.add(new_vector)
        database.flush()
        database.refresh(new_vector)
        database.add(model.UserVectorMapping(user=user.id, vector=new_vector.id))

        database.add_all(
            [
                model.Annotation(key=ann.key, value=ann.value, vector=new_vector.id)
                for ann in vector.annotations
            ]
        )

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

        database.add_all(
            [
                model.Reference(
                    authors=ref.authors,
                    title=ref.title,
                    vector=new_vector.id,
                )
                for ref in vector.references
            ]
        )

        if vector.level == "LEVEL1":
            database.add_all(
                [
                    model.VectorHierarchy(child=child, parent=new_vector.id)
                    for child in vector.children
                ]
            )

    except SQLAlchemyError as err:
        print(f"Error: {err}")
        database.rollback()
        return None
    else:
        print(f"committed {new_vector}")
        database.commit()
        return new_vector


def get_level0_for_user(database: Session, user: schemas.User) -> List[model.Vector]:
    "Query all vectors from the database that a given user has access to."
    return (
        database.query(model.Vector)
        .filter(model.Vector.users.any(id=user.id), model.Vector.level == 0)
        .all()
    )
