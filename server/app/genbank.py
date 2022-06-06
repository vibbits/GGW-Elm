from typing import Tuple, Callable, Any
import datetime
import os
import tempfile
from Bio import SeqIO
from Bio.Seq import Seq
import Bio.SeqFeature

from app.level import VectorLevel
from app.schemas import (
    GenbankData,
    Annotation,
    Feature,
    VectorReference,
    Qualifier,
)

from app import model, deps
from app.level import VectorLevel
from typing import List

from fastapi import Depends
from sqlalchemy.orm import Session


def digest_sequence(level: VectorLevel, sequence: str) -> Tuple[int, int, str]:
    if len(sequence) < 18:  # len("GGTCTCXXXXXXGAGACC")
        raise ValueError("Not a valid input sequence")

    bsa1_site_left = "GGTCTC"  # Actual sequence is 5' GGTCTCN 3'
    bsa1_site_right = "GAGACC"  # Actual sequence is 5' NNNNNGAGACC 3'

    pos_bsa1_left = sequence.index(bsa1_site_left) + 7
    pos_bsa1_right = sequence.index(bsa1_site_right) - 5

    if level == VectorLevel.BACKBONE:
        if pos_bsa1_left < pos_bsa1_right:
            digested_sequence = sequence[pos_bsa1_right:] + sequence[:pos_bsa1_left]
        else:
            digested_sequence = sequence[pos_bsa1_left:] + sequence[:pos_bsa1_right]
    elif level == VectorLevel.LEVEL0:
        if pos_bsa1_left <= pos_bsa1_right:
            digested_sequence = sequence[pos_bsa1_left:pos_bsa1_right]
        else:
            digested_sequence = sequence[pos_bsa1_left:] + sequence[:pos_bsa1_right]

    assert digested_sequence is not None

    return (pos_bsa1_left, pos_bsa1_right, str(digested_sequence))


def filter_features(start: int, end: int, level: VectorLevel) -> Callable[[Any], bool]:
    def my_filter(feature: Any) -> bool:
        if level == VectorLevel.BACKBONE:
            return not (
                feature.location.nofuzzy_start > start
                and feature.location.nofuzzy_end < end
            )
        elif level == VectorLevel.LEVEL0:
            return not (
                feature.location.nofuzzy_start > end
                and feature.location.nofuzzy_end < start
            )
        else:
            return False

    return my_filter


# Function that reads in a genbank file and converts it into a GenBankData object
def convert_gbk_to_vector(genbank_file, level: VectorLevel) -> GenbankData:
    # Reading the genbank file
    record = SeqIO.read(genbank_file, "genbank")

    (start, end, sequence) = digest_sequence(level, record.seq)

    # Getting the annotations
    annotations = []
    references = []
    for key, val in record.annotations.items():
        # All annotations are strings, integers or list of them but references are a special case.
        # References are objects that can be deconstructed to an author and a title, both strings.
        if key == "references":
            for reference in record.annotations["references"]:
                references.append(
                    VectorReference(authors=reference.authors, title=reference.title)
                )
        else:
            annotations.append(Annotation(key=key, value=str(val)))

    # Getting the features:
    features = []
    for feature in filter(filter_features(start, end, level), record.features):
        new_qualifiers = [
            Qualifier(key=key, value=str(value))
            for key, value in feature.qualifiers.items()
        ]
        features.append(
            Feature(
                type=feature.type,
                qualifiers=new_qualifiers,
                start_pos=feature.location.nofuzzy_start,
                end_pos=feature.location.nofuzzy_end,
                strand=feature.location.strand,
            )
        )

    assert isinstance(sequence, str)

    return GenbankData(
        sequence=sequence,
        annotations=annotations,
        features=features,
        references=references,
    )


# Converts a model.Vector to a Genbank output
def convert_LevelN_to_genbank(
    vector: model.Vector, database: Session = Depends(deps.get_db)
) -> str:
    vector_record = SeqIO.SeqRecord(seq=Seq(vector.sequence))

    # General construct information
    vector_record.name = (
        "MP-G1-" + str(vector.location) + "_" + vector.name.replace(" ", "_")
    )
    vector_record.description = "synthetic circular DNA"

    vector_record.origin = ""
    vector_record.size = len(vector.sequence)

    # Annotations
    for annotation in vector.annotations:
        vector_record.annotations[annotation.key] = annotation.value

    vector_record.accession = []
    vector_record.comment = ""
    vector_record.data_file_division = ""  # E.g. 'PLN' stands for plants
    vector_record.date = vector.date  # Is also present in annotations...
    vector_record.keywords = []
    vector_record.residue_type = "ds-DNA circular"
    vector_record.organism = (
        "synthetic DNA construct"  # To ask: Should this be bacterial_strain?
    )
    # To ask: molecule_type == residue_type?
    # To ask: sequence_version == accesion version?
    # The source of material where the sequence came from.
    vector_record.source = []
    vector_record.taxonomy = (
        []
    )  # A listing of the taxonomic classification of the organism, starting general and getting more specific.
    vector_record.topology = ""

    # References
    vector_record.annotations["references"] = [
        mod_Reference(authors=ref.authors, title=ref.title) for ref in vector.references
    ]

    # Features
    feature_list = []
    for vector_feature in vector.features:
        feature_qualifiers = vector_feature.qualifiers

        feat = Bio.SeqFeature.SeqFeature(
            type=vector_feature.type,
            location=Bio.SeqFeature.FeatureLocation(
                start=vector_feature.start_pos,
                end=vector_feature.end_pos,
                strand=vector_feature.strand,
            ),
        )

        for qual in feature_qualifiers:
            feat.qualifiers[qual.key] = qual.value

        # vector_record.features.append(feat)
        feature_list.append(feat)

    vector_record.features = feature_list

    # Writing record content to a temporary file
    with tempfile.NamedTemporaryFile(delete=False, mode="w+", encoding="utf-8") as f:
        SeqIO.write(vector_record, f.name, "genbank")
        f.seek(0)
        lines = f.readlines()

    # Manually clean-up of the temporary file
    os.remove(f.name)

    content = "".join(lines)
    print(content)
    return content


class mod_Reference(Bio.SeqFeature.Reference):
    """
    This class extends the existing Record.Reference class.
    """

    def __init__(self, authors: str, title: str):
        """
        Extra constructor to initialize a Record.Reference object
        with these attributes:

        - authors: str
        - title: str
        """
        super().__init__()
        self.authors = authors
        self.title = title
        self.journal = (
            f"Generated {datetime.datetime.now().strftime('%a %d %b %Y')} by GG2"
        )
