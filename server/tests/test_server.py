import pytest

from app import __version__
from app.genbank import digest_sequence
from app.level import VectorLevel


def test_version():
    assert __version__ == "0.1.0"


def test_sequence_with_no_inserts():
    with pytest.raises(ValueError) as e:
        digest_sequence(VectorLevel.LEVEL0, "")


def test_sequence_with_no_thing_in_the_middle():
    with pytest.raises(ValueError) as e:
        digest_sequence(
            VectorLevel.LEVEL0, "GGTCTCGAGACC"
        )  # No thing in the middle here


def test_sequence_min_length():
    assert digest_sequence(VectorLevel.LEVEL0, "GGTCTCXXXXXXGAGACC") == (7, 7, "")


def test_normal_level0():
    assert digest_sequence(
        VectorLevel.LEVEL0, "GGTCTCXGENE_OF_INTERESTXXXXXGAGACC"
    ) == (7, 23, "GENE_OF_INTEREST")


def test_minimal_single_nucleotide_level0():
    assert digest_sequence(VectorLevel.LEVEL0, "GGTCTCXNXXXXXGAGACC") == (7, 8, "N")


def test_emoji_padding_level0():
    assert digest_sequence(VectorLevel.LEVEL0, "GGTCTC🐺.🦍😀🔥⛲🏄GAGACC") == (7, 8, ".")


def test_reverse_level0():
    assert digest_sequence(
        VectorLevel.LEVEL0, "OF_INTERESTXXXXXGAGACCNOT_OF_INTERESTGGTCTCXGENE_"
    ) == (
        44,
        11,
        "GENE_OF_INTEREST",
    )


def test_level0_backbone():
    assert digest_sequence(
        VectorLevel.BACKBONE,
        "REGION1_REMAINSGGTCTCXREGION_CUT_OUTXXXXXGAGACCREGION2_REMAINS_",
    ) == (22, 36, "XXXXXGAGACCREGION2_REMAINS_REGION1_REMAINSGGTCTCX")


def test_minimal_length_level0_backbone():
    assert digest_sequence(
        VectorLevel.BACKBONE, "GGTCTCXREGION_CUT_OUTXXXXXGAGACC"
    ) == (7, 21, "XXXXXGAGACCGGTCTCX")


def test_emoji_padding_level0_backbone():
    assert digest_sequence(VectorLevel.BACKBONE, "GGTCTCX🐺🦍😀🔥⛲🏄XXXXXGAGACC") == (
        7,
        13,
        "XXXXXGAGACCGGTCTCX",
    )


def test_single_nucleotide_cut_level0_backbone():
    assert digest_sequence(VectorLevel.BACKBONE, "GGTCTCXNXXXXXGAGACC") == (
        7,
        8,
        "XXXXXGAGACCGGTCTCX",
    )


def test_level1_backbone():
    assert digest_sequence(
        VectorLevel.BACKBONE,
        "REGION2_REMAINSXXXXXGAGACCREGION_CUT_OUTGGTCTCXREGION1_REMAINS",
    ) == (47, 15, "REGION1_REMAINSREGION2_REMAINS")


def test_minimal_length_level1_backbone():
    assert digest_sequence(
        VectorLevel.BACKBONE,
        "XXXXXGAGACCREGION_CUT_OUTGGTCTCX",
    ) == (32, 0, "")


def test_emoji_padding_level1_backbone():
    assert digest_sequence(
        VectorLevel.BACKBONE,
        "REGION2_REMAINSXXXXXGAGACC🐺🦍😀🔥⛲🏄GGTCTCXREGION1_REMAINS",
    ) == (39, 15, "REGION1_REMAINSREGION2_REMAINS")


def test_single_nucleotide_cut_level1_backbone():
    assert digest_sequence(
        VectorLevel.BACKBONE,
        "REGION2_REMAINSXXXXXGAGACCNGGTCTCXREGION1_REMAINS",
    ) == (34, 15, "REGION1_REMAINSREGION2_REMAINS")
