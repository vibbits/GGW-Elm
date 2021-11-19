---
title: Software Design Document
author: Kevin De Pelseneer
reviewer:
tags: kevin-depelseneer,requirements,gww
---

# Software Design Document

## Overview

Software requirements can be found [here](docs/requirements.md).

## Audience

- Current developers
- Future developers within VIB
- Open source contributors
- Operations (person deploying)
- Customers
- Internship supervisors

## Glossary of terminology
- Include references where it makes sense

## Constraints

- Time. Hard deadline for delivery of satisfactory software is:
> The end of the traineeship, June 2022?

## System architecture: potential solutions

- Describe rejected architectures and reasons for rejecting them.
> 

## System architecture

- Figure/diagram of the whole system
- Components
> - User Interface
> - Admin Interface
> - API
> - Database
> - Reusable Core Application that can be implemented in other projects.
- Responsibilities
> - Group Sven Eyckerman:
>    - Testing the application
>    - Providing the data
- Data flow

## Data Structures

#### User
- name
- OpenID Connect issuer (maybe, depends if we support multiple issuers)
- OpenID Connect subject (unique id from an issuer)

#### Level 0 construct or donor vectors
- name
- MP-G0-number
- Sequence
- Length (Not strictly necessary: can be calculated from sequence length)
- Annotations (from genbank)
- Features (from genbank) (can be together with annotations)
- BSA I Overhang
- Owner / Designer
- Remarks
- Constraints?

#### Backbones or destination vectors
- name
- MP-G0-number
- Level => Can it be used for level 0, 1 or 2?
- Sequence
- Length (Not strictly necessary: can be calculated from sequence length)
- Annotations (from genbank)
- Features (from genbank) (can be together with annotations)

#### Level 1 construct
- name
- MP-G1-number
- [ level 0 elements ] in a list? Store an object?
- Backbone

#### Access Control
- White list

## User interface

- Wireframes
- Screenshots

## Testing plan

- User A/B testing ...
- Acceptance testing by Sven/Delphine/...

## Development and documentation methodology

## Goals

1. Deliver a useful GUI for Sven and his lab
2. Publish the core component as a seperately usable library locally and in WebAssembly
3. Publish JavaScript bindings to the **core component** to NPM
4. Publish user interface components to NPM

## Milestones

* 2021-Nov-12: Finalise first draft of SDD (+ 1 week)
* 2021-Dec-10: Initial Demo with Sven and Delphine (+ 4 days)
* 2021-Dec-13: Mid-project review meeting
* 