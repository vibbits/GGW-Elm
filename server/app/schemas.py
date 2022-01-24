"Data schemas for HTTP interface"

from typing import List, Optional

from pydantic import BaseModel

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
        from_orm = True


class Qualifier(BaseModel):
    key: str
    value: str

    class Config:
        from_orm = True


class Feature(BaseModel):
    type: str
    qualifiers: List[Qualifier]
    start_pos: int
    end_pos: int
    strand: int

    class Config:
        from_orm = True


class Annotation(BaseModel):
    key: str
    value: str

    class Config:
        from_orm = True


class Vector(BaseModel):
    id: int = 0
    name: str
    bacterial_strain: str
    responsible: str
    group: str
    bsa1_overhang: str
    selection: str
    cloning_technique: str
    is_BsmB1_free: str
    notes: str
    REase_digest: str
    sequence: str
    annotations: List[Annotation]
    features: List[Feature]
    references: List[Reference]
    children: List["Vector"]
    level: int
    BsmB1_site: Optional[str]
    gateway_site: Optional[str]

    class Config:
        orm_mode = True
