" Database data model "

from typing import Optional, List
from datetime import datetime
import enum

from sqlalchemy import (
    Column,
    DateTime,
    Integer,
    String,
    UniqueConstraint,
    ForeignKey,
    Enum,
    null,
)
from sqlalchemy.orm import relationship, Mapped

from app.database import Base


class VectorLevel(enum.Enum):
    BACKBONE = (enum.auto(),)
    LEVEL0 = (enum.auto(),)
    LEVEL1 = enum.auto()


class UserVectorMapping(Base):
    "A many-to-many mapping between users and vectors"
    __tablename__ = "user_vector_mapping"

    id = Column(Integer, primary_key=True)
    user = Column(Integer, ForeignKey("users.id"))
    vector = Column(Integer, ForeignKey("vectors.id"))


class VectorHierarchy(Base):
    """
    Level 1 vectors are made out of many level 0 vectors.
    A level 0 vector can be used in multiple level 1 vectors.

    Svens lab names level 1 vectors to encode the level 0 vectors it is made from.
    Instead, and to avoid likely human error, we also store this hierarchial
    relationship. This table maps children to parents (level 0 to level 1)
    """

    __tablename__ = "vector_hierarchy"

    id = Column(Integer, primary_key=True)
    parent = Column(Integer, ForeignKey("vectors.id"), primary_key=True)
    child = Column(Integer, ForeignKey("vectors.id"), primary_key=True)


class User(Base):
    "An authenticated user"
    __tablename__ = "users"

    id: int = Column(Integer, primary_key=True, index=True)
    iss: str = Column(String, nullable=False, index=True)
    sub: str = Column(String, nullable=False, index=True)
    created: datetime = Column(DateTime, nullable=False, default=datetime.now())
    name: Optional[str] = Column(String)
    role: str = Column(String, nullable=False, default="user")
    vectors: Mapped[List["Vector"]] = relationship(
        "Vector", secondary="user_vector_mapping", back_populates="users"
    )

    __table_args__ = (UniqueConstraint("iss", "sub", name="login_id"),)


class IdentityProvider(Base):
    "Accepted identity providers"
    __tablename__ = "providers"

    id: int = Column(Integer, primary_key=True, index=True)
    name: str = Column(String, nullable=False, unique=True)
    issuer: str = Column(String, nullable=False)
    clientid: str = Column(String, nullable=False)
    secret: str = Column(String, nullable=False)


class Vector(Base):
    "Sequence blocks for building a golden gateway construct."
    __tablename__ = "vectors"

    id: int = Column(Integer, primary_key=True, index=True)

    # General information
    mpg_number: int = Column(Integer, nullable=False)
    name: str = Column(String, nullable=False, unique=True)  # Plasmid name
    bacterial_strain: str = Column(String, nullable=False)
    responsible: str = Column(String, nullable=False)
    group: str = Column(String, nullable=False)
    bsa1_overhang: str = Column(String, nullable=True)
    selection: str = Column(String, nullable=True)
    cloning_technique: str = Column(String, nullable=True)  # DNA or PCR synthesis?
    is_BsmB1_free: str = Column(String, nullable=True)  # TODO: Might be removed...
    notes: str = Column(String, nullable=True)
    REase_digest: str = Column(String, nullable=True)  # TODO: Might be removed...

    # Genbank information
    sequence: str = Column(String, nullable=False)

    # Annotations are stored in another table
    annotations: Mapped[List["Annotation"]] = relationship(
        "Annotation", uselist=True, collection_class=list
    )
    features: Mapped[List["Feature"]] = relationship(
        "Feature", uselist=True, collection_class=list
    )
    references: Mapped[List["Reference"]] = relationship(
        "Reference", uselist=True, collection_class=list
    )
    users: Mapped[List["User"]] = relationship(
        "User", secondary="user_vector_mapping", back_populates="vectors"
    )

    # Extra fields for level 1
    level: VectorLevel = Column(Enum(VectorLevel), nullable=False)
    BsmB1_site: str = Column(String, nullable=True)
    children: Mapped[List["Vector"]] = relationship(
        "Vector",
        secondary="vector_hierarchy",
        primaryjoin=id == VectorHierarchy.parent,
        secondaryjoin=id == VectorHierarchy.child,
        backref="parents",
    )

    # Extra columns for Backbones
    bsmb1_overhang: str = Column(String, nullable=True)
    gateway_site: str = Column(String, nullable=True)
    vector_type: str = Column(String, nullable=True)
    date: datetime = Column(DateTime, nullable=True, default=datetime.now())

    # Unique MP-GX-numbering constraint
    __table_args__ = (UniqueConstraint("level", "mpg_number", name="lvl_mpg"),)

    def __str__(self):
        first_ann = str(self.annotations[0]) if len(self.annotations) > 0 else "null"
        return f"Vector({self.name=}, {len(self.annotations)=} [{first_ann}])"


class Annotation(Base):
    "Annotations relating to a Vector."
    __tablename__ = "annotations"

    id: int = Column(Integer, primary_key=True, index=True)
    key: str = Column(String, nullable=False)
    value: str = Column(String)
    vector = Column(Integer, ForeignKey("vectors.id"), nullable=False)

    def __str__(self):
        return f"Annotation({self.id=}, {self.key=}, {self.value=}, {self.vector=}"


class Feature(Base):
    "Features relating to a Vector."
    __tablename__ = "features"

    id: int = Column(Integer, primary_key=True, index=True, nullable=False)
    type: str = Column(String)
    start_pos: int = Column(Integer, nullable=False)
    end_pos: int = Column(Integer, nullable=False)
    strand: int = Column(Integer, nullable=True)
    vector = Column(Integer, ForeignKey("vectors.id"), nullable=False)
    qualifiers: Mapped[List["Qualifier"]] = relationship(
        "Qualifier", uselist=True, collection_class=list
    )


class Reference(Base):
    "Reference relating to a vector."
    __tablename__ = "references"

    id: int = Column(Integer, primary_key=True, index=True)
    authors: str = Column(String)
    title: str = Column(String)
    vector = Column(Integer, ForeignKey("vectors.id"), nullable=False)


class Qualifier(Base):
    "Qualifier relating to a vector."
    __tablename__ = "qualifiers"

    id: int = Column(Integer, primary_key=True, index=True, nullable=False)
    key: str = Column(String, nullable=False)
    value: str = Column(String)
    feature = Column(Integer, ForeignKey("features.id"), nullable=False)
