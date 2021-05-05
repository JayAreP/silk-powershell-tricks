param(
    [parameter(Mandatory)]
    [string] $target_rg,
    [parameter()]
    [string] $storage_container = 'silk',
    [parameter()]
    [string] $imageFileName = 'k2c-cnode-8-0-21-10.vhd'
)

$storage_accountname = 'images' + ( -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 10 | ForEach-Object {[char]$_})).ToLower()
$rg = Get-AzResourceGroup -Name $target_rg
$imageName = $imageFileName.replace('.vhd',$null)

# Create target storage account
Write-Host -ForegroundColor yellow "Creating Storage account $storage_accountname"
$sa = New-AzStorageAccount -Name $storage_accountname -ResourceGroupName $rg.ResourceGroupName -Location $rg.Location -SkuName Standard_LRS
$sc = $sa | New-AzStorageContainer -Name $storage_container 

# Generate storage contexts and 
Write-Host -ForegroundColor yellow "Copying $imageFileName to $storage_accountname"
$sakeys = $sa | Get-AzStorageAccountKey
$srcContext = New-AzStorageContext -Anonymous -StorageAccountName silkimages
$dstContext = New-AzStorageContext -StorageAccountName $sa.StorageAccountName -StorageAccountKey $sakeys[0].Value
Start-AzStorageBlobCopy -DestContainer $storage_container -SrcBlob $imageFileName -SrcContainer 'images' -DestContext $dstContext -Context $srcContext -DestBlob $imageFileName -Verbose 

# Wait for file to be copied
Get-AzStorageBlobCopyState -Blob $imageFileName -Container $storage_container -Context $dstContext -WaitForComplete

# Create Image
$imageURI = $sc.CloudBlobContainer.Uri.AbsoluteUri + '/' + $imageFileName
$imageConfig = New-AzImageConfig -Location $rg.Location
$imageConfig = Set-AzImageOsDisk -Image $imageConfig -OsType Linux -OsState Generalized -BlobUri $imageURI
New-AzImage -ImageName $imageName -ResourceGroupName $rg.ResourceGroupName -Image $imageConfig

