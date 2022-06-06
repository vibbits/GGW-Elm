"""
GGW server administration console command.
This is intended to be run for administration tasks such as
updating the database schema, adding an admin user,
adding an identity provider, etc.
"""

from typing import Tuple, Optional, List

import sys
from pathlib import Path
from datetime import datetime
import csv
import click
import httpx
from Bio import SeqIO
from sqlalchemy.exc import SQLAlchemyError

from app.database import SessionLocal
from app.level import VectorLevel
from app import model, crud, oidc, schemas
from app.genbank import convert_gbk_to_vector


@click.group()
def cli():
    "Top-level CLI"


@cli.command()
@click.option("--iss", default=1, help="identity provider")
@click.option("--sub", required=True, help="subject")
@click.argument("name")
def create_admin(iss, sub, name):
    "Create a new admin user"
    with SessionLocal() as database:
        if (provider := crud.get_provider_by_id(database, provider_id=iss)) is None:
            click.echo(f"No identity provider with id={iss}", err=True)
            return

        user = schemas.UserCreate(name=name, role="admin", iss=provider.issuer, sub=sub)
        crud.create_user(database, user)
        click.echo(f'Admin ({name}) created with issuer "{provider.name}"')


@cli.command()
@click.option("--issuer", help="Base OpenID Connect issuer URL")
@click.option("--clientid", help="Client identifier issued by the identity provider")
@click.option("--secret", help="Client secret issued by the identity provider")
@click.option("--name", help="Human readable name of this provider")
def add_identity_provider(name, issuer, clientid, secret):
    "Add a new identity provider"
    try:
        response = httpx.get(f"{issuer}/.well-known/openid-configuration")
        if response.status_code != 200:
            click.echo(
                f"Could not query OpenID configuration from issuer: {issuer}", err=True
            )
            return
    except httpx.ConnectError:
        click.echo(f"Could not connect to OpenID provider: {issuer}")
        return

    with SessionLocal() as database:
        try:
            provider = model.IdentityProvider(
                name=name, issuer=issuer, clientid=clientid, secret=secret
            )
            database.add(provider)
            database.commit()
        except SQLAlchemyError as err:
            database.rollback()
            click.echo(
                f"Could not add provider: {err.orig}", err=True
            )  # pylint: disable=no-member
        else:
            click.echo(f"Added identity provider: {name}")


@cli.group()
def show():
    "Sub-command to display info"


@show.command()
def providers():
    "Show identity providers"
    with SessionLocal() as database:
        for provider in crud.get_identity_providers(database):
            click.echo(f"{provider.id}: {provider.name} | {provider.issuer}")


@show.command()
@click.option("--iss", default=1, help="identity provider")
def login(iss):
    "Show login urls"
    with SessionLocal() as database:
        if (provider := crud.get_provider_by_id(database, iss)) is None:
            click.echo(f"No identity provider with id={iss}", err=True)
            return

        try:
            config = httpx.get(
                f"{provider.issuer}/.well-known/openid-configuration"
            ).json()
        except httpx.RequestError as err:
            click.echo(f"Error while requesting {err.request.url!r}")
        except httpx.HTTPStatusError as err:
            click.echo(
                f"Error response {err.response.status_code} while requesting {err.request.url!r}"
            )
        else:
            click.echo(oidc.login_url(config["authorization_endpoint"], provider))


def vector_level(g_number: str) -> Optional[VectorLevel]:
    "Converts part of the MP-GX-name to a VectorLevel"
    if g_number == "GB":
        vec_level = VectorLevel.BACKBONE
    elif g_number == "G0":
        vec_level = VectorLevel.LEVEL0
    elif g_number == "G1":
        vec_level = VectorLevel.LEVEL1
    else:
        vec_level = None
    return vec_level


def extract_loc(loc: str) -> Tuple[Optional[VectorLevel], int]:
    "Splits the MP-GX-number and returns the VectorLevel and the numberpart"
    split = loc.split("-")
    return (vector_level(split[1]), int(split[2]))


