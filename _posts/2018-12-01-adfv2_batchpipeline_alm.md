---
layout: post
title:  "Batch Pipeline Project Review : Developer Experience and ALM"
date:   2018-12-01 11:00:00 -0700
categories: architecture ADFv2 Azure batch
---

# Azure Data Factory v2 - Batch Pipeline Project Review : Developer Experience and ALM

This is article is part of a series:

1. [Architecture discussion](https://fleid.github.io/adfv2_batchepipeline/201812_adfv2_batchpipeline_adr)
2. **ALM and Infrastructure** *<- you are here, Comments / PR are [welcome](https://github.com/Fleid/fleid.github.io/blob/master/adfv2_batchepipeline/201812_adfv2_batchpipeline_alm.md)*
3. [Notable implementation details](https://fleid.github.io/adfv2_batchepipeline/201812_adfv2_batchpipeline_implementation)

- Author : Florian Eiden
  - [blog](https://fleid.net/) / [twitter](https://twitter.com/fleid_bi?lang=en) / [linkedin](https://ca.linkedin.com/in/fleid) / [github](https://github.com/fleid)
  - Disclaimer : I'm a Microsoft employee at the time of writing
- Publication : 2018-12
  - Last update : 2019-01-14

## General environment: Azure

We will implement the solution on [Azure](https://azure.microsoft.com/en-us/), the [public cloud](https://en.wikipedia.org/wiki/Cloud_computing#Public_cloud) platform from Microsoft. All the required services can run on a [free Azure account](https://azure.microsoft.com/free).

### Tools

To provision all the resources (Data factories, storage accounts, VMs...), we will use the [Azure portal](https://portal.azure.com) (your [color scheme](https://docs.microsoft.com/en-us/azure/azure-portal/azure-portal-change-theme-high-contrast) may vary):

![Screenshot of the Azure Portal](https://github.com/Fleid/fleid.github.io/blob/master/adfv2_batchepipeline/201812_adfv2_batchpipeline/azurePortal.png?raw=true)

There we will provision one resource group per project/environment. We will also use [tags](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-using-tags) to organize resources.

Once the factory is [created](https://docs.microsoft.com/en-us/azure/data-factory/quickstart-create-data-factory-portal#create-a-data-factory), all of the fun will happen in the [Data Factory portal](https://adf.azure.com) (even [debugging](https://docs.microsoft.com/en-us/azure/data-factory/iterative-development-debugging)):

![Screenshot of the Azure Portal](https://github.com/Fleid/fleid.github.io/blob/master/adfv2_batchepipeline/201812_adfv2_batchpipeline/adfPortal.png?raw=true)

We will use **Azure Storage Explorer** to move files to/from blob stores and file shares. It's a [free download](https://azure.microsoft.com/en-us/features/storage-explorer/) and works on Windows, macOS and Linux.

To develop the **Logic App** used for deleting files, we can either use the Azure Portal ([best option](https://docs.microsoft.com/en-us/azure/logic-apps/quickstart-create-first-logic-app-workflow) to get started), Visual Studio ([not really recommended](https://marketplace.visualstudio.com/items?itemName=VinaySinghMSFT.AzureLogicAppsToolsforVisualStudio-18551#review-details) at the moment) or Visual Studio Code ([no visual interface](https://docs.microsoft.com/en-us/azure/logic-apps/quickstart-create-logic-apps-visual-studio-code)).

Finally, we can leverage **PowerShell** (via the [ISE](https://docs.microsoft.com/en-us/powershell/scripting/core-powershell/ise/introducing-the-windows-powershell-ise?view=powershell-6) or the [Cloud Shell](https://docs.microsoft.com/en-us/azure/azure-resource-manager/powershell-azure-resource-manager#launch-azure-cloud-shell)) and the [Azure modules](https://docs.microsoft.com/en-us/powershell/azure/install-azurerm-ps) if things need to get [scripted](https://docs.microsoft.com/en-us/powershell/module/azurerm.datafactories/).

### Continuous Integration and Deployment (CI/CD)

[Azure DevOps](https://azure.microsoft.com/en-us/services/devops/) (Formerly VSTS / Visual Studio Online) will be used for source control ([Azure Repos](https://azure.microsoft.com/en-us/services/devops/repos/)) and to manage the deployment pipeline ([Azure Pipeline](https://azure.microsoft.com/en-us/services/devops/pipelines/)).

Using Azure DevOps will allow us to do [CI/CD directly from the Data Factory portal](https://docs.microsoft.com/en-us/azure/data-factory/continuous-integration-deployment).

The other asset that needs attention here is the **Logic App** used for deletion. At the time of writing there is no obvious way to treat the Logic App as a first class citizen in terms of ALM in our project. There is no easy way to develop, version and deploy Logic App code to multiple environments with parameters (connection strings...). Logic Apps are versioned in the service, but there is no native notion of environments. That's why in this project we will treat the Logic App as an infrastructure component, deployed once in every environment and updated rarely, putting no business logic into it.

### Monitoring

During development, we will monitor ADFv2 pipeline runs [visually](https://docs.microsoft.com/en-us/azure/data-factory/monitor-visually#list-view-monitoring) in the Data Factory portal.

Once deployed we will also use Azure Monitor [Metrics](https://docs.microsoft.com/en-us/azure/data-factory/monitor-using-azure-monitor#metrics) in the [metrics explorer](https://docs.microsoft.com/en-us/azure/monitoring-and-diagnostics/monitoring-metric-charts)) and build [dashboards](https://docs.microsoft.com/en-us/azure/azure-portal/azure-portal-dashboards) with them. We'll also define [alerts](https://azure.microsoft.com/en-us/adfv2_batchepipeline/create-alerts-to-proactively-monitor-your-data-factory-pipelines/). If need be, this data can be persisted using [Log Analytics](https://docs.microsoft.com/en-us/azure/data-factory/monitor-using-azure-monitor)).

## Infrastructure

Infrastructure components are the assets that are provisioned once in each environment (Development/Integration/Production), and not included in the Deployment pipeline. We won't script any of the infrastructure provisioning in that specific project, but it can be done via [ARM templates](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-overview#template-deployment).

We won't discuss the provisioning of the VMs, VNet and [other required bits](https://datasavvy.me/2019/01/11/the-necessary-extras-that-arent-shown-in-your-azure-bi-architecture-diagram/), as it should be pretty straightforward operations.

### ADFv2 Assets

We will follow the [CI/CD tutorial](https://docs.microsoft.com/en-us/azure/data-factory/continuous-integration-deployment) to set up the Factory itself in all 3 environments. This will result in the creation of 3 factories in the portal.

The self-hosted IR can either be [shared among environments](https://azure.microsoft.com/en-us/adfv2_batchepipeline/sharing-a-self-hosted-integration-runtime-infrastructure-with-multiple-data-factories/), or we'll create one per environment if need be.

In a factory we will create the following artifacts:

- Integration Runtime
  - Self-hosted IR ([how-to](https://docs.microsoft.com/en-us/azure/data-factory/create-self-hosted-integration-runtime#install-and-register-self-hosted-ir-from-the-download-center))
- Linked Services
  - [sFTP connector](https://docs.microsoft.com/en-us/azure/data-factory/connector-sftp)
  - **File Store A**, type Azure File Storage, **self-hosted** IR (reaching in the VNet), authentication via Password (should be Key Vault instead)
  - **File Store B**, type Azure File Storage, **auto resolve** IR (Parquet conversion), authentication via Password (should be Key Vault instead)
  - **Blob Store**, type Azure Blob Store, auto resolve IR, authentication via MSI ([how-to](https://docs.microsoft.com/en-ca/azure/data-factory/connector-azure-blob-storage#managed-identity), [from](https://toonvanhoutte.wordpress.com/2018/12/05/delete-blobs-in-azure-data-factory-by-leveraging-msi/))

### Logic App

At the time of writing, Logic Apps can't be defined as linked services in ADFv2. This is an issue when deploying to multiple environments, as each one will need to use its own Logic App endpoint: we can't just hard code that endpoint value in the Web Activity using it.

We'll address that shortcoming by using a pipeline parameter to pass the Logic App URL to the activity that needs it. That way we will be able to change the endpoint at runtime or in the CI/CD pipeline (via the parameter default value).

In terms of implementation of that Logic App, we will be using [that strategy](https://kromerbigdata.com/2018/03/15/azure-data-factory-delete-from-azure-blob-storage-and-table-storage/):

![Screenshot of the Logic App visual editor](https://github.com/Fleid/fleid.github.io/blob/master/adfv2_batchepipeline/201812_adfv2_batchpipeline/logicAppCanvas.png?raw=true)

The trigger is an HTTP request, the following step is an **Azure File Storage** > **Delete File** action. We define a parameter in the Request Body (using the *sample payload to generate schema* option): the path to the file to be deleted. We then use that parameter as the target of the Delete File action.

To call that Logic App in a Data Factory pipeline, we will copy/paste the **HTTP POST URL** from the Logic App designer into a Web Activity URL. The Web Activity method will be POST, and we will build its body using an expression (generating the expected JSON syntax inline, see below).

## Up next

[Implementation Details](https://fleid.github.io/adfv2_batchepipeline/201812_adfv2_batchpipeline_implementation)