from hmac import digest
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
    assert digest_sequence(VectorLevel.LEVEL0, "GGTCTCXXXXXXGAGACC") == (
        7,
        7,
        "",
    )


def test_single_character():
    assert digest_sequence(
        VectorLevel.LEVEL0, "GGTCTCXGENE_OF_INTERESTXXXXXGAGACC"
    ) == (7, 23, "GENE_OF_INTEREST")


def test_emoji_padding():
    assert digest_sequence(VectorLevel.LEVEL0, "GGTCTC🐺.🦍😀🔥⛲🏄GAGACC") == (7, 8, ".")


def test_reverse_level0():
    assert digest_sequence(
        VectorLevel.LEVEL0, "OF_INTERESTXXXXXGAGACCNOT_OF_INTERESTGGTCTCXGENE_"
    ) == (
        44,
        11,
        "GENE_OF_INTEREST",
    )


def test_normal_backbone():
    assert digest_sequence(
        VectorLevel.BACKBONE,
        "REGION1_REMAINSGGTCTCXREGION_CUT_OUTXXXXXGAGACCREGION2_REMAINS_",
    ) == (22, 36, "XXXXXGAGACCREGION2_REMAINS_REGION1_REMAINSGGTCTCX")


def test_reverse_backbone():
    assert digest_sequence(
        VectorLevel.BACKBONE,
        "REGION2_REMAINSXXXXXGAGACCREGION_CUT_OUTGGTCTCXREGION1_REMAINS",
    ) == (47, 15, "REGION1_REMAINSREGION2_REMAINS")
