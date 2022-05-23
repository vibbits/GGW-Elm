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
    data: List[VectorBase]


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


class VectorBase(BaseModel):
    """
    Base Class for defining a Vector.
    This class defines common fields that are
    used whether the vector is stored in the
    database, is being sent from the client, or
    is being sent to the client.
    """

    id: int
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


class VectorFromGenbank(BaseModel):
    """
    Base Class for defining a Vector.
    This class contains all the vector information
    that is read from a genbank file.
    """

    sequence: str
    annotations: List[Annotation]
    features: List[Feature]
    references: List[VectorReference]


class Vector(VectorBase):
    """
    This class inherits from the VectorBase class.
    This contains additional information shared by
    most Vector classes.
    """

    annotations: List[Annotation]
    features: List[Feature]
    references: List[VectorReference]
    bsmb1_overhang: Optional[str]
    users: List[User]
    gateway_site: str
    vector_type: str
    date: Optional[datetime]


class VectorInDB(Vector):
    """
    It contains all the necessary information for
    a Vector object when it is stored in the database.
    """

    children: List[VectorInDB]
    sequence: str
    genbank: str


class VectorToAdd(VectorBase):
    """
    It contains supplemental information provided
    when a new vector is posted to the database.
    The client sends a string that must be converted into
    a Python datetime object along with unparsed genbank
    data.
    """

    date: str
    genbank_content: Optional[str]
    bsmb1_overhang: Optional[str]


class VectorOut(Vector):
    """
    It contains all the necessary information for
    a Vector object when it is queried from the database.
    Not that the `sequence` is **NOT** sent, but instead
    is replaced by just the `sequence_length`. This is because
    the sequence is not used by the client but the length is
    so we save bytes over the wire.
    """

    inserts_out: List[VectorOut]
    backbone_out: Optional[
        VectorOut
    ]  # Should be optional because bacbones don't have a backbone
    sequence_length: int


class LevelNToAdd(VectorBase):
    """
    This schema represents the information received from the UI when
    making a level 1 construct.
    """

    bsmb1_overhang: Optional[str]
    inserts: List[VectorToAdd]
    backbone: VectorToAdd
    date: str


AllConstructs.update_forward_refs()
