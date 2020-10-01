---
layout: post
title:  "Hosting a blog with a custom domain and https on Azure for $2 per month"
date:   2020-09-30 10:00:00 -0700
tags: Azure AzCLI Design KeyVault PowerShell Meta 
permalink: /azure-static-blog/
---

A short article giving a high level picture of what's required to set up a static site (blog or other) on Azure, with a custom domain (root and www) with https.

<!--more-->

This is not a detailed walk-through. Instead I'll link to existing ones on the area that deserve it.

Noting that $1.5 out of the 2 mentioned in the tile are for the custom domain name and the associated SSL certificate (https). File hosting, CDN and networking in Azure cost less than 50 cents for this application. To be fair, this is not the most read blog of the Internet.

## Summary

The main components used are:

- From non-Microsoft providers
  - a **custom domain name** from a registrar of our choosing (I'm using [Gandi](https://www.gandi.net/en-CA)) - here `eiden.ca`
  - a **SSL certificate**, I recommend Namecheap ([PositiveSSL](https://www.namecheap.com/security/ssl-certificates/comodo/positivessl/)) to procure one. This certificate will need to be generated for the custom domain name we created above (we'll see how). **THIS IS IF** you want https for the **root** of a custom domain ([https://eiden.ca](https://eiden.ca)), even if you just want it to redirect to **www**. This was a must have for me, and the reason for the existence of this very article. If you don't care, you can use the included Azure CDN managed certificate (which at the time of writing doesn't support root).
- In Azure
  - a **Storage Account** with [static web hosting](https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website) enabled, to host our content
  - a **Key Vault** to help generate the certificate and hold it once issued
  - a **CDN Profile**, to cache the content and optimize performance and cost
  - a **DNS Zone**, to manage the custom domain and point the traffic towards the CDN profile

On a picture:

![Schema of the solution, all details will be explained below in this post](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/overall_schema.png)

*[figure 1 : Schema of the solution](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/overall_schema.png)*

Let's jump into the details.

## Step 1 and 2 : Starting with the Static Website and the CDN Profile

Let's follow the **parts 1 and 2** from this [awesome tutorial](https://www.wrightfully.com/azure-static-website-custom-domain-https) from John M. Wright.

In part 2, I've personally used the `Azure CDN from Microsoft` and it went great.

At this point, what we should have is this:

![Step 1 : a storage account with static hosting and a CDN endpoint](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/step1.png)

*[figure 2 : a storage account with static hosting and a CDN endpoint](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/step1.png)*

We can already see our content online at the following URLs:

- `https://<sa>.web.core.windows.net`, directly from the storage account
- `https://<cdn>.azureedge.net`, from the CDN endpoint

To be noted that to upload our content to the `$web` container of the storage account, the best option is to use the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli). I tend to prefer PowerShell but `Set-AzStorageBlobContent` doesn't manage the content-types of the files it uploads. The syntax in the CLI is straightforward (in a PowerShell host, cmd or bash terminal) :

```PowerShell
# Here the parameter syntax is PowerShell and I'm already logged via az login
$contentLocalPath = "C:\..."
$storageAccountName = "mystorageaccount"
az storage blob upload-batch -s $contentLocalPath -d '$web' --account-name $storageAccountName
```

## Step 3 : Adding a DNS Zone

Let's switch to the **part 3** of this [exhaustive guide](https://the.aamodt.family/rune/2020/01/08/tutorial-azure-website.html#step-3-set-up-dns-configuration) from Rune Aamodt.

We will not only create a record for the **www subdomain** (type `CNAME`, alias record set to the CDN endpoint) but also for the **root (apex) domain** (type `A`, alias record set to the same CDN endpoint).

This is how it should look now (**bold** being the ones we created above):
  
|Name|Type|TTL|Value|Alias resource type|Alias target|Comment|
|---|---|---|---|---|---|---|
|**@**|**A**|3600|-|Azure CDN|eiden-ca|**Root/apex domain record**|
|@|NS|172800|ns1-07.azure-dns.com...|||Azure stuff|
|@|SOA|3600|Email:... Host: ns1-07.azure-dns.com...|||Azure stuff|
|@|MX|3600|10 spool.mail.gandi.net.,50 fb.mail.gandi.net.|||Gandi stuff, for the email addresses of the domain|
|@|TXT|3600|"v=spf1 include:_mailcust.gandi...|||Gandi stuff, for the email addresses of the domain|
|cdnverify|CNAME|3600|cdnverify.eiden-ca.azure...|||Verification record created automatically for alias record sets|
|sa|CNAME|3600|external.simpleanalytics.com.|||Record required by the analytics provider I use here|
|**www**|**CNAME**|3600|-|Azure CDN|eiden-ca|**www subdomain record**|
|cdnverify.www|CNAME|3600|cdnverify.eiden-ca.azure...|||Verification record created automatically for alias record sets|

This is where we will have to log in to the admin portal of our Domain Registrar (Gandi, Namecheap...) to switch our custom domain to use external nameservers. We will provide the 4 Azure ones listed in our DNS zone. On **Gandi** it looks like this:

![Step 3 : Screenshot of the admin portal in Gandi](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/step3_gandi.jpg)

*[figure 3 : updating nameservers in Gandi](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/step3_gandi.jpg)*

Now that we have the DNS Zone setup, the situation looks like that:

![Step 3 : A DNS Zone is added to the picture, but the CDN profile still needs to be updated](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/step3.png)

*[figure 4 : A DNS Zone is added to the picture, but the CDN profile still needs to be updated](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/step3.png)*

Now let's head back to the CDN endpoint to add the custom domains we just created here.

## Step 4 : Enabling HTTPS for the CDN Endpoint Custom Domains

We will head back to the first tutorial, but before let's quickly sum up the situation. As I mentioned in the summary, Azure CDN offers managed certificate for https, but at the time of writing they are not available for the root / apex domain.

This is why we need to bring our own.

Before heading back into the tutorial, let's review the 5 steps of that process:
 - 1 : In a new Azure Key Vault, create a new certificate that will be issued by a **non-integrated** CA (Namecheap). Contrary to what's in the guide, use **PKCS#12** (even if you don't understand what it means, like me, it's just easier)
 - 2 : Download the CSR (`Certificate Signing Request`) from Azure Key Vault, upload it to your SSL certificate to get processed, get the PKCS#12 file back into Azure Key Vault (`merge signed request`)
 - 3 : Back in the CDN Endpoint, create the custom domains (root and www), with https, using our own certificate, from Key Vault

So let's head back to [the tutorial](https://www.wrightfully.com/azure-static-website-custom-domain-https) from John for **part 4 and 5** (sorry there's no direct link) explains everything in details.

## Step 5 : Adding CDN rules

Finally, we need to add some rules in the CDN Rules engine to sort traffic coming from our domains on both http and https. I settled on having my default domain be the www subdomain (rather than the root/apex), you can adapt the rules below for a different result:

- Rule 1 : `http://` requests need to be redirect to `https://www...`
- Rule 2 : root requests need to be redirected to `https://www...`

For that we can get inspiration from the [step 5](https://the.aamodt.family/rune/2020/01/08/tutorial-azure-website.html#step-5-enforce-https) of the second guide end assemble something looking like:

![Step 5 : Screenshot of the CDN endpoint rules engine configuration, detailed below](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/step5_rules.jpg)

*[figure 5 : Rules to manage traffic across domains and protocols](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/step5_rules.jpg)*

The details of these rules:

- Rule 1
  - Name : **http2https**
  - If Request **protocol**
    - Operator : `Equals`
    - Request URL : `HTTP`
  - Then URL redirect
    - Type : `Moved (301)`
    - Protocol : `HTTPS`
    - Hostname : `www.eiden.ca`
- Rule 2
  - Name : **root2www**
  - If Request **URL**
    - Operator : `Begins with`
    - Request URL : `https://eiden.ca`
    - Case transform : `To lowercase`
  - Then URL redirect
    - Type : `Moved (301)`
    - Protocol : `HTTPS`
    - Hostname : `www.eiden.ca`

The picture is now complete:

![Schema of the solution, everything has been explained above](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/overall_schema.png)

*[figure 6 : The whole thing wired up together](https://raw.githubusercontent.com/Fleid/fleid.github.io/master/_posts/202009_azure_static_blog/overall_schema.png)*

## Closing

So really, $2 per month?

- [Namecheap](https://www.namecheap.com/security/ssl-certificates/comodo/positivessl/) SSL Certificate : $9 per year
- [Gandi](https://www.gandi.net/en-CA) custom domain (`.ca`) : $15 per year
- Azure everything : $.5 per month

**Total : $2.5 per month!**