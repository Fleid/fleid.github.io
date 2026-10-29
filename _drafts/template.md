---
# Required. bin/new-post fills in title, tags and permalink; bin/publish adds the date.
layout: post
title:  "Post title"
tags: Tag1 Tag2
permalink: /post-slug/
# Tags used so far: Azure PowerShell DevOps ALM Architecture Streaming Design ASA KeyVault ETL ADFv2
#   AzCLI VSCode SQL Product Meta Jekyll Kafka Implementation EventHub

# Optional, uncomment as needed.
# subtitle: "One line under the title"
# meta-description: "Search/social summary, ~150 characters (defaults to the post start)"
# cover-img: /assets/img/post-slug/cover.png       # wide banner behind the title
# thumbnail-img: /assets/img/post-slug/thumb.png   # small image next to the post on the home page
# share-img: /assets/img/post-slug/share.png       # image for LinkedIn/social previews
# readtime: false          # on by default (_config.yml)
# social-share: false      # LinkedIn share button, on by default
---

One or two sentences on what this post is about. Everything above the marker below is the excerpt
shown on the home page.

<!--more-->

## Problem space

What's the situation, and why it matters.

### Constraints

- First constraint
- Second constraint

## Solution

Images go in `assets/img/post-slug/`, with alt text that says what the picture shows:

![Diagram of the solution: source on the left, target on the right](/assets/img/post-slug/diagram.png)

Code blocks take a language for highlighting (SQL, PowerShell, bash, yaml, json...):

```PowerShell
Get-AzResource -ResourceGroupName "rg-example"
```

A [link to the docs](https://learn.microsoft.com/) and a footnote[^1].

## Conclusion

What to remember, and what's next.

[^1]: Footnote text.
