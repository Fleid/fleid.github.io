# https://the.aamodt.family/rune/2020/01/08/tutorial-azure-website.html
# https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blob-static-website-how-to?tabs=azure-powershell#enable-metrics-on-static-website-pages


$tenantId = ""
$subscriptionId = ""
$resourceGroupName = "rg-static-jekyll"
$location = "canadacentral"
$storageAccountName = "sastaticjekyllcc"
$contentLocalPath = "C:\Users\fleide\Repos\Fleidlog\_site"

Connect-AzAccount -Tenant $tenantId -SubscriptionId $subscriptionId
az login --tenant $tenantId

New-AzResourceGroup `
    -Name $resourceGroupName `
    -Location $location

New-AzStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $storageAccountName `
    -Location $location `
    -SkuName "Standard_GRS" `
    -Kind StorageV2

$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -AccountName $storageAccountName
$ctx = $storageAccount.Context
Enable-AzStorageStaticWebsite -Context $ctx -IndexDocument "index.html" -ErrorDocument404Path "404.html"

#nano Gemfile.lock
# >> Add kramdown-parser-gfm (>= 1.0) to Jekyll
#bundle install

bundle exec jekyll clean
bundle exec jekyll build

# CDN endpoint can be done via ARM templates : https://docs.microsoft.com/en-us/azure/cdn/create-profile-endpoint-template
# For now via Portal > Via the Storage Account blade (from CDN it failed ><). If needed:
# Register-AzResourceProvider -ProviderNamespace Microsoft.Cdn
# New-AzADServicePrincipal -ApplicationId "205478c0-bd83-4e1b-a9d6-db63a3e1e1c8"

Get-AzStorageBlob -Container "`$web" -Context $ctx | Remove-AzStorageBlob

# CLI sinon ca merde les content types
#Get-ChildItem -Path $contentLocalPath -File -Recurse | Set-AzStorageBlobContent -Container "`$web" -Context $ctx -Properties @{ContentType = "text/html; charset=utf-8";}
az storage blob upload-batch -s $contentLocalPath -d '$web' --account-name $storageAccountName

# Ne pas oublier de purger le CDN a chaque upload
Get-AzCdnProfile | where-object {$_.Name -eq "eiden-ca"} |  Get-AzCdnEndpoint | Unpublish-AzCdnEndpointContent -PurgeContent "/*"

Write-Output $storageAccount.PrimaryEndpoints.Web

