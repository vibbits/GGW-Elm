from typing import Tuple, Callable, Any

from Bio import SeqIO

from app.level import VectorLevel
from app.schemas import (
    GenbankData,
    Annotation,
    Feature,
    VectorReference,
    Qualifier,
)


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


# Function that reads in a genbank file and converts it into a json
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
