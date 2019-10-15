---
layout: post
title:  "Batch Pipeline Project Review : Notable Implementation Details"
date:   2018-12-01 12:00:00 -0700
categories: architecture ADFv2 Azure batch
---

# Azure Data Factory v2 - Batch Pipeline Project Review : Notable Implementation Details

This is article is part of a series:

1. [Architecture discussion](https://fleid.github.io/adfv2_batchepipeline/201812_adfv2_batchpipeline_adr)
2. [ALM and Infrastructure](https://fleid.github.io/adfv2_batchepipeline/201812_adfv2_batchpipeline_alm)
3. **Notable implementation details** *<- you are here, comments / PR are [welcome](https://github.com/Fleid/fleid.github.io/blob/master/adfv2_batchepipeline/201812_adfv2_batchpipeline_implementation.md)*

- Author : Florian Eiden
  - [blog](https://fleid.net/) / [twitter](https://twitter.com/fleid_bi?lang=en) / [linkedin](https://ca.linkedin.com/in/fleid) / [github](https://github.com/fleid)
  - Disclaimer : I'm a Microsoft employee at the time of writing
- Publication : 2018-12
  - Last update : 2019-01-10

## Architecture

As a reminder, here is the solution architecture we established earlier ([see the first article of the series for more details](https://fleid.github.io/adfv2_batchepipeline/201812_adfv2_batchpipeline_adr)):

![Schema illustrating the architecture](https://github.com/Fleid/fleid.github.io/blob/master/adfv2_batchepipeline/201812_adfv2_batchpipeline/technicalArchitecture.png?raw=true)

## Implementation in ADFv2

We will focus on the implementation of **Step 3 and 4** in Azure Data Factory v2 as they contain most of the logic in our pipeline:

- **Step 3**
  - Get data from File Store B
  - Flatten the hierarchy of folders (see chart below)
  - Convert files from CSV to Parquet
- **Step 4**
  - Delete files when processed

![Schema illustrating the architecture](https://github.com/Fleid/fleid.github.io/blob/master/adfv2_batchepipeline/201812_adfv2_batchpipeline/technicalArchitecture2.png?raw=true)

### Logical flow

If the **Copy Activity** of ADFv2 allows for a flattening of the file structure when copying files, it [auto generates a name](https://docs.microsoft.com/en-us/azure/data-factory/connector-file-system#file-system-as-sink) for them in the operation. We decided instead to loop over the folder structure ourselves, gathering metadata as we go, to iterate over individual files and process them as required (copy, rename, delete).

We will use 3 levels of nested loops to achieve that result:

- Iterating over Companies
  - Within a company for the current year/month, iterating over Device IDs
    - Within a company for the current year/month for a Device ID, iterating over individual files

We won't loop over Year/Month as we're only processing the current day of results, and we can generate these attributes using the current date.

At the time of writing it is not possible to nest a ForEach activity inside another ForEach activity in ADFv2. What should be done instead is to execute a pipeline in a Foreach and implement the next loop in that second pipeline. Parameters are used to transmit the current item value of the loop between nested pipelines. This is detailed below.

Here is an illustration of the expected logical flow:

![Screenshot of the pipeline](https://github.com/Fleid/fleid.github.io/blob/master/adfv2_batchepipeline/201812_adfv2_batchpipeline/pipeLogicalFlow.png?raw=true)

### Data sets

We will use parameters in our data sets following that [strategy](https://www.blue-granite.com/adfv2_batchepipeline/using-azure-data-factory-v2-activities-dynamic-content-to-direct-your-files).

To iterate over the file structure in the **File Store B**, we will need:

- **FS_Companies** : point to the root folder containing the list of companies
  - Binary Copy (no metadata to be loaded) with a folderPath only (see [green tip infobox](https://docs.microsoft.com/en-us/azure/data-factory/connector-file-system#file-system-as-sink))
- **FS_DeviceIDs** : point to a folder of Device Ids
  - Parameters : Company, Year, Month
  - Binary Copy, folderPath only  
    - folder path: `@concat(dataset().Company,'/',dataset().Year,'/',dataset().Month)`
- **FS_Files** : point to a folder of files
  - Parameters : Company, Year, Month, Device Id
  - Binary Copy, folderPath only
    - folder path: `@concat(dataset().Company,'/',dataset().Year,'/',dataset().Month,'/',dataset().DeviceID)`
- **FS_File** : point to a specific file to be processed
  - Parameters : Company, Year, Month, Device Id, FileName
  - CSV format
    - folder path: `@concat(dataset().Company,'/',dataset().Year,'/',dataset().Month,'/',dataset().DeviceID)`
    - file path: `@dataset().FileName`
    - Schema : column names loaded from file, **data types should be generated manually** and entered here ([an explicit conversion is mapped from source](https://docs.microsoft.com/en-us/azure/data-factory/copy-activity-schema-and-type-mapping#explicit-data-type-conversion))

We don't need data sets to iterate over years and months as we can extract that from the current date. We will expose those as parameters to be able to process the past if need be.

On the output side, we will need a sink data set targeting the **blob store**:

- **BS_OutputFile** : point to a specific file to be generated
  - Parameters : Company, Year, Month, Device Id, FileName
  - Parquet format
    - file path: `@concat(dataset().Year,dataset().Month,'_',dataset().Company,'_',dataset().DeviceID,'_',dataset().FileName)`
    - schema : generated manually with cleaned column names (no space/symbol for Parquet) and explicit data types

### Pipeline design

Here are the pipelines that will be created:

#### Pipeline "01 - Master"

Parameter:

- *LogicApp_FS_Delete*: Logic App URL

This is the master pipeline for step 3/4. It will contain the main routine and eventually some additional administrative steps (audit, preparatory and clean-up tasks...).

![Screenshot of the pipeline](https://github.com/Fleid/fleid.github.io/blob/master/adfv2_batchepipeline/201812_adfv2_batchpipeline/pipe01.png?raw=true)

- Execute Pipeline Task : *02 - Get Companies and IDs*
  - Invoked Pipeline : "02 - Get Companies and IDs"
  - Parameters : `@pipeline().parameters.LogicApp_FS_Delete`

#### Pipeline "02 - Get Companies and IDs"

Parameter:

- *LogicApp_FS_Delete*: Logic App URL, String

Variables:

- *PipeMonth* : String
- *PipeYear* : String

This pipeline will get the list of companies from the folder metadata, generate the current Year/Month, and from that get the list of available Device IDs from the subfolder metadata.

![Screenshot of the pipeline](https://github.com/Fleid/fleid.github.io/blob/master/adfv2_batchepipeline/201812_adfv2_batchpipeline/pipe02.png?raw=true)

- Get Metadata : *Get Companies*
  - Dataset : **FS_Companies**
  - Field List Argument : Child Items
- Set Variable : *Set Month*
  - Variable : *`PipeMonth`*
  - Value : `@formatDateTime(adddays(utcnow(),-1),'MM')`
- Set Variable : *Set Year*
  - Variable : *`PipeYear`*
  - Value : `@formatDateTime(utcnow(),'yyyy')`
- ForEach : *Foreach Company*
  - Items : **`@activity('Get Companies').output.childItems`**
  - Activities :
    - Get Metadata : *Get Device IDs"
      - Dataset : **FS_DeviceIDs**
        - Parameters :
          - Company : **`@item().name`**
          - Year : `@variables(*PipeYear*)`
          - Month : `@variables(*PipeMonth*)`
      - Field List Argument : Child Items
    - Execute Pipeline : *03 - Get File Names*
      - Invoked Pipeline : "03 - Get File Names"
      - Parameters :
        - LogicApp_FS_Delete : `@pipeline().parameters.LogicApp_FS_Delete`
        - PipeCompany : **`@item().name`**
        - PipeYear : `@variables(*Var_Year*)`
        - PipeMonth : `@variables(*Var_Month*)`
        - PipeDeviceIDList : `@activity('Get Device IDs').output.childItems`

#### Pipeline "03 - Get File Names"

Parameters:

- *LogicApp_FS_Delete*: Logic App URL, String
- PipeCompany : String
- PipeYear : String
- PipeMonth : String
- PipeDeviceIDList : Array

This pipeline will get the list of file names from the final subfolder metadata.

![Screenshot of the pipeline](https://github.com/Fleid/fleid.github.io/blob/master/adfv2_batchepipeline/201812_adfv2_batchpipeline/pipe03.png?raw=true)

- ForEach : *ForEach ID*
  - Items : **`@pipeline().parameters.PipeDeviceIDList`**
  - Activities :
    - Get Metadata : *Get file names"
      - Dataset : **FS_Files**
        - Parameters :
          - Company : `@pipeline().parameters.PipeCompany`
          - Year : `@pipeline().parameters.PipeYear`
          - Month : `@pipeline().parameters.PipeMonth`
          - Device ID : **`@item().Name`**
      - Field List Argument : Child Items
    - Execute Pipeline : *04 - Actual Move*
      - Invoked Pipeline : "04 - Actual Move"
      - Parameters :
        - LogicApp_FS_Delete : `@pipeline().parameters.LogicApp_FS_Delete`
        - PipeCompany : `@pipeline().parameters.PipeCompany`
        - PipeYear : `@pipeline().parameters.PipeYear`
        - PipeMonth : `@pipeline().parameters.PipeMonth`
        - PipeDeviceID : **`@item().Name`**
        - PipeFileNames : `@activity('Get file names').output.childItems`

#### Pipeline "04 - Actual Move"

Parameters:

- *LogicApp_FS_Delete*: Logic App URL, String
- PipeCompany : String
- PipeYear : String
- PipeMonth : String
- PipeDeviceID : String
- PipeFileNames : Array

This pipeline will copy and then delete the files.

![Screenshot of the pipeline](https://github.com/Fleid/fleid.github.io/blob/master/adfv2_batchepipeline/201812_adfv2_batchpipeline/pipe04.png?raw=true)

- ForEach : *ForEach FileName*
  - Items : **`@pipeline().parameters.PipeFileNames`**
  - Activities :
    - Copy Data : *Actual Copy - Single File*
      - Source : **FS_File**
        - Parameters :
          - Company : `@pipeline().parameters.PipeCompany`
          - Year : `@pipeline().parameters.PipeYear`
          - Month : `@pipeline().parameters.PipeMonth`
          - Device ID : `@pipeline().parameters.PipeDeviceID`
          - FileName : **`@item().Name`**
      - Sink : **BS_OutputFile**
        - Parameters :
          - Company : `@pipeline().parameters.PipeCompany`
          - Year : `@pipeline().parameters.PipeYear`
          - Month : `@pipeline().parameters.PipeMonth`
          - Device ID : `@pipeline().parameters.PipeDeviceID`
          - FileName : **`@item().Name`**
      - Schema mapped
    - Web Activity : *Delete via Logic App*
      - URL : `@pipeline().parameters.LogicApp_FS_Delete`
      - Method : POST
      - Body :
        - `@concat('{"filepath":"','myfolder/',pipeline().parameters.PipeCompany,'/',pipeline().parameters.PipeYear,'/',pipeline().parameters.PipeMonth,'/',pipeline().parameters.PipeDeviceID,'/',item().Name,'"}')`

### Actual pipeline Flow

Here is an illustration of the complete flow as implemented in ADFv2 across 4 pipelines:

![Screenshot of the pipeline](https://github.com/Fleid/fleid.github.io/blob/master/adfv2_batchepipeline/201812_adfv2_batchpipeline/pipeFlow.png?raw=true)

## Conclusion

The documentation of ADFv2 was a bit immature at the time of writing, so figuring some of the quirks of ADFv2 was a bit challenging.
But if the solution we built is far from perfect, it is a good first iteration delivering on all the initial requirements.