"Data schemas for HTTP interface"
# pylint: disable=too-few-public-methods
from __future__ import annotations
from typing import List, Optional, Literal
from datetime import datetime

from pydantic import BaseModel

from app.level import VectorLevel

# Users


class UserBase(BaseModel):
    """
    Base Class for a user
    """

    name: Optional[str]
    role: str = "user"


class UserCreate(UserBase):
    """
    Class to create a user.
    When creating a user we also need the authorization issuer (`iss`),
    and the unique identifier (subject, `sub`) on top of the data from
    `UserBase`.
    """

    iss: str  # Issuer
    sub: str  # Subject


class User(UserBase):
    """
    Class for a user.
    Used when the database `id` (a globally unique id) is required.
    """

    id: int

    class Config:
        """Orm mode configuration"""

        orm_mode = True


# Auth


class AuthorizationResponse(BaseModel):
    """
    Base Class for a Authorization Response when
    using the API
    """

    state: str
    code: str


class Token(BaseModel):
    """
    Base Class for defining a Token.
    The token is also linked to a user.
    """

    access_token: str
    token_type: str
    user: User


class Provider(BaseModel):
    """
    Base Class for defining an OpenID Connect identity provider.
    """

    id: int
    name: str
    issuer: str
    clientid: str
    secret: str

    class Config:
        "pydantic configuration"
        orm_mode = True


class LoginUrl(BaseModel):
    """
    Base Class for defining a LoginUrl
    """

    name: str
    url: str


# Administration


class AllUsers(BaseModel):
    "Listing of all users"
    label: Literal["users"]
    data: List[User]


class AllGroups(BaseModel):
    "Listing of all groups"
    label: Literal["groups"]
    data: List[str]


class AllConstructs(BaseModel):
    "Listing of all constructs"
    label: Literal["constructs"]
    data: List[VectorAdmin]


# Adding data


class VectorReference(BaseModel):
    """
    Base Class for defining a Reference.
    This links the genbank file to the maker.
    """

    authors: str
    title: str

    class Config:
        """Orm mode configuration"""

        orm_mode = True


class Qualifier(BaseModel):
    """
    Base Class for defining qualifiers.
    Qualifiers are descriptive components
    from a genbank file.
    """

    key: str
    value: str

    class Config:
        """Orm mode configuration"""

        orm_mode = True


class Feature(BaseModel):
    """
    Base Class for defining Features.
    The features describe like on a map where certain
    pieces of a construct can be found.

    Features can contain multiple qualifiers to
    provide more information
    """

    type: str
    qualifiers: List[Qualifier]
    start_pos: int
    end_pos: int
    strand: int

    class Config:
        """Orm mode configuration"""

        orm_mode = True


class Annotation(BaseModel):
    """
    Base Class defining an Annotation.
    Annotations are considered as extra
    information for a construct.
    """

    key: str
    value: str

    class Config:
        """Orm mode configuration"""

        orm_mode = True


class GenbankData(BaseModel):
    """
    Data extracted from a genbank file.
    """

    sequence: str
    annotations: List[Annotation]
    features: List[Feature]
    references: List[VectorReference]


class VectorBase(BaseModel):
    """
    Base Class for defining a Vector.
    This class defines common fields that are
    used whether the vector is stored in the
    database, is being sent from the client, or
    is being sent to the client.
    """

    location: int
    name: str
    bsa1_overhang: Optional[str]
    cloning_technique: Optional[str]
    bacterial_strain: str
    group: str
    selection: Optional[str]
    responsible: str
    is_BsmB1_free: Optional[str]
    notes: Optional[str]
    REase_digest: Optional[str]
    level: VectorLevel

    class Config:
        """Orm mode configuration"""

        orm_mode = True


class Vector(VectorBase):
    """
    This class inherits from the VectorBase class.
    This contains additional information shared by
    most Vector classes.
    """

    annotations: List[Annotation]
    references: List[VectorReference]
    bsmb1_overhang: Optional[str]
    gateway_site: str
    experiment: str


class VectorIn(Vector):
    """
    A construct ("vector") as input to the server.
    """

    date: str
    bsmb1_overhang: Optional[str]
    genbank: Optional[str]
    children: List[int]


class VectorOut(Vector):
    """
    A construct ("vector") is used by clients.
    """

    id: int
    sequence_length: int
    children: List[VectorOut]
    date: datetime


class VectorAdmin(VectorOut):
    "Specifically for admin, known list of users"

    users: List[User]


AllConstructs.update_forward_refs()
