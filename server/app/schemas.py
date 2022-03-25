"Data schemas for HTTP interface"
# pylint: disable=too-few-public-methods
from datetime import datetime
import enum
from typing import List, Optional

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
        orm_mode = True


class LoginUrl(BaseModel):
    """
    Base Class for defining a LoginUrl
    """

    name: str
    url: str


# Adding data


class Reference(BaseModel):
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

    location: int
    name: str
    bsa1_overhang: str
    cloning_technique: str
    bacterial_strain: str
    group: str
    selection: str
    responsible: str
    is_BsmB1_free: Optional[str]
    notes: str
    REase_digest: str


class VectorFromGenbank(BaseModel):
    """
    Base Class for defining a Vector.
    This class contains all the vector information
    that is read from a genbank file.
    """

    sequence: str
    annotations: List[Annotation]
    features: List[Feature]
    references: List[Reference]


class Vector(VectorBase):
    """
    This class inherits from the VectorBase class.
    This contains additional information shared by
    most Vector classes.
    """

    id: int = 0
    children: List["Vector"]
    annotations: List[Annotation]
    features: List[Feature]
    references: List[Reference]
    bsmb1_overhang: str
    users: List[User]
    level: VectorLevel
    gateway_site: str
    vector_type: str
    date: Optional[datetime]


class VectorInDB(Vector):
    """
    It contains all the necessary information for
    a Vector object when it is stored in the database.
    """

    sequence: str

    class Config:
        """Orm mode configuration"""

        orm_mode = True


class VectorToAdd(VectorBase):
    """
    It contains supplemental information provided
    when a new vector is posted to the database.
    The client sends a string that must be converted into
    a Python datetime object along with unparsed genbank
    data.
    """

    date: str
    genbank_content: str


class VectorOut(Vector):
    """
    It contains all the necessary information for
    a Vector object when it is queried from the database.
    Not that the `sequence` is **NOT** sent, but instead
    is replaced by just the `sequence_length`. This is because
    the sequence is not used by the client but the length is
    so we save bytes over the wire.
    """

    sequence_length: int
