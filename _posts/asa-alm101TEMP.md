
## 1. Developer Experience

### Status of a job

Starting / restarting, from/when
By the way, it's already stress inducing for a DWH/BI pro: when I select to start the job, it asks me about when it should start reading from the input. What if I miss something? What if read something twice! Argh! :)

Bleh, stop guessing, here is the [doc](https://docs.microsoft.com/en-us/azure/stream-analytics/start-job) on the matter. The ARM Template was generated with ```JobStartTime```, I want ```LastOutputEventTime```. Using the charm in VS to compile the script reset the value of that parameter so I should update that in the build pipeline instead.


Back to the **deployment** option. I did update the build pipeline to ```LastOutputEventTime```, but in the meantime I createad a new job in a new resource group, and ```LastOutputEventTime``` can't be used for the first deployment. I triggered the build with ```JobStartTime``` once ant put back ```LastOutputEventTime```. Time for some testing.

I lost some time because I decided to change the ARM deployment mode to complete instead of incremental, which means it deleted the storage account that was supposed to be used as the output of the ASA job. That failed the deployment. When I tried again, ASA got into a funky state, I suppose it's because it was expecting some data to be there (```LastOutputEventTime```) but it wasn't (deleted/recreated). I changed the ARM mode back to incremental, and did a clean deploy (```JobStartTime```) just to start properly. It still fails. I successfully started the job manually from the portal. Go figure.

Anyhoo, I'll give a couple of minutes to the staging job to catch up, then will trigger a deploy to see if I'm missing data now. The job is restarting. It restarted successfully. I stopped both jobs and compared data in their files.

Big surprise, **I actually have duplicated keys** (4 records overlapping). That's very interesting! Investigation next time...

For the [delivery guarantee](https://docs.microsoft.com/en-us/stream-analytics-query/event-delivery-guarantees-azure-stream-analytics#exactly-once-delivery), here is what the doc says: *"Azure Stream Analytics **guarantes at-least-once delivery** to output sinks, which guarantees that all results are outputted, but duplicate results may occur. However exactly-once delivery may be achieved with several outputs such as Cosmos DB or SQL."*

This explains that.

### VSCode setup


https://docs.microsoft.com/en-us/azure/stream-analytics/vscode-local-run

So the doc is not updated, but I should be able to test locally, in VS Code, both for local sample data and live stream input.

The tutorial is summary, it just tells you to create a local input, and run the query on it. Let's generate a test file from scratch then. Or I could download what was put on blob the last time the job ran. I need to install [Storage Explorer](https://azure.microsoft.com/en-us/features/storage-explorer/).





### Azure Devops Setup + Repos

I created new Azure Devops project (I already had an account there, but it's free anyway).

There I created 3 new repos: Ticker (consoleapp), Function01 and ASAtopologu01 and initialized them. I'm making assumptions here in terms of repo strategy. I want to isolate per technology by habit, we'll see how it goes. Still I'm not sure how to handle infra as code artifacts, At the moment I want each component to be self contained (Ticker repo will host deployment code for ticker resources), but then where to put shared assets? I'll surely need a shared infra repo but let's feel the pain before I fix that.

Then I cloned these repos locally, in VSCode, opening a terminal in the repo root folder, and doing a ```git clone https...```. That adresse comes form DevOps, that will also generate for you. Which now means I need a KeyVault to store those credentials, which means I need an Azure subscription. Why not 1Password? I expect to need them accessible from code.

### Local execution and testing

Building blocks
- 000 is for the IoTHub device
- 001 is for local, it should have a storage account and n asa jobs
- 002 is for staging, it should have a storage account and 1 asa jobs
I added a Cosmos DB account/db/container to the provisioning script with a TTL of 12h.
Job is running but still nothing in Cosmos. THE PARTITION COLUMN NAME IS CASE SENSITIVE. Note that the activity log from ASA is pretty good (portal>ASA job>Activity Log>JSON details).

- ASA is [at-least-once delivery]](https://docs.microsoft.com/en-us/stream-analytics-query/event-delivery-guarantees-azure-stream-analytics)
- ASA should run in 1.2 (not default yet)
- Cosmos should make a good observability output

In passing, there is an extremly strong case to use an idempotent destination with these at-least-once delivery mechanims, either Cosmos or SQL. It is such a relief not to bother about duplication. I'd say that outside of cost perspective (lol), capture should happen at the first ingestion point, before any duplication can happen, and then after one of these stores, to eliminate it..

- Gotcha local output

**NB**: [Info] 11/11/2019 10:14:46 PM : Warning : Time policy for stream analytics job is not supported for local static input file.

I installed Storage Explorer, but in the meantime just downloaded the file from the Azure portal. Apparently it's badly formatted though (each record is appended, without being in ```[]``` or separated by ,). 
>> I should look into why the output JSON file on blob was weird on how to prevent that. Or is IoTHub the culprit?

I corrected it manually, now I have a test file. Well, a random test file, I would need to qualify it to make it a proper test file.

I created a new ASA local input getting data from that file.

After playing a bit with the setup, I settled on the following: 

- a ```Local_myInputfile.json``` definition file
- a ```Data_myInputfile.xxx``` for the test data,
  - In this file I add a ```_testId``` column for the test case number
- in the query that needs to be tested I add ```COALESCE(_testID,0) AS Audit``` as an output column

Now I need the following:

- [x] to add the LocalRunOutputs folder to the gitignore
- [ ] to understand why the output didn't change to CSV when I updated the output definition file
  - New output, same result. Not sure the local job runner can output CSV?
- [ ] to find a way to compare the output to my Eval conditions
  - More complicated than expected. I tried NBI but that's not forward looking. I also looked at SQLtoJSON tools (q, TextQL) but that's not solid - and I may be limitied to JSON (build mine in .NET Core then?). Another way around would be to call the local test via CLI (asarunlocal.exe input.json outputpath), even better if we could provide a resultset and get a test result (https://docs.confluent.io/current/ksql/docs/developer-guide/ksql-testing-tool.html)


## 2. Provisioning

I'll need to provision a resource group, an IoT Hub (usually I do it with an Event Hub and a console app, but let's follow the tutorial for once), a storage account and an ASA project. As from the start I'll do a provision.azcli script for that, **except the IoT Hub**, which will only be used for the Hello World. Another deviation from the tutorial : I'll script the ASA project.

LOL @ scripting the ASA project, there's no support in the CLI. The options are Powershell or portal. Let's do Powershell (against my better judgement). Actually, after some more thoughts, let's not. There's 2 things here: creating a stub project/job, and deploying it. I'll follow the tutorial and use VSCode the create the job, I'll see what happens when we need to deploy it later.

I wanted to try testing here and there, but they don't provide a test file at the right format and I don't even have the schema yet.

### CLI

### PS

Down to deploying the job, I didn't need more that the input and output resources. I need to create a job in PowerShell then, let's [do that](https://docs.microsoft.com/en-us/azure/stream-analytics/stream-analytics-quick-create-powershell#create-a-stream-analytics-job). Obviously I don't have the AZ module installed, so let's start [there](https://docs.microsoft.com/en-us/powershell/azure/install-Az-ps?view=azps-3.0.0).

Getting some help from the PS tutorial, there are still some issues. My script looks like that:

```
Connect-AzAccount

# List all available subscriptions.
Get-AzSubscription

# Select the Azure subscription you want to use to create the resource group and resources.
Get-AzSubscription -SubscriptionName "Visual Studio Premium avec MSDN" | Select-AzSubscription

# Create a Stream Analytics job
$rg_name = "rg-tik-streaming001"
$jobName = "MyStreamingJob001"
$jobDefinitionFile = "C:\Users\Florian\Source\Repos\ASAtopology01\myASAProj\Deploy\myASAProj.JobTemplate.json"

New-AzStreamAnalyticsJob `
  -ResourceGroupName $rg_name `
  -File $jobDefinitionFile `
  -Name $jobName `
  -Force
```
But it's not in a happy place (and let's not mention the absolute path), as it says the location is missing from the definition. If I go in there, there's a location but it's parameterized in another json file. Looking at the cmdlet [definition](https://docs.microsoft.com/en-us/powershell/module/az.streamanalytics/new-azstreamanalyticsjob?view=azps-3.0.0) there's no mention of that paramater json file. Is this something Powershell and not ASA? After a bit of research, it's an [arm thing](https://docs.microsoft.com/en-us/azure/stream-analytics/stream-analytics-tools-for-visual-studio-cicd#generate-a-job-definition-file-to-use-with-the-stream-analytics-powershell-api) and there's a command in PowerShell to combine both files into something the cmdlet can deal with. Let's pause that thread, and resume it when I'm looking at releasing/testing the thing.

>> Explore CI/CD capabilities of Stream Analytics, and finalize the scripted deployment in the meantime
>> 

Hum, but I can always deploy an empty/stub job for provisioning, and target that for deployment in VSCode. Let's try that by creating a provision.JobTemplate.json with what's in the PS tutorial... that worked! Now let's target that for deploying the job from the other tutorial... and it won't show up in the wizard. Not sure why and I don't really care at the moment. I'm done, let's create another one from the wizard... it works!

## 3. Build / release pipeline

### Local compile

### ARM Template
\I started where I let things last time. The build pipeline was failing because it needed the keys to the blob stores and IoT Device. Right now the keys are hardcoded in the build pipeline, I should clean that up.

I'm still wondering if the resource group shouldn't be a variable instead of hardcoded. But at the same time, I just need 1 static build pipeline from the repo to the dev/test environment.

The deployment looks good now. I started the [emitter](https://azure-samples.github.io/raspberry-pi-web-simulator/) again to see some traffic.

I made a minor change to the ASA job, generated new ARM template, and pushed to master. It triggered a build pipeline, and the job was updated. It did restart the job though. It makes sense but I have to investigate how it behaves in regards to the data. Let's just check that it restarts where it left of (and check how to do that if necessary).


### From hardcoded keys to variables

In Azure Devops Pipeline, I created variables (type credentials, settable at queue time, only for my 4 keys), and referenced them in the build step in the ARM parameter override field using ```$(myVariable)``` symtax.

Looks like it's running from the first try.