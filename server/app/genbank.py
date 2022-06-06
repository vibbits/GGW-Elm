from typing import Tuple, Callable, Any
import datetime
import io

from Bio import SeqIO
from Bio.Seq import Seq
import Bio.SeqFeature
from fastapi import Depends
from sqlalchemy.orm import Session


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


def filter_features(left: int, right: int, level: VectorLevel) -> Callable[[Any], bool]:
    def my_filter(feature: Any) -> bool:
        if level == VectorLevel.BACKBONE:
            start = min(left, right)
            end = max(left, right)
            return (
                feature.location.nofuzzy_start > end
                or feature.location.nofuzzy_end < start
            )
        elif level == VectorLevel.LEVEL0:
            return (
                feature.location.nofuzzy_start >= left
                and feature.location.nofuzzy_end <= right
            )
        else:
            return False

    return my_filter


def reposition_features(
    bsa_left: int,
    bsa_right: int,
    sequence_length: int,
    level: VectorLevel,
    feature: Feature,
) -> Feature:
    """
    Function that repositions the features after performing a BsaI digest.
    """
    new_feature_start_pos = 0
    new_feature_end_pos = 0

    start = min(bsa_left, bsa_right)
    end = max(bsa_left, bsa_right)

    if level == VectorLevel.LEVEL0:
        new_feature_start_pos = feature.start_pos - start
        new_feature_end_pos = feature.end_pos - start
    elif level == VectorLevel.BACKBONE:
        if feature.start_pos >= end:
            new_feature_start_pos = feature.start_pos - end
            new_feature_end_pos = feature.end_pos - end
        else:
            new_feature_start_pos = feature.start_pos + (sequence_length - end)
            new_feature_end_pos = feature.end_pos + (sequence_length - end)
    else:
        raise ValueError(
            f"Error in adjusting feature positions. Incorrect VectorLevel: '{level}'"
        )

    return Feature(
        type=feature.type,
        qualifiers=feature.qualifiers,
        start_pos=new_feature_start_pos,
        end_pos=new_feature_end_pos,
        strand=feature.strand,
    )


def convert_gbk_to_vector(genbank_file, level: VectorLevel) -> GenbankData:
    """
    Function that reads in a genbank file and converts it into a GenBankData object.
    """
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
    # print(f"(Start, end, level) = {(start, end, level)}")
    features = []
    for feature in filter(filter_features(start, end, level), record.features):
        new_qualifiers = [
            Qualifier(key=key, value=str(value))
            for key, value in feature.qualifiers.items()
        ]
        # print(
        #     f"No fuzzy start:{feature.location.nofuzzy_start}\tNo fuzzy end:{feature.location.nofuzzy_end}"
        # )
        features.append(
            reposition_features(
                bsa_left=start,
                bsa_right=end,
                sequence_length=len(sequence),
                level=level,
                feature=Feature(
                    type=feature.type,
                    qualifiers=new_qualifiers,
                    start_pos=feature.location.nofuzzy_start,
                    end_pos=feature.location.nofuzzy_end,
                    strand=feature.location.strand,
                ),
            )
        )

    assert isinstance(sequence, str)

    return GenbankData(
        sequence=sequence,
        annotations=annotations,
        features=features,
        references=references,
    )


def serialize_to_genbank(vector: model.Vector) -> str:
    """
    Converts a model.Vector to a Genbank output.
    """
    vector_record = SeqIO.SeqRecord(
        seq=Seq(vector.sequence), annotations={"molecule_type": "circular dsDNA"}
    )

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

        print(
            f"Feature id {vector_feature.id} location (start:{vector_feature.start_pos}, end:{vector_feature.end_pos})"
        )

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

    # Writing record content to an in-memory file and returning its content.
    with io.StringIO() as outf:
        SeqIO.write(vector_record, outf, "genbank")
        return outf.getvalue()


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
