"""Implementation of Backbones

Revision ID: 12d6f7ae4742
Revises: 4c75e0271cec
Create Date: 2022-02-07 14:35:31.105562

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "12d6f7ae4742"
down_revision = "4c75e0271cec"
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    with op.batch_alter_table("features", schema=None) as batch_op:
        batch_op.alter_column("strand", existing_type=sa.INTEGER(), nullable=True)

    with op.batch_alter_table("user_vector_mapping", schema=None) as batch_op:
        batch_op.alter_column("user", existing_type=sa.INTEGER(), nullable=True)

    with op.batch_alter_table("vectors", schema=None) as batch_op:
        batch_op.add_column(sa.Column("mpg_number", sa.Integer(), nullable=False))
        batch_op.add_column(sa.Column("bsmb1_overhang", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("vector_type", sa.String(), nullable=True))
        batch_op.add_column(sa.Column("date", sa.DateTime(), nullable=True))
        batch_op.alter_column(
            "bsa1_overhang", existing_type=sa.VARCHAR(), nullable=True
        )
        batch_op.alter_column("selection", existing_type=sa.VARCHAR(), nullable=True)
        batch_op.alter_column(
            "cloning_technique", existing_type=sa.VARCHAR(), nullable=True
        )
        batch_op.alter_column(
            "is_BsmB1_free", existing_type=sa.VARCHAR(), nullable=True
        )
        batch_op.alter_column("level", existing_type=sa.INTEGER(), nullable=False)
        batch_op.create_unique_constraint("lvl_mpg", ["level", "mpg_number"])

    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    with op.batch_alter_table("vectors", schema=None) as batch_op:
        batch_op.drop_constraint("lvl_mpg", type_="unique")
        batch_op.alter_column("level", existing_type=sa.INTEGER(), nullable=True)
        batch_op.alter_column(
            "is_BsmB1_free", existing_type=sa.VARCHAR(), nullable=False
        )
        batch_op.alter_column(
            "cloning_technique", existing_type=sa.VARCHAR(), nullable=False
        )
        batch_op.alter_column("selection", existing_type=sa.VARCHAR(), nullable=False)
        batch_op.alter_column(
            "bsa1_overhang", existing_type=sa.VARCHAR(), nullable=False
        )
        batch_op.drop_column("date")
        batch_op.drop_column("vector_type")
        batch_op.drop_column("bsmb1_overhang")
        batch_op.drop_column("mpg_number")

    with op.batch_alter_table("user_vector_mapping", schema=None) as batch_op:
        batch_op.alter_column("user", existing_type=sa.INTEGER(), nullable=False)

    with op.batch_alter_table("features", schema=None) as batch_op:
        batch_op.alter_column("strand", existing_type=sa.INTEGER(), nullable=False)

    # ### end Alembic commands ###
