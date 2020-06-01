---
layout: post
title:  "Azure Data Factory release pipeline considerations with Azure DevOps"
date:   2020-05-28 10:00:00 -0700
categories: ALM Azure ADF DevOps
---

# Azure Data Factory release pipeline considerations with Azure DevOps

[Azure Data Factory](https://docs.microsoft.com/en-us/azure/data-factory/introduction) (ADF) is the batch processing engine, aka [ETL/ELT](https://en.wikipedia.org/wiki/Extract,_transform,_load) (Extract, Transform and Load) service, available in the Microsoft public cloud. In its v2 version (let's forget about v1), ADF offers orchestration and data movement as a service. It's quite good at that.

The ADF service offers more than an orchestration engine ([pipelines](https://docs.microsoft.com/en-us/azure/data-factory/concepts-pipelines-activities) and [triggers](https://docs.microsoft.com/en-us/azure/data-factory/concepts-pipeline-execution-triggers)) that can call external services in addition to a native data movement engine ([data flows](https://docs.microsoft.com/en-us/azure/data-factory/concepts-data-flow-overview)), it's also a metadata manager ([linked services](https://docs.microsoft.com/en-us/azure/data-factory/concepts-linked-services), [datasets](https://docs.microsoft.com/en-us/azure/data-factory/concepts-datasets-linked-services), a credentials manager (but let's use [Key Vault](https://docs.microsoft.com/en-us/azure/data-factory/store-credentials-in-key-vault) instead) and a web IDE with debugging capabilities ([ADF UI](https://docs.microsoft.com/en-us/azure/data-factory/quickstart-create-data-factory-portal)]). If all that empower single developers to get highly productive quickly, it makes things somewhat confusing when trying to standardize operations for larger teams, and setup proper CI/CD release pipelines.

Here we won't talk about moving data round, but rather planning an enterprise deployment of Azure Data Factory.

## Summary

There are 2 approaches to shipping code in a release pipeline with ADF.

**ARM template deployments** are the ones covered in the [documentation](https://docs.microsoft.com/en-us/azure/data-factory/continuous-integration-deployment). They are supported natively in the ADF UI but only offer all-or-nothing deployments. They rely on the publish process to build JSON definitions of artifacts from the collaboration branch into ARM templates in the adf_publish branch. Since there can be only one pair of collaboration and publish branches, this will impose constraints on the developer experience.

**JSON based deployments** require [custom wiring](https://docs.microsoft.com/en-us/powershell/module/Az.DataFactory/?view=azps-4.1.0) and/or a [3rd party tool](https://github.com/liprec/vsts-publish-adf), but offer a la carte deployments.

## Requirements

1 Project = 1 code repository
2 Developers working on their own features (branches)
4 Scenario
- Release 1 : A + B all the way to production
- Release 2 : moving things in and out of Release candidate
- Release 3 : removing a pipeline artefact from prod
- Release 3 : C + D to test, only D all the way to production, and rebase C
- Hotfix

## Approach 1 : ARM Template deployments

## Approach 2 : JSON based deployments

## Additional constraints

A game changer requirement is related to security. If each developer needs to have a separate identity context (ala passthrough/user authentication in SSIS), then the best approach is to leverage Managed Identity and associate one ADF instance to each developer...

## Design guidance

A factory can only be wired to a single repository

A factory has a single Managed Identity
But a repository can be wired to multiple factories (how to change collaboration branches, no need to change adf_publish)

A factory has a single collaboration/publish branch pair
But a repository can be wired to multiple factories (how to change collaboration branches, no need to change adf_publish)

## Conclusion
