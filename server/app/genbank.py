from Bio import SeqIO
import json

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
        # new_feature = Feature()
        # Getting the qualifiers of each feature

        new_qualifiers = []
        for k, v in feature.qualifiers.items():
            new_qualifiers.append(Qualifier(key=k, value=str(v)))
        features.append(
            Feature(
                type=feature.type,
                qualifiers=new_qualifiers,
                # qualifier="qualifiers",
                start_pos=feature.location.nofuzzy_start,
                end_pos=feature.location.nofuzzy_end,
                strand=feature.location.strand,
            )
        )

    return Vector(
        name="".join(str(record.name).split("_")[1:]),
        mpg_number=str(record.name).split("_")[0],
        sequence=str(record.seq),
        sequence_length=len(record.seq),
        annotations=annotations,
        features=features,
        references=references,
    )
