---
layout: post
title:  "Retrieving Azure Key Vault secrets with PowerShell in Azure DevOps Pipelines"
date:   2020-01-07 10:00:00 -0700
tags: ALM Azure DevOps KeyVault PowerShell
---

Alternative options to retrieve secrets from Azure Key Vault for a PowerShell script running in Azure DevOps Pipelines.

<!--more-->

## 1. Context

I [recently]({% post_url 2020-01-07-asa-alm104 %}) struggled a bit to find the right way to retrieve secrets from [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/) within a [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/overview?view=powershell-7) script running in [Azure DevOps Pipelines](https://azure.microsoft.com/en-us/services/devops/pipelines/). I could not figure out the proper syntax to do so (and I was [not alone](https://stackoverflow.com/questions/58607998/dynamicallly-get-keyvault-secret-in-azure-devops-powershell-script) in the situation).

This was for the [CI/CD pipeline]({% post_url 2019-12-06-asa-alm100 %}) of my [Azure Stream Analytics](https://docs.microsoft.com/en-us/azure/stream-analytics/stream-analytics-introduction) project hosted in Azure DevOps. At some point it needed to perform some **ARM Template deployments** via a PowerShell task, and figuring out the syntax to get access to my connection strings stored in Key Vault in the script was not as easy as I expected.

![Schema focusing on the release pipeline](https://github.com/Fleid/fleid.github.io/blob/master/_posts/201912_asa_alm101/asa_alm104_goal.png?raw=true)

*[figure 1 - Schema of the release pipeline](https://github.com/Fleid/fleid.github.io/blob/master/_posts/201912_asa_alm101/asa_alm104_goal.png?raw=true)*

What should have been a straightforward scenario took a bit of planning. Now I know that depending on 2 factors you can leverage different capabilities which come with different syntaxes. Those 2 factors being:

- the Azure Pipelines [experience](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/pipelines-get-started?view=azure-devops&tabs=yaml) in Build and Release:  YAML vs Classic
- the script type of the [Azure PowerShell](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/deploy/azure-powershell?view=azure-devops) task: inline vs file script

***

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

***

## 3. Options

**Before anything else**, we need to create a variable group linked to the Key Vault we plan to use. For that see the [middle section of that article]({% post_url 2020-01-07-asa-alm104 %}).

To be noted:

> When trying to link the KeyVault in the Variable Group, the **authentication** process can hang indefinitely. It can be solved in KeyVault, by manually creating an **access policy** for the Azure DevOps project application principal (service account) with List/Get permissions on Secrets. The application principal id can be found in the Azure DevOps project **settings** (bottom left), **Service Connections** tab, editing the right subscription and going `use the full version of the service connection dialog`. It should be under `Service principal client ID`.

From there we can look at each syntax:

- Input macro : only available for inline scripts
- Inherited environment variable : most natural for normal variables but never works with secrets
- Mapped environment variable : only available in the YAML experience
- Arguments / parameter mapping : only available for file scripts
- PowerShell `Get-AzKeyVaultSecret` : when it just needs to work

### 3.1 Input macro

**Only available for inline scripts**, [more info](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#set-variables-in-pipeline).

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

Both for Inline and File script, the syntax is similar : `$env:normalVariable` (as in `Write-Host "Inherited ENV from normal VG: $env:normalVariable"`)

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
Then both for Inline and File script the syntax is similar : `$env:normalVariable` (as in `Write-Host "Inherited ENV from normal VG: $env:normalVariable"`).

**NB** : The variable name will be altered as follow ([ref](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#understand-variable-syntax)):

> Name is upper-cased, . replaced with _

Knowing that PowerShell is not case sensitive, the only issue is the . to _ switcheroo.

![Screenshot of Azure DevOps : Inherited environment variable for inline script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/inherited_inline_classic.png?raw=true)

*[figure 4 - Screenshot of Azure DevOps : Inherited environment variable for inline script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/inherited_inline_classic.png?raw=true)*

### 3.3 Mapped environment variable

**Only available via the YAML experience.** This is the [recommended solution](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#secret-variables) in YAML (too bad it's not available for releases yet).

With the variable group `myVariableGroup` linked to KeyVault, giving access to the secret `kvTestSecret`.
The inline script can reference the secret directly via : `$env:MY_MAPPED_ENV_VAR_KV` (as in `Write-Host "Mapped ENV from KeyVault VG: $env:MY_MAPPED_ENV_VAR_KV"`).

The **key statement** here being the `env:` [parameter](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema?view=azure-devops&tabs=schema#task) required at each task.

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

**Only available for File Path scripts**, since arguments don't exist inline.

With the variable group `myVariableGroup` linked to KeyVault, giving access to the secret `kvTestSecret`.

Independently of the experiences, the PowerShell script will require a [binding statement](https://www.red-gate.com/simple-talk/sysadmin/powershell/how-to-use-parameters-in-powershell/) at the top:

Content of **testArg.ps1**:

```PowerShell
[CmdletBinding()]
param ([string] $Arg1)

# Using arguments:
Write-Host "Argument from the KeyVault VG: $Arg1"
```

#### 3.4.1 Argument : YAML experience

On the YAML side, the task will use the `ScriptArguments` parameter, each arguments following `-Arg1 $(var1) -Arg2 $(var2)`. Since this is a string generated at runtime and fed as is to PowerShell, variables should be enclosed with `"..."` if they can contain spaces: `-Arg1 "$(var1)" -Arg2 "$(var2)"`.

```YAML
trigger:
  - master
  
pool:
  vmImage: 'windows-latest'

variables:
- group: myVariableGroup
  
steps:
- task: AzurePowerShell@4
  displayName: 'Azure PowerShell script - file path'
  inputs:
    azureSubscription: '...'
    ScriptType: 'FilePath'
    ScriptPath: '$(Build.Repository.LocalPath)/testArg.ps1'
    ScriptArguments: '-Arg1 "$(kvTestSecret)"'
    azurePowerShellVersion: 'LatestVersion'
```

#### 3.4.2 Argument : Classic experience

In the classic experience, the variable group must be declared in the `Variables` tab beforehand.
Then the same syntax will be used to map the argument: `-Arg1 "$(kvTestSecret)"`.

![Screenshot of Azure DevOps : Argument mapping for file script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/argument_file_classic.png?raw=true)

*[figure 5 - Screenshot of Azure DevOps : Argument mapping for file script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/argument_file_classic.png?raw=true)*

### 3.5 PowerShell `Get-AzKeyVaultSecret`

Finally, in every experience the [PowerShell cmdlet](https://docs.microsoft.com/en-us/powershell/module/az.keyvault/get-azkeyvaultsecret?view=azps-3.3.0) `Get-AzKeyVaultSecret` can leverage the existing wiring to retrieve the secret from the script. This approach will require an **access policy** in Azure Key Vault for the Azure DevOps project application principal (service account) with List/Get permissions on Secrets (see above).

The PowerShell syntax is similar in every configuration:

```PowerShell
# Using PowerShell directly:
$Secret = (Get-AzKeyVaultSecret -VaultName "myKeyVaultName" -Name "kvTestSecret").SecretValueText
Write-Host  "PowerShell Get-AzKeyVaultSecret: $Secret"
```

While not illustrated here, the Key Vault name and Secret name should be retrieved via "normal" variables using inherited environment variable for example.

#### 3.5.1 `Get-AzKeyVaultSecret` : YAML experience

There is no need to declare a variable group:

```YAML
trigger:
  - master
  
pool:
  vmImage: 'windows-latest'
  
steps:

- task: AzurePowerShell@4
  env:
  displayName: 'Azure PowerShell script - inline'
  inputs:
    azureSubscription: '...'
    ScriptType: 'InlineScript'
    Inline: |
      # Using PowerShell directly:
      $Secret = (Get-AzKeyVaultSecret -VaultName "myKeyVaultName" -Name "kvTestSecret").SecretValueText
      Write-Host  "PowerShell Get-AzKeyVaultSecret: $Secret"
    azurePowerShellVersion: 'LatestVersion'

- task: AzurePowerShell@4
  env:
  displayName: 'Azure PowerShell script - file path'
  inputs:
    azureSubscription: '...'
    ScriptType: 'FilePath'
    ScriptPath: '$(Build.Repository.LocalPath)/testArg.ps1'
    azurePowerShellVersion: 'LatestVersion'
```

#### 3.5.1 `Get-AzKeyVaultSecret` : Classic experience

There is no need to declare a variable group:

![Screenshot of Azure DevOps : PowerShell cmdlet for inline script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/ps_inline_classic.png?raw=true)

*[figure 6 - Screenshot of Azure DevOps : PowerShell cmdlet for inline script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/ps_inline_classic.png?raw=true)*

![Screenshot of Azure DevOps : PowerShell cmdlet for file script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/ps_file_classic.png?raw=true)

*[figure 7 - Screenshot of Azure DevOps : PowerShell cmdlet for file script in classic experience](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202001_azure_devops_keyvault/ps_file_classic.png?raw=true)*

***

## 4 Resources

Azure Pipelines >

- [Variable Groups](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=yaml)
- [Variable > Syntax](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#understand-variable-syntax)
- [Variable > Set Secret Variables](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/variables?view=azure-devops&tabs=yaml%2Cbatch#secret-variables)
- [Azure PowerShell Task](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/deploy/azure-powershell?view=azure-devops#samples)
