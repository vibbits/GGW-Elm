"Data schemas for HTTP interface"

from datetime import datetime
import enum
from typing import List, Optional

from pydantic import BaseModel

from app.level import VectorLevel

# Users


class UserBase(BaseModel):
    name: Optional[str]
    role: str = "user"


class UserCreate(UserBase):
    iss: str  # Issuer
    sub: str  # Subject


class User(UserBase):
    id: int

    class Config:
        orm_mode = True


# Auth


class AuthorizationResponse(BaseModel):
    state: str
    code: str


class Token(BaseModel):
    access_token: str
    token_type: str
    user: User


class Provider(BaseModel):
    id: int
    name: str
    issuer: str
    clientid: str
    secret: str

    class Config:
        orm_mode = True


class LoginUrl(BaseModel):
    name: str
    url: str


# Adding data


class Reference(BaseModel):
    authors: str
    title: str

    class Config:
        orm_mode = True


class Qualifier(BaseModel):
    key: str
    value: str

    class Config:
        orm_mode = True


class Feature(BaseModel):
    type: str
    qualifiers: List[Qualifier]
    start_pos: int
    end_pos: int
    strand: int

    class Config:
        orm_mode = True


class Annotation(BaseModel):
    key: str
    value: str

    class Config:
        orm_mode = True


class Vector(BaseModel):
    id: int = 0
    location: int
    name: str
    bsa1_overhang: str
    bsmb1_overhang: str
    cloning_technique: str
    children: List["Vector"]
    bacterial_strain: str
    responsible: str
    group: str
    selection: str
    is_BsmB1_free: str
    notes: str
    REase_digest: str
    annotations: List[Annotation]
    features: List[Feature]
    references: List[Reference]
    users: List[User]
    level: VectorLevel
    gateway_site: str
    vector_type: str
    date: Optional[datetime]


class VectorInDB(Vector):
    sequence: str

    class Config:
        orm_mode = True


class VectorOut(Vector):
    sequence_length: int
