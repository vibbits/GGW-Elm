"""
GGW server administration console command.
This is intended to be run for administration tasks such as
updating the database schema, adding an admin user,
adding an identity provider, etc.
"""

from pathlib import Path
import click
import httpx
import csv
import json
from Bio import SeqIO
from sqlalchemy.exc import SQLAlchemyError

from typing import List
from app.model import Vector, Annotation, Reference, Qualifier, Feature

from app.database import SessionLocal
from app import model, crud, oidc, schemas


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


@cli.command()
@click.argument("csv_path")
@click.argument("gbk_path")
def import0(csv_path, gbk_path):
    # read the cvs-file
    csv_content = []

    with open(csv_path) as csv_file:
        csv_reader = csv.DictReader(csv_file, delimiter=";")
        for item in csv_reader:
            csv_content.append(item)
    csv_file.close()

    files_to_read = [
        (i, entry["Name Genbank file"]) for i, entry in enumerate(csv_content)
    ]

    vec_list = []

    for i, gbk_file in files_to_read:
        # Create vector and fill in data from csv file
        vec = Vector()
        vec.name = csv_content[i]["Plasmid name"]
        vec.bacterial_strain = csv_content[i]["Bacterial strain"]
        vec.mpg_number = csv_content[i]["MP-G0- number"]
        vec.responsible = csv_content[i]["Responsible"]
        vec.group = csv_content[i]["Group"]
        vec.bsa1_overhang = csv_content[i]["BsaI overhang"]
        vec.selection = csv_content[i]["Selection"]
        vec.cloning_technique = csv_content[i]["DNA synthesis or PCR?"]
        vec.is_BsmB1_free = csv_content[i]["BsmBI free? (Yes/No)"]
        vec.notes = csv_content[i]["Notes"]
        vec.REase_digest = csv_content[i]["REase digest"]

        # Reading the sequence from the genbank file
        gbk_file_path = Path(gbk_path) / Path(gbk_file)
        record = SeqIO.read(gbk_file_path, "genbank")
        vec.sequence = str(record.seq)
        vec.sequence_length = len(vec.sequence)

        # Getting the annotations
        annotations = []
        references = []
        for k, v in record.annotations.items():
            # All annotations are strings, integers or list of them but references are a special case.
            # References are objects that can be deconstructed to an author and a title, both strings.
            if k == "references":
                for reference in record.annotations["references"]:
                    references.append(
                        Reference(authors=reference.authors, title=reference.title)
                    )
            else:
                annotations.append(Annotation(key=k, value=str(v)))

        vec.annotations = annotations
        vec.references = references

        # Getting the features:
        features = []
        for feature in record.features:
            # Getting the qualifiers of each feature

            new_qualifiers = []
            for k, v in feature.qualifiers.items():
                new_qualifiers.append(Qualifier(key=k, value=str(v)))
            features.append(
                Feature(
                    type=feature.type,
                    qualifiers=new_qualifiers,
                    start_pos=feature.location.nofuzzy_start,
                    end_pos=feature.location.nofuzzy_end,
                    strand=feature.location.strand,
                )
            )

        vec.features = features

        # Append to vec_list
        vec_list.append(vec)

    with SessionLocal() as database:
        for vec in vec_list:
            crud.add_vector(database=database, vector=vec)
            click.echo(f"Vector '{vec.name}' added.")


@cli.command()
@click.argument("json_file", nargs=-1)
@click.option("--iss", default=1, help="identity provider")
def json_to_vec_list(json_file, iss):
    vec_list: List[Vector] = []

    # read the json-file
    with open(json_file[0], "r") as jf:
        json_string = json.load(jf)
        for item in json_string:
            # Reading the annotations
            ann_list: List[Annotation] = []
            for ann in item["annotations"]:
                ann_list.append(Annotation(key=ann["key"], value=ann["value"]))

            # Reading the references
            ref_list: List[Reference] = []
            for ref in item["references"]:
                ref_list.append(Reference(authors=ref["authors"], title=ref["title"]))

            # Reading the features
            feat_list: List[Feature] = []
            for feat in item["features"]:

                # Reading the qualifiers
                qual_list: List[Qualifier] = []
                for qual_key, qual_val in feat["qualifiers"]:
                    qual_list.append(Qualifier(key=qual_key, value=qual_val))

                # appending the features to the list
                feat_list.append(
                    Feature(
                        type=feat["type"],
                        qualifiers=qual_list,
                        start_pos=feat["start_pos"],
                        end_pos=feat["end_pos"],
                        strand=feat["strand"],
                    )
                )

            vec_list.append(
                Vector(
                    name=item["name"],
                    bacterial_strain=item["bacterial_strain"],
                    mpg_number=item["mpg_number"],
                    responsible=item["responsible"],
                    group=item["group"],
                    bsa1_overhang=item["bsa1_overhang"],
                    selection=item["selection"],
                    cloning_technique=item["cloning_technique"],
                    is_BsmB1_free=item["is_BsmB1_free"],
                    notes=item["notes"],
                    REase_digest=item["REase_digest"],
                    sequence=item["sequence"],
                    sequence_length=item["sequence_length"],
                    annotations=ann_list,
                    references=ref_list,
                    features=feat_list,
                )
            )
    jf.close()

    with SessionLocal() as database:
        if (provider := crud.get_provider_by_id(database, provider_id=iss)) is None:
            click.echo(f"No identity provider with id={iss}", err=True)
            return

        for vec in vec_list:
            crud.add_vector(database=database, vector=vec)
            click.echo(f"Vector '{vec.name}' added.")


if __name__ == "__main__":
    cli()
