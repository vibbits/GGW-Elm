" Database data model "

from datetime import datetime
from typing import Optional, List

from sqlalchemy import Column, DateTime, Integer, String, UniqueConstraint, ForeignKey
from sqlalchemy.orm import relationship, Mapped

from app.database import Base


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
    name: str = Column(String, nullable=False, unique=True)  # Plasmid name
    bacterial_strain: str = Column(String, nullable=False)
    responsible: str = Column(String, nullable=False)
    group: str = Column(String, nullable=False)
    bsa1_overhang: str = Column(String, nullable=False)
    selection: str = Column(String, nullable=False)
    cloning_technique: str = Column(String, nullable=False)  # DNA or PCR synthesis?
    is_BsmB1_free: str = Column(String, nullable=False)  # TODO: Might be removed...
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

    ## JAMES PROPOSES:
    level: int = Column(Integer)
    BsmB1_site: str = Column(String)
    gateway_site: str = Column(String)
    children: Mapped[List["Vector"]] = relationship(
        "Vector",
        secondary="vector_hierarchy",
        primaryjoin=id == VectorHierarchy.parent,
        secondaryjoin=id == VectorHierarchy.child,
        backref="parents",
    )
    ##


# class Backbone(Base):
#     pass


class Annotation(Base):
    "Annotations relating to a Vector."
    __tablename__ = "annotations"

    id: int = Column(Integer, primary_key=True, index=True)
    key: str = Column(String, nullable=False)
    value: str = Column(String)
    vector = Column(Integer, ForeignKey("vectors.id"), nullable=False)


class Feature(Base):
    "Features relating to a Vector."
    __tablename__ = "features"

    id: int = Column(Integer, primary_key=True, index=True, nullable=False)
    type: str = Column(String)
    start_pos: int = Column(Integer, nullable=False)
    end_pos: int = Column(Integer, nullable=False)
    strand: int = Column(Integer, nullable=False)
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
