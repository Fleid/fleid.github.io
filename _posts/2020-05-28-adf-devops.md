---
layout: post
title:  "Azure Data Factory release pipeline considerations with Azure DevOps"
date:   2020-05-28 10:00:00 -0700
categories: ALM Azure ADF DevOps
---

# Azure Data Factory release pipeline considerations with Azure DevOps

[Azure Data Factory](https://docs.microsoft.com/en-us/azure/data-factory/introduction) (ADF) is the native batch data processing platform, aka [ETL/ELT](https://en.wikipedia.org/wiki/Extract,_transform,_load) (Extract, Transform and Load) service, available in the Microsoft public cloud. In its v2 version (let's forget about v1), ADF offers orchestration and data movement as a service. It's quite good at that.

ADF offers multiple features that makes if a true cloud native ETL/ELT:

- an **orchestration engine** (via [pipelines](https://docs.microsoft.com/en-us/azure/data-factory/concepts-pipelines-activities) and [triggers](https://docs.microsoft.com/en-us/azure/data-factory/concepts-pipeline-execution-triggers)) that **can call external services** in addition to...
- ...two native **data movement engines**: [mapping data flows](https://docs.microsoft.com/en-us/azure/data-factory/concepts-data-flow-overview) (poor name though if you ask me) running Spark under the covers and [wrangling data flows](https://docs.microsoft.com/en-us/azure/data-factory/wrangling-data-flow-overview) running the Power Query engine under the covers
- a metadata repository ([linked services](https://docs.microsoft.com/en-us/azure/data-factory/concepts-linked-services), [datasets](https://docs.microsoft.com/en-us/azure/data-factory/concepts-datasets-linked-services))
- a credentials manager (but let's use [Key Vault](https://docs.microsoft.com/en-us/azure/data-factory/store-credentials-in-key-vault) instead)
- a web IDE with debugging capabilities: the [ADF UI](https://docs.microsoft.com/en-us/azure/data-factory/quickstart-create-data-factory-portal)

If all that empower single developers to get highly productive quickly, it makes things somewhat confusing when trying to standardize operations for larger teams, and setup proper CI/CD release pipelines.

Here we won't talk about moving data round, but rather planning an enterprise deployment of Azure Data Factory.

## Summary

There are 2 aspects to take into account when deciding how to standardize development practices in ADF:

1. **Development scope** : How to allocate factory instances, taking current ADF constraints into account, it boils down to:
    - [Managed identity](https://docs.microsoft.com/en-us/azure/data-factory/data-factory-service-identity): can your development group all share the same managed identity? Else allocate one ADF instance (= one managed identity) to each developer/team
    - Do you need [triggered runs](https://docs.microsoft.com/en-us/azure/data-factory/concepts-pipeline-execution-triggers#trigger-execution) in development, or is [debugging](https://docs.microsoft.com/en-us/azure/data-factory/iterative-development-debugging) good enough? Runs can only be triggered from the code branch used to publish ARM templates, as such it can become a point of contention and create collisions between those 2 use cases.
1. **Deployment scope** : What is the atomicity of a release:
    - All-or-nothing deployments, the entire factory is deployed every time -> ARM Templates
    - Something more subtle, scoped to specific artifacts -> JSON based deployments

Let's jump into the details.

## Design considerations

We are going to look at the constraints guiding our design, and how to plan our platform around them. This starts with our branching strategy.

### Branching strategy

This being an enterprise deployment, we will use [source control](https://docs.microsoft.com/en-us/azure/data-factory/source-control). ADF integrates with GitHub and Azure DevOps natively. We'll use Azure DevOps in the rest of the article as the [third party tool](https://azurebi-docs.jppp.org/vsts-extensions/azure-data-factory-deploy.html?tabs=docs-open) we might need lives there. 

If we're collaborating on a code base, using Git, then we'll need to think about our [branching strategy](https://docs.microsoft.com/en-us/azure/devops/repos/git/git-branching-guidance?view=azure-devops). Because **most of the issues we can observe in ADF enterprise deployments are solved by making a conscious choice about that branching strategy**, and enforcing it.

I personally recommend the [Atomic Change Flow](https://www.feval.ca/posts/Atomic-Change-Flow-A-simple-yet-very-effective-source-control-workflow/) approach, which is nicely summed up by [Charles Feval](https://twitter.com/cfe84) in this schema of his :

[![Charles' diagram of the Atomic Change Flow, content are detailed in the original article](https://www.feval.ca/img/atomic-flow/Basic-idea.png)](https://www.feval.ca/posts/Atomic-Change-Flow-A-simple-yet-very-effective-source-control-workflow/)

The main difference with the [simple one recommended](https://docs.microsoft.com/en-us/azure/devops/repos/git/git-branching-guidance?view=azure-devops) by Microsoft, is that `master` always stays in sync with Production. We use `release` branches to push code through the delivery pipeline, and only merge them back into `master` when the release is successful.

Please go read the [full article](https://www.feval.ca/posts/Atomic-Change-Flow-A-simple-yet-very-effective-source-control-workflow/). We will see how this will impact ARM Templates based deployments.

### Development scope : Factory instances allocation guidance

These constraints, specific to ADF, will guide how we'll distribute factory instances. Note that since factories only incur costs when used, there should be no impact cost-wise in distributing the same activities on 1 or N factories.

>1. A factory can only be wired to a single repository
>1. Multiples factories can be wired to a single repository
>1. A factory has a single [managed identity](https://docs.microsoft.com/en-us/azure/data-factory/data-factory-service-identity)
>1. A factory has a single `collaboration`/`adf_publish` branch pair. The `collaboration` branch holds JSON artifacts, it is the source branch for the internal build process to generates ("publish") the ARM templates in the `adf_publish` branch
>1. The default `collaboration` branch is recommended to be `master`, but it can be changed
>1. The `adf_publish` branch holds ARM templates from different factories in different subfolders
>1. Triggers can only be started from the collaboration branch
>1. We do not merge ARM Templates. Any collaboration must be done in JSON land

Point **1** will give us that we should **distribute factory instances on repositories boundaries**. If we allocate repositories per *{ team x project x solution }*, then each of these should get at least a distinct factory instance.

Points **3** and **2** will give us that we should **also distribute factory instances on data sources authentication boundaries**. If we generate individual credentials to each developers for data sources and sinks, then each developer will need a data factory instance to get their own managed identity. All of these factories are tied to the same repository, code is moved between branches via pull requests. If we're okay with those credentials being shared in a team, then a shared factory instance will do fine. 

Points **7**, **4** and **2** will give us that we should **also distribute factory instances to prevent collisions of triggered runs with the release pipeline**. If the team is fine with debugging (no triggers) there is no need here. If the team needs to trigger runs but is okay sharing an instance together then dedicate a factory for releasing (wired to the CI/CD pipeline) in addition to the development one (used for triggers). If each developer needs to trigger runs independently then allocate a factory instance per developer and add one instance for releasing. All of these factories are tied to the same repository, code is moved between branches via pull requests.

Schema of examples

The other points will guide our implementations below.

### Deployment scope : atomicity of a release

ADF artifacts are defined in a JSON format. This first aspect is about choosing to deploy these artifacts via ARM templates (default approach, we will need to "build" those templates) or to publish them directly.

**ARM templates deployments** are the ones covered in the [documentation](https://docs.microsoft.com/en-us/azure/data-factory/continuous-integration-deployment). They are supported natively in the ADF UI but only offer **all-or-nothing deployments**. They rely on the integrated **publish** process that build ARM Templates (in the `adf_publish` branch) from the JSON definitions of artifacts in the collaboration branch. Since there can be only one pair of collaboration-publish branches, this will impose constraints on the developer experience. We'll dig into that.

**JSON based deployments** require [custom wiring](https://docs.microsoft.com/en-us/powershell/module/Az.DataFactory/?view=azps-4.1.0) and/or a [3rd party tool](https://github.com/liprec/vsts-publish-adf), but offer a-la-carte deployments. It's an involved setup that brings a solution to a problem that in my opinion can be avoided by properly scoping and allocating ADF instances instead - see below for that.

## Implementations

A game changer requirement is related to security. If each developer needs to have a separate identity context (ala passthrough/user authentication in SSIS), then the best approach is to leverage Managed Identity and associate one ADF instance to each developer...

1 Project = 1 code repository
2 Developers working on their own features (branches)
4 Scenario

- Release 1 : A + B all the way to production
- Release 2 : moving things in and out of Release candidate
- Release 3 : removing a pipeline artefact from prod
- Release 3 : C + D to test, only D all the way to production, and rebase C
- Hotfix

### Shared factory with ARM template deployments

### Shared factory with JSON based deployments

### Individual factories with ARM templates deployments

### Individual factories with JSON based deployments

## Conclusion

Alternatives