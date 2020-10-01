---
layout: post
title:  "Hosting a blog with a custom domain and https on Azure for $2 per month"
date:   2020-09-30 10:00:00 -0700
tags: Azure AzCLI Design KeyVault PowerShell Meta 
permalink: /azure-static-blog/
---

A short article giving a high level picture of what's required to setup a static site (blog or other) on Azure, with a custom domain (root and www) with https.

<!--more-->

This is not a detailed walk-through. Instead I'll link to existing ones on the area that deserve it.

Noting that $1.5 out of the 2 mentioned in the tile are for the custom domain name and the associated SSL certificate (https). File hosting, CDN and networking in Azure cost less than 50 cents for this application. To be fair, this is not the most read blog of the Internet.

## Summary

The main components used are:

- From non-Microsoft providers
  - a **custom domain name** from a registrar of your chosing (I'm using [Gandi](https://www.gandi.net/en-CA)) - here `eiden.ca`
  - a **SSL certificate**, I recommend Namecheap ([PositiveSSL](https://www.namecheap.com/security/ssl-certificates/comodo/positivessl/)) to procure one. This certificate will need to be generated for the custom domain name created above
- In Azure
  - a **Storage Account** with [static web hosting](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website) enabled, to host your content
  - a **Key Vault** to help generate the certificate and hold it once issued
  - a **CDN Profile**, to cache the content and optimize performance and cost
  - a **DNS Zone**, to manage the custom domain and point the traffic towards the CDN profile

On a picture:

![Schema of the solution, all details will be explained below in this post](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/overall_schema.png)

*[figure 1 : Schema of the solution](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/overall_schema.png)*

Let's jump into the details.

## Point 1

a
