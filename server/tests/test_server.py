import pytest

from app import __version__
from app.genbank import digest_sequence, reposition_features
from app.level import VectorLevel
from app.schemas import Feature


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


def test_reposition_features_level0_case1():
    """
    VectorLevel = LEVEL0
    bsa1 left < bsa1 right
    """
    original_feature = Feature(
        type="Some type", qualifiers=[], start_pos=3125, end_pos=3425, strand=1
    )

    # bsa1 left < bsa1 right
    bsa1_left = 1520
    bsa1_right = 3760
    sequence_length = 6250
    vector_level = VectorLevel.LEVEL0

    adjusted_feature = Feature(
        type="Some type", qualifiers=[], start_pos=1605, end_pos=1905, strand=1
    )

    assert (
        reposition_features(
            bsa_left=bsa1_left,
            bsa_right=bsa1_right,
            sequence_length=sequence_length,
            level=vector_level,
            feature=original_feature,
        )
        == adjusted_feature
    )


def test_reposition_features_level0_case2():
    """
    VectorLevel = LEVEL0
    bsa1 left > bsa1 right
    """
    original_feature = Feature(
        type="Some type", qualifiers=[], start_pos=3125, end_pos=3425, strand=1
    )

    bsa1_left = 3760
    bsa1_right = 1520
    sequence_length = 6250
    vector_level = VectorLevel.LEVEL0

    adjusted_feature = Feature(
        type="Some type", qualifiers=[], start_pos=1605, end_pos=1905, strand=1
    )

    assert (
        reposition_features(
            bsa_left=bsa1_left,
            bsa_right=bsa1_right,
            sequence_length=sequence_length,
            level=vector_level,
            feature=original_feature,
        )
        == adjusted_feature
    )


def test_reposition_features_backbone_case1():
    """
    VectorLevel = BACKBONE
    bsa1 left site < bsa1 right site
    feature position > bsa1 right site
    """
    original_feature = Feature(
        type="Some type", qualifiers=[], start_pos=3825, end_pos=3925, strand=1
    )

    bsa1_left = 1520
    bsa1_right = 3760
    sequence_length = 6250
    vector_level = VectorLevel.BACKBONE

    adjusted_feature = Feature(
        type="Some type", qualifiers=[], start_pos=65, end_pos=165, strand=1
    )

    assert (
        reposition_features(
            bsa_left=bsa1_left,
            bsa_right=bsa1_right,
            sequence_length=sequence_length,
            level=vector_level,
            feature=original_feature,
        )
        == adjusted_feature
    )


def test_reposition_features_backbone_case2():
    """
    VectorLevel = BACKBONE
    bsa1 left site < bsa1 right site
    feature position < bsa1 left site
    """
    original_feature = Feature(
        type="Some type", qualifiers=[], start_pos=1125, end_pos=1175, strand=1
    )

    bsa1_left = 1520
    bsa1_right = 3760
    sequence_length = 6250
    vector_level = VectorLevel.BACKBONE

    adjusted_feature = Feature(
        type="Some type", qualifiers=[], start_pos=3615, end_pos=3665, strand=1
    )

    assert (
        reposition_features(
            bsa_left=bsa1_left,
            bsa_right=bsa1_right,
            sequence_length=sequence_length,
            level=vector_level,
            feature=original_feature,
        )
        == adjusted_feature
    )


def test_reposition_features_backbone_case3():
    """
    VectorLevel = BACKBONE
    bsa1 left site > bsa1 right site
    feature position > bsa1 right site
    """
    original_feature = Feature(
        type="Some type", qualifiers=[], start_pos=3825, end_pos=3925, strand=1
    )

    bsa1_left = 3760
    bsa1_right = 1520
    sequence_length = 6250
    vector_level = VectorLevel.BACKBONE

    adjusted_feature = Feature(
        type="Some type", qualifiers=[], start_pos=65, end_pos=165, strand=1
    )

    assert (
        reposition_features(
            bsa_left=bsa1_left,
            bsa_right=bsa1_right,
            sequence_length=sequence_length,
            level=vector_level,
            feature=original_feature,
        )
        == adjusted_feature
    )


def test_reposition_features_backbone_case4():
    """
    VectorLevel = BACKBONE
    bsa1 left site > bsa1 right site
    feature position < bsa1 left site
    """
    original_feature = Feature(
        type="Some type", qualifiers=[], start_pos=1125, end_pos=1175, strand=1
    )

    bsa1_left = 3760
    bsa1_right = 1520
    sequence_length = 6250
    vector_level = VectorLevel.BACKBONE

    adjusted_feature = Feature(
        type="Some type", qualifiers=[], start_pos=3615, end_pos=3665, strand=1
    )

    assert (
        reposition_features(
            bsa_left=bsa1_left,
            bsa_right=bsa1_right,
            sequence_length=sequence_length,
            level=vector_level,
            feature=original_feature,
        )
        == adjusted_feature
    )
