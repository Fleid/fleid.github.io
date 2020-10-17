---
layout: post
title:  "Running a blog with Jekyll on Azure"
date:   2020-09-30 10:00:00 -0700
tags: Azure AzCLI Design KeyVault PowerShell Meta Jekyll
permalink: /azure-jekyll-blog/
---

High level picture of hosting a static site (blog) on Azure with details on how to wire a custom domain (root and www) with HTTPS support. It's actually easier that it sounds.

<!--more-->

Let's start by noting that $2 out of the $2.5 mentioned in the title are for the custom domain name and associated SSL certificate (for HTTPS). Static content hosting, CDN ([content delivery network](https://en.wikipedia.org/wiki/Content_delivery_network)) and networking in Azure cost less than 50 cents per month for this application. To be fair, this is not the most read blog of the Internet.

Also I'm using [Jekyll](https://jekyllrb.com/) for this blog, and it's been good to me so far.

## Summary

The main components used are:
