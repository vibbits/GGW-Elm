" Database data model "

from datetime import datetime
from typing import Optional, List

from sqlalchemy import Column, DateTime, Integer, String, UniqueConstraint, ForeignKey
from sqlalchemy.orm import relationship, Mapped
from sqlalchemy.sql.expression import null

from app.database import Base


class User(Base):
    "An authenticated user"
    __tablename__ = "users"

    id: int = Column(Integer, primary_key=True, index=True)
    iss: str = Column(String, nullable=False, index=True)
    sub: str = Column(String, nullable=False, index=True)
    created: datetime = Column(DateTime, nullable=False, default=datetime.now())
    name: Optional[str] = Column(String)
    role: str = Column(String, nullable=False, default="user")

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
    name: str = Column(String, nullable=False, unique=True)
    mpg_number: str = Column(String, nullable=False, unique=True)
    bacterial_strain: str = Column(String, nullable=False)
    responsible: str = Column(String, nullable=False)
    group: str = Column(String, nullable=False)
    bsa1_overhang: str = Column(String, nullable=False)
    selection: str = Column(String, nullable=False)
    cloning_technique: str = Column(String, nullable=False)  # DNA or PCR synthesis?
    is_BsmB1_free: str = Column(String, nullable=False)  # Might be removed...
    notes: str = Column(String, nullable=True)
    REase_digest: str = Column(String, nullable=True)  # Might be removed...

    # Genbank information
    sequence: str = Column(String, nullable=False)

    # Annotations are stored in another table
    annotations: Mapped[List["Annotation"]] = relationship(
        "Annotation", uselist=True, collection_class=list
    )
    sequence_length: int = Column(Integer, nullable=False)
    features: Mapped[List["Feature"]] = relationship(
        "Feature", uselist=True, collection_class=list
    )
    references: Mapped[List["Reference"]] = relationship(
        "Reference", uselist=True, collection_class=list
    )


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
