---
layout: post
title:  "Calculating Consumer Lag in Azure Event Hubs"
date:   201-12-02 10:00:00 -0700
categories: monitoring Azure eventhub kafka
---

# Calculating Consumer Lag in Azure Event Hubs

## Consumer Lag

When consuming large streams of data, it is important to monitor and detect early if we're starting to lag behind. If we ingest 10 events per second on a topic and only consume 8, we're falling behind and soon we'll never be able to catch up.

Looking at a topic as it is [typically implemented](https://kafka.apache.org/documentation) in stream processing:

![A log with producers and consumers writing and reading at different offsets](https://kafka.apache.org/23/images/log_consumer.png)

*Source: [Apache Kafka Documentation](https://kafka.apache.org/documentation/)*

On that schema, the last committed offset of the topic is 11. Consumer A is reading at offset 9 with a **lag of 2** (11-9). Consumer B is reading at 11 with a **lag of 0**. An added complexity is that topics are always [partitioned](https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-features#partitions). For a given topic, the actual grain to calculate lag will effectively be **{ consumer x partition }**.

![The impact of partitioning on consumer lag](https://github.com/Fleid/fleid.github.io/blob/master/_posts/201912_eh_consumerlag/consumerlag_partitions.png?raw=true)

## No consumer lag metric in Azure Event Hubs

If Confluent offers [multiple options](https://docs.confluent.io/current/cloud/using/monitor-lag.html) to monitor consumer lag in Kafka (plus [some](https://github.com/teslamotors/kafka-helmsman/blob/master/kafka_consumer_freshness_tracker/README.md) - [community](https://github.com/lightbend/kafka-lag-exporter) - [alternatives](https://github.com/linkedin/Burrow)), Microsoft [doesn't](https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-metrics-azure-monitor) for [Azure Event Hubs](https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-about).

It makes sense when you remember that **Azure Event Hubs** is basically a topic-as-a-service offering, while Kafka is a fully featured platform. We can think of it as comparing a single table vs a complete [RDBMS](https://en.wikipedia.org/wiki/Relational_database#RDBMS). Not the same effort to get started, but not the same value proposition either.

![Value proposition of Event Hub vs Kafka](https://github.com/Fleid/fleid.github.io/blob/master/_posts/201912_eh_consumerlag/eh_value_prop.png?raw=true)

So to get that consumer lag, we will need to calculate it ourselves: there is no central service that will do it for us.

## TL/DR

To date, the only option to get a consumer lag metric in **Event Hubs** is to calculate it at the consumer level.

If we use an [EventProcessorHost](https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-event-processor-host) in that context (recommended approach), we can leverage [EventProcessorOptions](https://docs.microsoft.com/en-us/dotnet/api/microsoft.servicebus.messaging.eventprocessoroptions?view=azure-dotnet) to ```EnableReceiverRuntimeMetric``` before registering the processor to the host. This way we will get access to both consumer offset (already there) and ```lastEnqueuedSequence``` (part of those enabled runtime metrics). This works for every [SDKs](https://docs.microsoft.com/en-us/azure/#pivot=sdkstools) that supports ```EventProcessorHost``` (sure thing for [.NET](https://docs.microsoft.com/en-us/dotnet/api/microsoft.azure.eventhubs.processor.eventprocessorhost?view=azure-dotnet) and [Java](https://azuresdkdocs.blob.core.windows.net/$web/java/azure-eventhubs-eph/3.1.0/index.html)).

## Implementation details

To calculate consumer lag we "just" need to do a difference: ```consumerLag(consumer,partition) = lastEnqueuedSequence(partition) - currentSequence(consumer,partition)```.

Here the ```lastEnqueuedSequence``` is the sequence number of the last event that was ingested on a specific partition of the Event Hub (offset 11 on partition 0 of the schema below). If we compare that to the ```currentSequence``` number being read by a consumer (offset 9 for A on the same partition below), it will give us its lag - on that partition: 3.

![Consumer Lag calculated at the partition level](https://github.com/Fleid/fleid.github.io/blob/master/_posts/201912_eh_consumerlag/consumerlag_partitionCalculation.png?raw=true)

For ```lastEnqueuedSequence``` things are easy. It's a property of the Event Hub partitions that can be obtained from an [EventHubClient](https://docs.microsoft.com/en-us/dotnet/api/microsoft.azure.eventhubs.eventhubclient?view=azure-dotnet) via [GetPartitionRuntimeInformationAsync](https://docs.microsoft.com/en-us/dotnet/api/microsoft.azure.eventhubs.eventhubclient.getpartitionruntimeinformationasync?view=azure-dotnet#Microsoft_Azure_EventHubs_EventHubClient_GetPartitionRuntimeInformationAsync_System_String_).

Now for ```currentSequence```, it is not that easy. By design, the Event Hubs service is never aware of the consumer offset. As [explained](https://stackoverflow.com/questions/35464192/understanding-check-pointing-in-eventhub) by a member of the product team responsible for Event Hubs:
> In short - just to be clear, EventHubs Service - is completely unaware that you are checkpointing to Azure Storage. EventProcessor library - only helps the job of checkpointing the Offset (and managing lease across multiple instances) using the Azure Storage library

If we are using the direct API to consume events from the Event Hub, we have to manage the offset - store its value - by ourselves. In that case, we will have to handle the consumer lag calculation also, since nobody else has a knowledge of it. This is not the recommended approach though. The Event Hubs team maintain a companion library to Event Hubs called the ```EventProcessorHost```. Its job is to manage the current customer offset - storing in its own storage service - Most of the time this will be a storage account that we need to provide for it to run.

![Simplified view of the event hub processor topology](https://github.com/Fleid/fleid.github.io/blob/master/_posts/201912_eh_consumerlag/eh_simplifiedView.png?raw=true)

If we follow that approach (again, it's the recommended one), then the only place where we can get the ```currentSequence``` will be at the Event Processor level (```SimpleEventProcessor``` above). There we could get ```lastEnqueuedSequence```  from an ```EventHubClient```, but the Event Hubs team has actually made it available directly from the ```EventProcessorHost```. It's not turned on by default, for slight performance reasons, but it can be enabled via the [EventProcessorOptions](https://docs.microsoft.com/en-us/dotnet/api/microsoft.servicebus.messaging.eventprocessoroptions?view=azure-dotnet) and its ```EnableReceiverRuntimeMetric``` property, passed when registering the processor to the host (see above).

Using [this sample solution](https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-dotnet-standard-getstarted-send#receive-events) we can do just that with the following changes.

- In ```program.cs```:

```CSHARP
private static async Task MainAsync(string[] args)
    {
        Console.WriteLine("Registering EventProcessor...");

        var eventProcessorHost = new EventProcessorHost(
            EventHubName,
            PartitionReceiver.DefaultConsumerGroupName,
            EventHubConnectionString,
            StorageConnectionString,
            StorageContainerName);

        // This is where we prepare the configuration to enable runtime metrics
        var eventProcessorOptions = new EventProcessorOptions();
        eventProcessorOptions.EnableReceiverRuntimeMetric = true;

        // We inject the configuration when we're registering the processor
        await eventProcessorHost.RegisterEventProcessorAsync<SimpleEventProcessor>(eventProcessorOptions);

        Console.WriteLine("Receiving. Press ENTER to stop worker.");
        Console.ReadLine();

        await eventProcessorHost.UnregisterEventProcessorAsync();
    }
```

Which gives access to ```context.RuntimeInformation.LastSequenceNumber``` in the processor instance.

- In ```SimpleEventProcessor.cs```:

```CSHARP
public Task ProcessEventsAsync(PartitionContext context, IEnumerable<EventData> messages)
{
    foreach (var eventData in messages)
    {
        // Consumer Lag
        var messageSequence = eventData.SystemProperties.SequenceNumber;
        var lastEnqueuedSequence = context.RuntimeInformation.LastSequenceNumber;
        var sequenceDifference = lastEnqueuedSequence - messageSequence;

        // Payload
        var data = Encoding.UTF8.GetString(eventData.Body.Array, eventData.Body.Offset, eventData.Body.Count);

        // Output
        Console.WriteLine($"Message received. Partition: '{context.PartitionId}', Data: '{data}', Consumer Lag: '{sequenceDifference}'");
    }

    return context.CheckpointAsync();
}
```

At runtime, we will be able to see the consumer lag each time we receive a message:

![Our updated app output the consumer lag for each message received](https://github.com/Fleid/fleid.github.io/blob/master/_posts/201912_eh_consumerlag/consumerlag_console.png?raw=true)

From there we can push that new metric to [our monitoring solution](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/metrics-custom-overview).

## Alternatives

If we leverage the ```EventProcessorHost``` library, we could actually gather checkpoints / current offsets directly from the storage service it requires. Looking at what's generated there, it's a pretty straightforward file to process:

![Inside the file the Event Processor Host use to keep the offset](https://github.com/Fleid/fleid.github.io/blob/master/_posts/201912_eh_consumerlag/eh_eventProcessorInternal?raw=true)

On the plus side, it means no code change in the processor, and with the [new change feed](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-change-feed?tabs=azure-portal) capability of blob storage we should be able to build a live monitoring solution across all consumers fairly easily.

On the minus side, this can be seen as accessing the internal data store of another independent service which is basically a [big no no](https://martinfowler.com/bliki/IntegrationDatabase.html).

## Sources

What led me to the solution were this [StackOverflow answer](https://stackoverflow.com/questions/56491948/how-do-you-monitor-azure-event-hub-consumer-lag) and associated [article](https://medium.com/@dylanm_asos/azure-functions-event-hub-processing-8a3f39d2cd0f) (with an how-to in the context of [Azure Functions bindings](https://docs.microsoft.com/en-us/azure/azure-functions/functions-bindings-event-hubs)). I wanted something to work in a console app for a more generic solution, but that helped a ton.

The other one is this [StackOverflow answer](https://stackoverflow.com/questions/51823399/azure-event-processor-host-java-library-receiverruntimeinformation-doesnt-hav) that gives the final hint to what needs to be done.
