---
layout: post
title:  "Retrieving Azure KeyVault secrets with PowerShell in Azure DevOps Pipelines"
date:   2020-01-07 10:00:00 -0700
categories: ALM Azure ASA DevOps
---

# Retrieving Azure Key Vault secrets with PowerShell in Azure DevOps pipelines

## Context

I [recently stumbled](https://www.eiden.ca/asa-alm-104/) on some issues while trying to retrieve secrets stored in [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/) from a [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/overview?view=powershell-7) script running in [Azure DevOps Pipelines](https://azure.microsoft.com/en-us/services/devops/pipelines/).

I was [building a CI/CD pipeline](https://www.eiden.ca/asa-alm-100/) for an [Azure Stream Analytics](https://docs.microsoft.com/en-us/azure/stream-analytics/stream-analytics-introduction) job in Azure DevOps. For that I needed to perform **ARM Template deployments** via PowerShell in the release phase. With my secrets stored in Key Vault, I needed to get access to their values in PowerShell to update those ARM template files. Figuring out the syntax was not as easy as I expected.

![Schema focusing on the release pipeline](https://github.com/Fleid/fleid.github.io/blob/master/_posts/201912_asa_alm101/asa_alm104_goal.png?raw=true)

*[figure 1 - Schema of the release pipeline](https://github.com/Fleid/fleid.github.io/blob/master/_posts/201912_asa_alm101/asa_alm104_goal.png?raw=true)*

What should be a straightforward scenario takes a bit of planning. The main point of contention being that Azure Pipelines offer different capabilities depending on 2 factors:

- [the pipeline experience](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/pipelines-get-started?view=azure-devops&tabs=yaml):  YAML vs Classic
- the script execution type for its [Azure PowerShell](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/deploy/azure-powershell?view=azure-devops) task: inline vs file script

## TL/DR

Here are the wirings that work, see below for details on each syntax:

- **YAML** experience / **Inline** script
  - Input macro
  - Mapped environment variable (recommended in the doc)
  - PowerShell Get-AzKeyVaultSecret

- **YAML** experience / **File Path** script
  - Argument / Parameter mapping
  - Mapped environment variable  (recommended in the doc)
  - PowerShell Get-AzKeyVaultSecret

- **Classic** experience / **Inline** script
  - Input macro
  - PowerShell Get-AzKeyVaultSecret

- **Classic** experience / **File Path** script
  - Argument / Parameter mapping
  - PowerShell Get-AzKeyVaultSecret

## Options

**Before trying anything else**, it's required to create a variable group linked to the Key Vault (see [middle section](https://www.eiden.ca/asa-alm-104/) if necessary).

To be noted:

> When trying to link the KeyVault in the Variable Group, the **authentication** process can hang indefinitely. It can be solved in KeyVault, by manually creating an **access policy** for the Azure DevOps project application principal (service account) with List/Get permissions on Secrets. The application principal id can be found in the Azure DevOps project **settings** (bottom left), **Service Connections** tab, editing the right subscription and going `use the full version of the service connection dialog`. It should be under `Service principal client ID`.

### Input Macro syntax

Only available inline. With the variable group `myVariableGroup` linked to KeyVault, giving access to the secret `kvTestSecret`.
[More info](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#set-variables-in-pipeline)

#### YAML experience

The inline script can reference the secret directly via : `$(kvTestSecret)`.

```YAML
trigger:
  - master
  
pool:
  vmImage: 'windows-latest'

variables:
- group: myVariableGroup
  
steps:

- task: AzurePowerShell@4
  displayName: 'Azure PowerShell script - inline'
  inputs:
    azureSubscription: '...'
    ScriptType: 'InlineScript'
    Inline: |
      # Using an input-macro:
      Write-Host "Input-macro from KeyVault VG: $(kvTestSecret)"
```

#### Classic experience

In the classic experience, the variable group must be declared in the `Variables` tab beforehand.
Then the inline script can reference the secret directly via : `$(kvTestSecret)`.

![Screenshot of Azure DevOps : Input macro syntax for inline script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/macro_inline_classic.png?raw=true)

*[figure 2 - Screenshot of Azure DevOps : Input macro syntax for inline script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/macro_inline_classic.png?raw=true)*

### Inherited environment variable

This syntax is the default for variables **not** coming from Key Vault (local variable and default variable groups). It will **not** return Key Vault secrets in any configuration.

With the variable group `myDefaultVariableGroup` **not** linked to KeyVault, holding the variable `normalVariable`. Also with the variable `localVariable`.

#### YAML

```YAML

trigger:
  - master
  
pool:
  vmImage: 'windows-latest'

variables:
- group: myDefaultVariableGroup
- name: localVariable
  value: myvalue
  
steps:

- task: AzurePowerShell@4
  displayName: 'Azure PowerShell script - inline'
  inputs:
    azureSubscription: '...'
    ScriptType: 'InlineScript'
    Inline: |
      # Using the env var:
      Write-Host "Inherited ENV from normal VG: $env:normalVariable"
      Write-Host "Inherited ENV from local variable: $env:localVariable"
    azurePowerShellVersion: 'LatestVersion'
```

#### Classic experience

In the classic experience, both the local variable and the variable group must be declared in the `Variables` tab beforehand.
Then the inline script can reference the variables directly via : `$env:normalVariable`.

NB : The variable name will be altered as follow [ref](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#understand-variable-syntax):

> Name is upper-cased, . replaced with _, and automatically

![Screenshot of Azure DevOps : Inherited environment variable for inline script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/inherited_inline_classic.png?raw=true)

*[figure 2 - Screenshot of Azure DevOps : Inherited environment variable for inline script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/inherited_inline_classic.png?raw=true)*

### Mapped environment variable

### Argument / Parameter mapping

### PowerShell Get-AzKeyVaultSecret

## Resources

Azure Pipelines >

- [Variable Groups](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=yaml)
- [Variable > Syntax](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#understand-variable-syntax)
- [Variable > Set Secret Variables](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#secret-variables)
- [Azure PowerShell Task](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/deploy/azure-powershell?view=azure-devops#samples)
