---
title: Software Requirements Document
description: Requirements and user stories for the Golden-Gate cloning shop project
tags: kevin-depelseneer,requirements
---

# Requirements Document

* Project: Golden Gateway
* Date: 27-Sept-2021
* Author: Kevin De Pelseneer

## Context
The project aims to provide a simple tool to assemble DNA sequences into sequences that can be used by the research community. A final goal would be a website providing a 'store' functionality where a user could design their destination vector(s), purchace, and order their manufacture.

### Background on Golden Gate cloning

Golden gateway is a cloning method to assemble multiple fragments simultaneously into one construct (a "destination vector").

The inputs are a "donor vector" (or backbone) a selection of inserts,
some of which are selected from a pre-defined list, and one of which (the
gene of interest")

**The level0 fragments (inserts and backbones)**

* Have specific overhangs at both sides. These are the options:
  * AB
  * AG
  * BC
  * BG
  * CD
  * CG
  * DE
  * DG
  * EF
  * EG
  * FG

#### Golden gate enzymatic reaction

1. Level one reactions:
* Multiple inserts and a backbone (= destination vector) are selected from a catalog
* Digestion of the destination vector and the inserts
* Ligate the digested inserts with the digested destination vector


2. Level two reactions:
Two or three transcript units or level 1 constructs are combined with a backbone (which are different from level-1 backbones) and form a level 2 construct similarly to the level 1 constructs => Final product

![Golden gate cloning](https://upload.wikimedia.org/wikipedia/commons/thumb/f/f1/Golden_Gate_assembly.svg/800px-Golden_Gate_assembly.svg.png)

### Intensions
* Develop a UI that visually displays the inserts and backbones (user doesn't need to have programming knowledge)
* Make a database scheme for the storage of the inserts and the destination vectors

### Goals
* Develop a GUI for building level 1 constructs for use within the lab setting.
* Abstract the core functionality for inclusion in a future web shop.
* Develop a shop integrating with a payment service and robots to manufacture the designed constructs.

### Non-goals

### Environment
* Users may be working in a wet lab and wearing gloves
* Likely to be used on mobile devices (phones and tablets)


## Assumptions

* Most of the application, including the database and the GUI will be thrown away when building the final web store.

## Users

* Customer: a user of the application that wishes to design a level-1 construct.
* Technician: a member of the lab that may with to update or edit the database of available donor vectors and inserts.
* Admin: Application administrator who may wish to deploy updates, make backups, print invoices.
* Developer: Software developer that may wish to debug or instrument an application, or make changes to source code.

## Functional requirements

* As a _customer_, I want to be able to view or search a list of available inserts (categorised) so that I can easily customise my design.
* As a _customer_, I want to be able to see (visualise) the current state of my design to facilitate rapid design iteration.
* As a _customer_, I want to be able to save my designed level-1 construct to Genbank format.
* As a _customer_, I want my level-1 construct output to include the annotations for the input level-0 constructs because ...?
* As a _customer_, I want to be able to update or add constructs (every two days) regularily so that I can correct errors / build new constructs.
* As a _customer_, I want to be able to use the application on a mobile device for convenience.

* As a _technician_, I want to be able to add or edit annotations[^1] for level-0 constructs.
* As a _technician_, I want to be able to assemble pre-donor fragments into level-0 constructs so that I can provide new level-0 constructs to _customers_.
* As a _technician_, I want to be able to edit level-0 constructs to correct errors.

* As an _admin_, I want to be able to distribute the application to customers so that customers can use it.
* As an _admin_, I want to be able to make database backups so that the risk of data loss in minimised.

* As a _developer_, I want to be able to rapidly experiment with GUI design so that I can optimise for customer speed and comfort.


## Non-functional requirements

* Performance
* Concurrent Database access.
* Quality (test coverage, Linting)
    * At least 80% test coverage on the core module.
    * No compiler warnings
    * No linter warnings
    * Integration tests with browser and desktop platforms.
    * Interface is "well documented".
* Core should be GPLv3+

## Open questions
* Are there any *"rules"* that should be checked during the analysis? Does it have to show warnings in some cases?


## References
* http://scikit-bio.org/docs/0.5.2/generated/skbio.io.format.genbank.html#r336
* https://www.insdc.org/files/feature_table.html


[^1]: One or potentially more than 1? And what do they look like?