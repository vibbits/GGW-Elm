"""Extract qualifiers to their own table

Revision ID: 1abd517b82eb
Revises: 1c6b70c5141f
Create Date: 2021-11-26 15:55:14.188723

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "1abd517b82eb"
down_revision = "69252b7f20ca"
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.create_table(
        "qualifiers",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("key", sa.String(), nullable=False),
        sa.Column("value", sa.String(), nullable=True),
        sa.Column("feature", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(
            ["feature"],
            ["features.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_qualifiers_id"), "qualifiers", ["id"], unique=False)
    op.create_table(
        "vectors",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("mpg_number", sa.String(), nullable=False),
        sa.Column("bacterial_strain", sa.String(), nullable=False),
        sa.Column("responsible", sa.String(), nullable=False),
        sa.Column("group", sa.String(), nullable=False),
        sa.Column("bsa1_overhang", sa.String(), nullable=False),
        sa.Column("selection", sa.String(), nullable=False),
        sa.Column("cloning_technique", sa.String(), nullable=False),
        sa.Column("is_BsmB1_free", sa.String(), nullable=False),
        sa.Column("notes", sa.String(), nullable=True),
        sa.Column("REase_digest", sa.String(), nullable=False),
        sa.Column("sequence", sa.String(), nullable=False),
        sa.Column("sequence_length", sa.Integer(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("mpg_number"),
        sa.UniqueConstraint("name"),
    )
    op.create_index(op.f("ix_vectors_id"), "vectors", ["id"], unique=False)
    op.create_table(
        "annotations",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("key", sa.String(), nullable=False),
        sa.Column("value", sa.String(), nullable=True),
        sa.Column("vector", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["vector"],
            ["vectors.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_annotations_id"), "annotations", ["id"], unique=False)
    op.create_table(
        "features",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("type", sa.String(), nullable=True),
        sa.Column("qualifier", sa.String(), nullable=True),
        sa.Column("start_pos", sa.Integer(), nullable=False),
        sa.Column("end_pos", sa.Integer(), nullable=False),
        sa.Column("strand", sa.Integer(), nullable=False),
        sa.Column("vector", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["vector"],
            ["vectors.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_features_id"), "features", ["id"], unique=False)
    op.create_table(
        "references",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("authors", sa.String(), nullable=True),
        sa.Column("title", sa.String(), nullable=True),
        sa.Column("vector", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["vector"],
            ["vectors.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_references_id"), "references", ["id"], unique=False)

    with op.batch_alter_table("features") as batch_op:
        batch_op.drop_column("qualifier")
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.add_column("features", sa.Column("qualifiers", sa.VARCHAR(), nullable=False))
    op.drop_index(op.f("ix_qualifiers_id"), table_name="qualifiers")
    op.drop_table("qualifiers")

    op.drop_index(op.f("ix_references_id"), table_name="references")
    op.drop_table("references")
    op.drop_index(op.f("ix_features_id"), table_name="features")
    op.drop_table("features")
    op.drop_index(op.f("ix_annotations_id"), table_name="annotations")
    op.drop_table("annotations")
    op.drop_index(op.f("ix_vectors_id"), table_name="vectors")
    op.drop_table("vectors")
    # ### end Alembic commands ###
