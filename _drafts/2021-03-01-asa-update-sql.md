---
layout: post
title:  "Updating Azure SQL from Azure Stream Analytics with a Function"
date:   2021-03-01 10:00:00 -0700
tags: Azure Design SQL ASA Streaming
permalink: /asa-update-sql/
---

Updating / merging records into an Azure SQL table, from Azure Stream Analytics, by using Azure Function.

<!--more-->

When we need to store the latest version of each row in a dataset generated from an application, the recommended pattern is the [materialized view](https://docs.microsoft.com/en-us/azure/architecture/patterns/materialized-view).

[![Materialized view schema, from the Azure Architecture Center](https://docs.microsoft.com/en-us/azure/architecture/patterns/_images/materialized-view-pattern-diagram.png)](https://docs.microsoft.com/en-us/azure/architecture/patterns/materialized-view)

As illustrated above, with that pattern when a row of data is inserted in the source (blue) the view (orange) is updated with new values of the same key.

This approach can be really useful with streams of data. It allows to pre-calculate aggregates, or rather to keep them updated on the fly, rather than re-processing from scratch at query time. Let's see how that looks.

## Problem space

Say we have a stream of events coming from a fleet of devices (via [Event Hub](https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-about)). Each message comes with a value, of which we want to keep the latest value, on-going sum and count. We want to process data in 5-minute [tumbling windows](https://docs.microsoft.com/en-us/azure/stream-analytics/stream-analytics-window-functions).

When we initialize the stream (left below), we can insert the first rows in a SQL table (right), making sure they are distinct by key (DeviceId):

[![Inserting the first rows](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/stream_to_table01.png)](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/stream_to_table01.png)

Let's note how the "materialized **view**" pattern will manifest itself as a **table** in our database in this situation.

From there, each batch of new messages in the stream should update our table, instead of just appending them:

[![Following events are updating the records](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/stream_to_table02.png)](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/stream_to_table02.png)

And again later, this time with multiple events in our window:

[![More of the same](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/stream_to_table03.png)](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/stream_to_table03.png)

### Approach

The Azure native tool to solve the stream processing part is [Azure Stream Analytics](https://docs.microsoft.com/en-us/azure/stream-analytics/) (ASA). With it we can write a SQL query that will aggregate the events coming from the [input stream](https://docs.microsoft.com/en-us/azure/stream-analytics/stream-analytics-define-inputs) on our 5 minute time window.

```SQL
    SELECT
        SourceTimestamp,
        DeviceId,

        /*Below: LAST will return a single row here. MAX is there to appease the GROUP BY gods*/
        MAX(LAST(EventValue) OVER (PARTITION BY DeviceId LIMIT DURATION(minute, 5)) AS LastEventValue,

        SUM(EventValue) AS SumEventValue,
        COUNT(*) AS CountEvent
    FROM
        [SourceStream] TIMESTAMP BY SourceTimestamp
    GROUP BY
        DeviceId,
        TumblingWindow(minute,5)
```

We want to keep a backup of the output of the ASA job for multiple reasons, including the ability to monitor the drift (there should be none) and re-generate the "materialized view" (aka aggregate table) if needs be.

So we'll create a history table with the output of the ASA job in addition to our view:

[![First design](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/requirement01.png)](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/requirement01.png)

### Constraints

The main issue here is that ASA doesn't support updating a table via the [Azure SQL output](https://docs.microsoft.com/en-us/azure/stream-analytics/sql-database-output) at the time of writing.

From a theoretical perspective, there are 2 ways to deal with it.

**The first option** is to delegate to Azure SQL the role of maintaining the "materialized view" from the history table we created. This can be done via triggers (but let's not) or [indexed views](https://docs.microsoft.com/en-us/sql/relational-databases/views/create-indexed-views?view=azuresqldb-current). To be transparent I haven't tested that option, but I am a bit worried about the performance implications since indexed views slow down the inserts on their source tables.

**The other option** is to offload the update path to another compute resource, like [Azure Functions](https://docs.microsoft.com/en-us/azure/azure-functions/functions-overview).

### Solution

As the title of the article suggests, I decided to use Azure Functions to implement the materialized view pattern in this situation. It's the more scalable option, but it does require a little bit of code to wire everything together.

[![First solution](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/solution01.png)](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/solution01.png)

## Areas of interest

### ASA Query

The setup is straightforward for Stream Analytics. Here we have one input (Event Hub) and two outputs (Azure SQL, Azure Function).

The query will need to use the `with` [syntax](https://docs.microsoft.com/en-us/stream-analytics-query/with-azure-stream-analytics) (aka CTE / Common Table Expression) to serve an identical result set to our 2 outputs.

```SQL
WITH CTE1 AS (
    SELECT
        SourceTimestamp,
        DeviceId,
        /*Below: LAST will return a single row here. MAX is there to appease the GROUP BY gods*/
        MAX(LAST(EventValue) OVER (PARTITION BY DeviceId LIMIT DURATION(minute, 5)) AS LastEventValue,
        SUM(EventValue) AS SumEventValue,
        COUNT(*) AS CountEvent
    FROM
        [SourceStream] TIMESTAMP BY SourceTimestamp
    GROUP BY
        DeviceId,
        TumblingWindow(minute,5)
    )

/*******************************/

SELECT
    *
INTO
    [sql_history]
FROM CTE1;

/*******************************/

SELECT
    DeviceId,
    LastEventValue,
    SumEventValue,
    CountEvent
INTO
    [fun_matview]
FROM CTE1
```

### Function

C#
Python

## Conclusion
