from Bio import SeqIO

from app.schemas import Vector, Annotation, Feature, Reference, Qualifier


# Function that reads in a genbank file and converts it into a json
def convert_gbk_to_vector(genbank_file) -> Vector:
    # Reading the genbank file
    record = SeqIO.read(genbank_file, "genbank")

    # Getting the annotations
    annotations = []
    references = []
    for key, val in record.annotations.items():
        # All annotations are strings, integers or list of them but references are a special case.
        # References are objects that can be deconstructed to an author and a title, both strings.
        if key == "references":
            for reference in record.annotations["references"]:
                references.append(
                    Reference(authors=reference.authors, title=reference.title)
                )
        else:
            annotations.append(Annotation(key=key, value=str(val)))

    # Getting the features:
    features = []
    for feature in record.features:
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

    return Vector(
        name="".join(str(record.name).split("_")[1:]),
        mpg_number=str(record.name).split("_", maxsplit=1)[0],
        bacterial_strain="Not provided",  # Not provided through a genbank file => Additional information
        responsible="Not provided",  # Not provided through a genbank file => Additional information
        group="Not provided",  # Not provided through a genbank file => Additional information
        bsa1_overhang="Not provided",  # Not provided through a genbank file => Additional information
        selection="Not provided",  # Not provided through a genbank file => Additional information
        cloning_technique="Not provided",  # Not provided through a genbank file => Additional information
        is_BsmB1_free="Not provided",  # Not provided through a genbank file => Additional information
        notes="Not provided",  # Not provided through a genbank file => Additional information
        REase_digest="Not provided",  # Not provided through a genbank file => Additional information
        sequence=str(record.seq),
        sequence_length=len(record.seq),
        annotations=annotations,
        features=features,
        references=references,
    )