@cli.command(name="import")
@click.argument("csv_path")
@click.argument("gbk_path")
@click.argument("user")
def import_data(csv_path, gbk_path, user):
    """
    Extracts the vector information from a csv file and seperate genbank files
    and adds them to the database.
    """
    with SessionLocal() as database:
        # Lookup user
        if (
            db_user := database.query(model.User).filter(model.User.sub == user).first()
        ) is None:
            click.echo(f"No user with subject: {user}")
            sys.exit(1)

    print(f"Looked up user: {db_user}")
    # read the cvs-file
    csv_content = []

    with open(csv_path, encoding="utf8") as csv_file:
        csv_reader = csv.DictReader(csv_file)
        for item in csv_reader:
            csv_content.append(item)
    csv_file.close()

    files_to_read = [
        (i, entry["Name Genbank file"]) for i, entry in enumerate(csv_content)
    ]

    vecs_to_add: List[Tuple[schemas.VectorIn, schemas.GenbankData]] = []

    for i, gbk_file in files_to_read:
        # Create vector and fill in data from csv file
        loc = extract_loc(csv_content[i]["MP-G- number"])
        date = datetime.strftime(datetime.now(), "%Y-%m-%d")
        if csv_content[i]["Date (extra)"] != "":
            date = csv_content[i]["Date (extra)"]
        children = [
            int(id)
            for id in csv_content[i]["Children ID"]
            .replace("[", "")
            .replace("]", "")
            .split(",")
            if id != ""
        ]
        # Complete GenBank file name
        gbk_file_path = Path(gbk_path) / Path(gbk_file)

        # Raw Genbank content
        genbank = gbk_file_path.read_text()

        if loc[0] in [VectorLevel.LEVEL0, VectorLevel.BACKBONE]:
            genbank_data = convert_gbk_to_vector(gbk_file_path, loc[0])
        else:
            # Convert raw data to GenBank Record
            record = SeqIO.read(gbk_file_path, "genbank")
            # Getting the annotations
            annotations = []
            references = []
            for key, value in record.annotations.items():
                # All annotations are strings, integers or list of them
                # but references are a special case.
                # References are objects that can be deconstructed to
                # an author and a title, both strings.
                if key == "references":
                    for reference in record.annotations["references"]:
                        references.append(
                            schemas.VectorReference(
                                authors=reference.authors, title=reference.title
                            )
                        )
                else:
                    annotations.append(schemas.Annotation(key=key, value=str(value)))

            # Getting the features:
            features = []
            for feature in record.features:
                # Getting the qualifiers of each feature
                new_qualifiers = []
                for key, value in feature.qualifiers.items():
                    new_qualifiers.append(schemas.Qualifier(key=key, value=str(value)))
                features.append(
                    schemas.Feature(
                        type=feature.type,
                        qualifiers=new_qualifiers,
                        start_pos=feature.location.nofuzzy_start,
                        end_pos=feature.location.nofuzzy_end,
                        strand=feature.location.strand,
                    )
                )

            genbank_data = schemas.GenbankData(
                sequence=str(record.seq),
                annotations=annotations,
                features=features,
                references=references,
            )

        vec = schemas.VectorIn(
            location=loc[1],
            name=csv_content[i]["Plasmid name"],
            bacterial_strain=csv_content[i]["Bacterial strain"],
            responsible=csv_content[i]["Responsible"],
            group=csv_content[i]["Group"],
            level=loc[0],
            bsa1_overhang=csv_content[i]["BsaI overhang"],
            selection=csv_content[i]["Selection"],
            cloning_technique=csv_content[i]["DNA synthesis or PCR?"],
            bsmb1_overhang=csv_content[i]["BsmBI overhang"],
            is_BsmB1_free=csv_content[i]["BsmBI free? (Yes/No)"],
            notes=csv_content[i]["Notes"],
            REase_digest=csv_content[i]["REase digest"],
            date=date,
            gateway_site=csv_content[i]["Gateway site"],
            experiment=csv_content[i]["Vector type (MP-G2-)"],
            children=children,
            genbank=genbank,
            annotations=genbank_data.annotations,
            references=genbank_data.references,
        )

        vecs_to_add.append((vec, genbank_data))

    with SessionLocal() as database:
        for (vec, genbank) in vecs_to_add:
            if (
                crud.add_vector(
                    database=database, vector=vec, genbank=genbank, user=db_user
                )
                is not None
            ):
                click.echo(f"Vector '{vec.name}' added.")


if __name__ == "__main__":
    cli()
