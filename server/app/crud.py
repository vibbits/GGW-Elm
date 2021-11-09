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
