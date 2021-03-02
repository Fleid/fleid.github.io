---
layout: post
title:  "Updating Azure SQL from Azure Stream Analytics with a Function"
date:   2021-03-01 10:00:00 -0700
tags: Azure Design SQL ASA Streaming
permalink: /asa-update-sql/
---

Updating / merging records into an Azure SQL table, from Azure Stream Analytics, by using Azure Function.

<!--more-->

When we need to store the latest version of each row in a dataset generated from a stream, the recommended pattern is the [materialized view](https://docs.microsoft.com/en-us/azure/architecture/patterns/materialized-view).

[![Materialized view schema, from the Azure Architecture Center](https://docs.microsoft.com/en-us/azure/architecture/patterns/_images/materialized-view-pattern-diagram.png)](https://docs.microsoft.com/en-us/azure/architecture/patterns/materialized-view)

That patterns update the view with new values of the same key, rather than inserting new rows.

## Problem space

Let's say we have a stream of events coming from a fleet of devices. Each message comes with a value, of which we want to keep the latest value, sum and count.

When we initialize the stream (left below), we can insert the first rows in a SQL table (right), making sure they are distinct by key (DeviceId):

[![Inserting the first rows](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/stream_to_table01.png)](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/stream_to_table01.png)

From there, each batch of new messages in the stream should update our table, instead of just appending them:

[![Following events are updating the records](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/stream_to_table02.png)](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/stream_to_table02.png)

And again later, this time with multiple events in our [window](https://docs.microsoft.com/en-us/azure/stream-analytics/stream-analytics-window-functions) (here 5 minutes):

[![More of the same](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/stream_to_table03.png)](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/stream_to_table03.png)

The Azure native tool to solve the stream processing part is [Azure Stream Analytics](https://docs.microsoft.com/en-us/azure/stream-analytics/) (ASA). With it we can write a SQL query that will aggregates the events coming from the [input stream](https://docs.microsoft.com/en-us/azure/stream-analytics/stream-analytics-define-inputs) on our 5 minute time window.

Since we want to keep a backup of the output, we'll also create a history table with the output of the ASA job (5 minute batches):

[![First design](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/requirement01.png)](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202103_asa_update_sql/requirement01.png)

### Constraints

The main issue here is that ASA doesn't support updating an output to Azure SQL at the time of writing.

From a theoretical perspective, there are 2 ways to deal with it. Either we output our payload to another compute resource that will update the table for us, or we built that "materialized view" on top of the history table we created in SQL.

### Components and solution

## Areas of interest

### ASA Query

### Function

### HA / DR

## Conclusion
