---
layout: post
title:  "Retrieving Azure KeyVault secrets with PowerShell in Azure DevOps Pipelines"
date:   2020-01-07 10:00:00 -0700
categories: ALM Azure ASA DevOps
---

# Retrieving Azure Key Vault secrets with PowerShell in Azure DevOps pipelines

## 1. Context

I [recently](https://www.eiden.ca/asa-alm-104/) got confused while trying to retrieve secrets stored in [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/) from a [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/overview?view=powershell-7) script running in [Azure DevOps Pipelines](https://azure.microsoft.com/en-us/services/devops/pipelines/). I could not figure out the proper syntax to do so (and I was [not alone](https://stackoverflow.com/questions/58607998/dynamicallly-get-keyvault-secret-in-azure-devops-powershell-script)).

This was for the [CI/CD pipeline](https://www.eiden.ca/asa-alm-100/) of my [Azure Stream Analytics](https://docs.microsoft.com/en-us/azure/stream-analytics/stream-analytics-introduction) project hosted in Azure DevOps. At some point it needed to perform some **ARM Template deployments** via a PowerShell task, and figuring out the syntax to get access to the secrets in the script was not as easy as I expected.

![Schema focusing on the release pipeline](https://github.com/Fleid/fleid.github.io/blob/master/_posts/201912_asa_alm101/asa_alm104_goal.png?raw=true)

*[figure 1 - Schema of the release pipeline](https://github.com/Fleid/fleid.github.io/blob/master/_posts/201912_asa_alm101/asa_alm104_goal.png?raw=true)*

What should have been a straightforward scenario took a bit of planning. Now I know that depending on 2 factors you can leverage different capabilities which come with different syntaxes. Those 2 factors being:

- the Azure Pipelines [experience](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/pipelines-get-started?view=azure-devops&tabs=yaml) in Build and Release:  YAML vs Classic
- the script type of the [Azure PowerShell](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/deploy/azure-powershell?view=azure-devops) task: inline vs file script

## 2. TL/DR

Here are the wirings that work, see below for details on each syntax:

![Schema of the available options](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/recap.png?raw=true)

*[figure 2 - Schema of the available options](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/recap.png?raw=true)*

- **YAML** experience / **Inline** script
  - Input macro
  - Mapped environment variable (recommended in the doc but YAML not available in Release)
  - PowerShell Get-AzKeyVaultSecret

- **YAML** experience / **File Path** script
  - Argument / Parameter mapping
  - Mapped environment variable  (recommended in the doc but YAML not available in Release)
  - PowerShell Get-AzKeyVaultSecret

- **Classic** experience / **Inline** script
  - Input macro
  - PowerShell Get-AzKeyVaultSecret

- **Classic** experience / **File Path** script
  - Argument / Parameter mapping
  - PowerShell Get-AzKeyVaultSecret

## 3. Options

**Before anything else**, we need to create a variable group linked to the Key Vault we plan to use. For that see the [middle section of that article](https://www.eiden.ca/asa-alm-104/).

To be noted:

> When trying to link the KeyVault in the Variable Group, the **authentication** process can hang indefinitely. It can be solved in KeyVault, by manually creating an **access policy** for the Azure DevOps project application principal (service account) with List/Get permissions on Secrets. The application principal id can be found in the Azure DevOps project **settings** (bottom left), **Service Connections** tab, editing the right subscription and going `use the full version of the service connection dialog`. It should be under `Service principal client ID`.

### 3.1 Input macro

**Only available inline**, [more info](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#set-variables-in-pipeline).

With the variable group `myVariableGroup` linked to KeyVault, giving access to the secret `kvTestSecret`.

#### 3.1.1 Input macro : YAML experience

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

#### 3.1.2 Input macro : Classic experience

In the classic experience, the variable group must be declared in the `Variables` tab beforehand.
Then the inline script can reference the secret directly via : `$(kvTestSecret)` (as in `Write-Host "Input-macro from KeyVault VG: $(kvTestSecret)"`).

![Screenshot of Azure DevOps : Input macro syntax for inline script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/macro_inline_classic.png?raw=true)

*[figure 3 - Screenshot of Azure DevOps : Input macro syntax for inline script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/macro_inline_classic.png?raw=true)*

### 3.2 Inherited environment variable

This syntax is the default for variables **not** coming from Key Vault (local variable and default variable groups). It will **not** return Key Vault secrets in any configuration.

With the variable group `myDefaultVariableGroup` **not** linked to KeyVault, holding the variable `normalVariable`. Also with the variable `localVariable`.

#### 3.2.1 Inherited Env : YAML experience

For Inline and File script the syntax is similar : `$env:normalVariable` (as in `Write-Host "Inherited ENV from normal VG: $env:normalVariable"`)

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

- task: AzurePowerShell@4
  displayName: 'Azure PowerShell script - file path'
  inputs:
    azureSubscription: '...'
    ScriptType: 'FilePath'
    ScriptPath: '$(Build.Repository.LocalPath)/myScript.ps1'
    azurePowerShellVersion: 'LatestVersion'
```

#### 3.2.2 Inherited Env : Classic experience

In the classic experience, both the local variable and the variable group must be declared in the `Variables` tab beforehand.
Then for Inline and File script the syntax is similar : `$env:normalVariable` (as in `Write-Host "Inherited ENV from normal VG: $env:normalVariable"`).

NB : The variable name will be altered as follow ([ref](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#understand-variable-syntax)):

> Name is upper-cased, . replaced with _

![Screenshot of Azure DevOps : Inherited environment variable for inline script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/inherited_inline_classic.png?raw=true)

*[figure 2 - Screenshot of Azure DevOps : Inherited environment variable for inline script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/inherited_inline_classic.png?raw=true)*

### 3.3 Mapped environment variable

**Only available via the YAML experience.** This is the [recommended solution](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#secret-variables) in YAML.

With the variable group `myVariableGroup` linked to KeyVault, giving access to the secret `kvTestSecret`.
The inline script can reference the secret directly via : `$env:MY_MAPPED_ENV_VAR_KV` (as in `Write-Host "Mapped ENV from KeyVault VG: $env:MY_MAPPED_ENV_VAR_KV"`).

The key statement here being the `env:` [parameter](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema?view=azure-devops&tabs=schema#task) required at each task.

```YAML
trigger:
  - master
  
pool:
  vmImage: 'windows-latest'

variables:
- group: myVariableGroup
  
steps:

- task: AzurePowerShell@4
  env: 
    MY_MAPPED_ENV_VAR_KV: $(kvTestSecret)
  displayName: 'Azure PowerShell script - inline'
  inputs:
    azureSubscription: '...'
    ScriptType: 'InlineScript'
    Inline: |
      # Using the env var:
      Write-Host "Mapped ENV from KeyVault VG: $env:MY_MAPPED_ENV_VAR_KV"
    azurePowerShellVersion: 'LatestVersion'

- task: AzurePowerShell@4
  env: 
    MY_MAPPED_ENV_VAR_KV: $(kvTestSecret)
  displayName: 'Azure PowerShell script - file path'
  inputs:
    azureSubscription: '...'
    ScriptType: 'FilePath'
    ScriptPath: '$(Build.Repository.LocalPath)/myScript.ps1'
    azurePowerShellVersion: 'LatestVersion'
```

### 3.4 Argument / Parameter mapping

**Only available in File Path experience**.

#### 3.4.1 Argument : YAML experience

#### 3.4.2 Argument : Classic experience

### 3.5 PowerShell Get-AzKeyVaultSecret

## 4 Resources

Azure Pipelines >

- [Variable Groups](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=yaml)
- [Variable > Syntax](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#understand-variable-syntax)
- [Variable > Set Secret Variables](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#secret-variables)
- [Azure PowerShell Task](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/deploy/azure-powershell?view=azure-devops#samples)
