---
layout: post
title:  "PowerShell Tips"
date:   2020-01-07 10:00:00 -0700
categories: Azure DevOps PowerShell Script
---

# PowerShell tips

This article contains my notes from completing [Learn PowerShell in a Month of Lunches](https://www.manning.com/books/learn-windows-powershell-in-a-month-of-lunches-third-edition).

## Context

As I've recently been using **PowerShell** [more](https://www.eiden.ca/asa-alm-103/) and [more](https://github.com/Fleid/asa.unittest), I've decided to take the time to learn it properly.

I had bought [Learn PowerShell in a Month of Lunches](https://www.manning.com/books/learn-windows-powershell-in-a-month-of-lunches-third-edition) previously but never had taken the time to go through it. So I did. And I don't regret it. Both the format and the content are fantastic, **I highly recommend it to anyone looking to get a strong foundation** in PowerShell.

![Cover of Learn Windows Powershell in a Month of Lunches](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202002_powershell_tips/cover1.png?raw=true)
*[Learn Windows Powershell in a Month of Lunches](https://www.manning.com/books/learn-windows-powershell-in-a-month-of-lunches-third-edition)*

Now why would one want a good foundation in [PowerShell](https://docs.microsoft.com/en-us/powershell/)? Because everyone needs to be comfortable in at least one [shell](https://en.wikipedia.org/wiki/Shell_%28computing%29). It is fairly simple and yields huge benefits in automating all sort of processes via the command line. PowerShell is of course the perfect candidate when you're deep in Microsoft territory (so easy to leverage in Azure). And since it's [cross platform](https://github.com/powershell/powershell) now!

![Sample of PowerShell code - look at me flexing my mad](https://github.com/Fleid/fleid.github.io/blob/master/_posts/202002_powershell_tips/ps_sample.png?raw=true)
*[Sample of PowerShell code, the rest here](https://github.com/Fleid/asa.unittest/blob/master/unittest/2_act/unittest_prun.ps1)*

I'm starting [Learn PowerShell Scripting in a Month of Lunches](https://www.manning.c8om/books/learn-powershell-scripting-in-a-month-of-lunches) now, the follow-up to **Learn PowerShell...** focusing on scripting. I'll surely add to the list of tips below when I'm done.

## Notes

### Must remember

- In PowerShell **everything is an object**
  - To get the properties/methods of an object : `... | Get-Member`
  - To see [what is accepted as pipeline input](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pipelines?view=powershell-7#methods-of-accepting-pipeline-input) : `Get-Help ... -full`
  - To strongly type / cast a variable : `[int]$number = Read-Host "Enter a number"`
- Always **try to pipe commands first**
  - When binding is not possible, then use `(...)`. As an example:
    - This is not supported: `Get-Content .\computers.txt | Get-WmiObject -class win32_bios`
    - The alternative : `Get-WmiObject -class Win32_BIOS -ComputerName (Get-Content .\computers.txt)`
- **Vocabulary**
  - "Host" = screen (as in `Write-Host`)

### Practical

- **Syntax**
  - `${My Variable}` for variable with spaces
  - Use `$(...)` to run a command in a string: `$firstname = "The first name is $($services[0].name)"`, here the command is `$services[0].name`
- **Unboxing a property** via `Select-Object`
  - `...| Select-Object -expand name`
  - Similar to `(...).name` which also returns a string
  - As opposed to `...| Select-Object -property name` which returns an object with the unique property `name`
- **Aggregating** in the pipeline
  - `... | Measure-Object -property A -sum`
- **File parsing**:
  - To open a file: `Get-Content`
  - Use `Import-CSV` or `Import-CliXML` instead to get automatic parsing from file structure
  - For JSON it's still `Get-Content ... | ConvertFrom-Json`
- **Invocation operator**: `&` ([doc](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_operators?view=powershell-7#call-operator-))
  - or `--%` (same but with literal parsing of arguments)
  - The syntax is weird in the sense that arguments are passed as PowerShell arguments and not string: `& sa.exe -p1 "AH" -p2 "HA"`
- **Wildcard characters**: `*` for 0 or more char, `?` for any single one
  - `-LiteralPath` instead of `-Path` to prevent wildcard interpretations
- **Background jobs**
  - `Enable-PSRemoting` to `Start-Job` even local
  - >Don’t ever make assumptions about file paths from within a background job: Use absolute paths to make sure you can refer to whatever files your job command may require
- In a **script** there's only one pipeline, so your scripts should strive to output only one kind of object

### Cute

- [`Show-Markdown`](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/show-markdown?view=powershell-7) will show a string or file in the console rendering the [Markdown](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet) syntax
- `... > my.txt` is equivalent to  `... | Out-File my.txt`
- The percent sign (`%`) is an alias to `ForEach-Object`
- **Variables**
  - PowerShell home : `$pshome`
  - PowerShell version " `$PSVersionTable`
- Don't use `Write-Host` for fuzzy status
  - Use `Write-Verbose`, `Write-Debug`, `Write-Warning`, `Write-Error`
  - Leverage their settings `$VerbosePreference="Continue"` and call parameters `.\myScript.ps1 -verbose`
