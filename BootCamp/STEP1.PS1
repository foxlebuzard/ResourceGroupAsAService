# ConnectAzureAD
#LoginAzureAccount

$RGName = "CellenzaResourceGroupAsAServiceTESTV4"
$AzureRegion = "FranceCentral"
$StorageSKUName = "Standard_LRS"
$StorageAccountName3 = "cellenzaapi$(Get-Random -Minimum 0 -Maximum 99)"
$KeyVaultName1 = "cellenzaapi$(Get-Random -Minimum 0 -Maximum 99)"
$AuthorizationModuleStorageAccountMasterKeyName = "AuthorizationModuleStorageAccountMasterKey"
$MySecretRandom = (get-random -Minimum 1 -Maximum 9999)
$MySecretsRG = "mysecrets$MySecretRandom"
$MySecretKeyVault = "mysecrets$MySecretRandom"
#
# Variables for first Azure function (internal)
#
$MyAPIRandom = (get-random -Minimum 1 -Maximum 9999)
$ServiceAppPlanName = "ServiceAsaServiceAppPlan"
$AzureFunctionInternalName = "cellenzainternalapi$MyAPIRandom"
$AzureFunctionInternalStorageAccountname = "cellenzast$MyAPIRandom"
$AzureFunctionInternalAPIGitContent = "https://github.com/foxlebuzard/ResourceGroupAsAService/raw/master/resourcegroupasaserviceinternalapi.zip"
$AuthorizationModuleExpirationPeriod = 30
#
# Variables for second Azure function (internal)
#
$MyAPIRandom = (get-random -Minimum 1 -Maximum 9999)
$AzureFunctionExternalName = "cellenzaexternalapi$MyAPIRandom"
$AzureFunctionExternalStorageAccountname = "cellenzast$MyAPIRandom"
$AzureFunctionExternalAPIGitContent = "https://github.com/foxlebuzard/ResourceGroupAsAService/raw/master/resourcegroupasaservicepublicapi.zip"
#
# If user is invited, object is is not the same
#
$CurrentUserIdentity = (Get-AzureADUser -Filter "Mail eq 'benoit.Sautiere@cellenza.com'").userprincipalname

function Get-PublishingProfileCredentialsAzure($resourceGroupName, $functionAppNamr){   
 
    $resourceType = "Microsoft.Web/sites/config"
    $resourceName = "$functionAppNamr/publishingcredentials"
 
    $publishingCredentials = Invoke-AzureRmResourceAction -ResourceGroupName $resourceGroupName -ResourceType $resourceType -ResourceName $resourceName -Action list -ApiVersion 2015-08-01 -Force
 
    return $publishingCredentials
}
 
#function to get bearer token from publishing profile (source : http://blog.octavie.nl/index.php/2017/04/20/get-the-default-azure-function-key-with-powershell)
function Get-KuduApiAuthorisationHeaderValueAzure($resourceGroupName, $functionAppNamr)
{
 
    $publishingCredentials = Get-PublishingProfileCredentialsAzure $resourceGroupName $functionAppNamr
 
    return ("Basic {0}" -f [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $publishingCredentials.Properties.PublishingUserName, $publishingCredentials.Properties.PublishingPassword))))
}
 
#function to get the Master Key using End point and passing bearer tocken in Authorization Header
function Get-MasterAPIKey($kuduApiAuthorisationToken, $functionAppNamr)
{
 
    $apiUrl = "https://$functionAppNamr.scm.azurewebsites.net/api/functions/admin/masterkey"
    
    $result = Invoke-RestMethod -Uri $apiUrl -Headers @{"Authorization"=$kuduApiAuthorisationToken;"If-Match"="*"} 
     
    return $result
} 
#function to get the Admin keys
function Get-HostAPIKeys($kuduApiAuthorisationToken, $functionAppNamr, $masterKey ){
     $masterKey
     $apiUrl2 = "https://$functionAppNamr.azurewebsites.net/admin/host/keys?code="
     $apiUrl=$apiUrl2 + $masterKey.masterKey.ToString()
     $apiUrl
     $result = Invoke-WebRequest $apiUrl
    return $result
}


#
# TODO Check Powershell running in elevated mode for module installation
#

#
# For dev purpose
#
#$KeyVaultName1 = "cellenzaapi70"
#$StorageAccountName3 = "cellenzaapi4"
#$MySecretsRG = "mysecrets9203"
#$AzureFunctionInternalStorageAccountname = "Cellenzast9397"
#$AzureFunctionInternalName = "cellenzainternalapi9397"

$TestPowershellModule = get-module -ListAvailable "AzureRmStorageTable"
if ($TestPowershellModule -eq $null)
{
    Warning "Required Powershell module AzureRmStorageTable is not present on this system. Please install it and relaunch the script."
    exit
}
#
# Create the Resource Group
# OK
$CheckRG = Get-AzureRmResourceGroup $RGName -ErrorAction SilentlyContinue
If($CheckRG -eq $null)
{
    #
    # Required Resource Group does not exists, create It
    #
    New-AzureRmResourceGroup -Name $RGName -Location $AzureRegion
}
Else
{
    Write-Warning "Required Resource Group $RGName Already exists."
    #
    # Todo : Force deletion then create the Resource Group if Force parameter value is $True
    #
}
#
# Create required storage account
# OK
$checkstorage = Get-AzureRmStorageAccount -Name $StorageAccountName3 -ResourceGroupName $rgname -ErrorAction SilentlyContinue
If ($checkstorage -eq $null)
{
    Write-Host "Required Storage Account $StorageAccountName3 does not exists, create it."
    New-AzureRmStorageAccount -ResourceGroupName $RGName -AccountName $StorageAccountName3 -Location $AzureRegion -SKUName $StorageSKUName -Kind StorageV2 -EnableHttpsTrafficOnly $True
    #
    # Create Security Context, Azure table and content
    #
    $keys = Get-AzureRmStorageAccountKey -ResourceGroupName $RGName -Name $StorageAccountName3
    $context = New-AzureStorageContext -StorageAccountName $StorageAccountName3 -StorageAccountKey $keys[0].value
    "AuthorizedCallers AuthorizedEnvironments AuthorizedIAMTemplateRole AuthorizedPolicyAssignment DefaultCostCenter".Split() | new-AzureStorageTable -Context $context
    Import-Module -Name AzureRmStorageTable
    $table = Get-AzureStorageTableTable -resourceGroup $RGName -tableName "Authorizedcallers" -storageAccountName $StorageAccountName3
    $partitionkey = (Get-AzureRmContext).Subscription.ID
    $rowkey = ((Get-AzureRmContext).account).id
    Add-StorageTableRow -table $table -partitionKey $partitionKey -rowKey $rowkey -property @{"Authorized"="true";"AuthorizedCostCenters"="ITDEPT,FINANCEDEPT";"AuthorizedDefaultRegion"= "WestEurope";
    "AuthorizedEnvironments"="TESTS";"AuthorizedRegions"="WestEurope,NorthEurope"}
    $table = Get-AzureStorageTableTable -resourceGroup $RGName -tableName "AuthorizedEnvironments" -storageAccountName $StorageAccountName3
    $partitionkey = (Get-AzureRmContext).Subscription.ID
    $rowKey = "TESTS"
    Add-StorageTableRow -table $table -partitionKey $partitionKey -rowKey $rowkey
    $table = Get-AzureStorageTableTable -resourceGroup $RGName -tableName "DefaultCostCenter" -storageAccountName $Storageaccountname3
    $partitionkey = (Get-AzureRmContext).Subscription.ID
    $rowkey = ((Get-AzureRmContext).account).id
    Add-StorageTableRow -table $table -partitionKey $partitionKey -rowKey $rowkey -property @{"CostCenter"= "ITDEPT"}
}
Else
{
    Write-Host "Required Storage Account $StorageAccountName3 already exists."
    $keys = Get-AzureRmStorageAccountKey -ResourceGroupName $RGName -Name $StorageAccountName3
}
#
# Create KeyVault used by the solution and Store Storage Account primary key
# OK
$checkKeyVault  = Get-AzureRmKeyVault -Name $KeyVaultName1 -ErrorAction SilentlyContinue
If ($checkKeyVault -eq $null)
{
    Write-Host "Required instance of Keyvault $KeyVaultName1 does not exists, create it."  
    New-AzureRmKeyVault -Name $KeyVaultName1 -ResourceGroupName $RGName -Location $AzureRegion -Sku Standard
    Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVaultName1 -UserPrincipalName $CurrentUserIdentity -PermissionsToKeys create, import, delete, list -PermissionsToSecrets set, delete
    $Secret = ConvertTo-SecureString -String $Keys[0].value -AsPlainText -Force
    Set-AzureKeyVaultSecret -VaultName $KeyVaultName1  -Name $AuthorizationModuleStorageAccountMasterKeyName -SecretValue $Secret
}
Else
{
    Write-Host "Required instance of Keyvault $KeyVaultName1 already exists."  
}
#
# Create dedicated resource group to store subscription secrets 
# OK
$checkrg = Get-AzureRmResourceGroup -Name MySecretsRG -ErrorAction SilentlyContinue
If ($checkrg -eq $null)
{ 
    Write-Host "Required ResourceGroup $MySecretsRG does not exists, create it."
    New-AzureRmResourceGroup -Name $MySecretsRG -Location $AzureRegion
}
Else
{
    Write-Host "Required ResourceGroup $MySecretsRG already exists."
}
#
# Create dedicated secret to store current subscription secret
# OK
$checkvault = Get-AzureRmKeyVault -VaultName $MySecretKeyVault -ErrorAction SilentlyContinue
if ($checkvault  -eq $null)
{
    Write-Host "Required Key Vault instance $MySecretKeyVault does not exists, create it."
    New-AzureRmKeyVault -Name $MySecretKeyVault -ResourceGroupName $MySecretsRG -Location $AzureRegion -Sku Standard
    Set-AzureRmKeyVaultAccessPolicy -VaultName $MySecretKeyVault -UserPrincipalName $CurrentUserIdentity -PermissionsToKeys create, import, delete, list -PermissionsToSecrets set, delete, List, Get
}
Else
{
    Write-Host "Requires Key Vault instance $MySecretKeyVault already exists."
}
#
# Create Storage Account for first Azure Function (Internal)
# OK
$teststorage = get-AzureRmStorageAccount -ResourceGroupname $RGName  -AccountName $AzureFunctionInternalStorageAccountname  -ErrorAction SilentlyContinue
If ($teststorage -eq $null)
{
    Write-Host "Required Storage Account $AzureFunctionInternalStorageAccountname does not exists, create it."
    New-AzureRmStorageAccount -ResourceGroupname $RGName  -AccountName $AzureFunctionInternalStorageAccountname -Location $AzureRegion -Skuname $StorageSKUName
}
Else
{
    Write-Host "Required Storage Account $AzureFunctionInternalStorageAccountname already exists."
}
#
# Get Keys of newly created storage account
# OK
$Keys = Get-AzureRmStorageAccountKey -ResourceGroupName $RGName -Name $AzureFunctionInternalStorageAccountname
#
# Create the Service App plan that will be hosting the two Azure Functions
# OK
$AppServicePlan = Get-AzureRmAppServicePlan -Name $ServiceAppPlanName -ResourceGroupName $RGName -ErrorAction SilentlyContinue
If ($AppServicePlan -eq $null)
{
    Write-host "Required Service App Plan $ServiceAppPlanName does not exists in Resource Group $RGName, will be created." 
    $AppServicePlan = New-AzureRmAppServicePlan -Name $ServiceAppPlanName -ResourceGroupName $RGName -Tier Basic -Location $AzureRegion
}
Else
{
    Write-host "Required Service App Plan $ServiceAppPlanName already exists in Resource Group $RGName." 
}
#
# Create FunctionApp
#
#$webApp = New-AzureRmWebApp -ResourceGroupName AADAppAuthDemo -AppServicePlan $appServicePlan.Id -Name AADAppAuthDemoSite -Location usgovvirginia
# TODO : Create Web app on dedicated app plan
#
$testwebapp = Get-AzureRmWebApp -ResourceGroupName $rgname -Name $AzureFunctionInternalName -ErrorAction SilentlyContinue
If ($testwebapp  -eq $null)
{
    #
    # Todo : intégrer association App Plan
    #
    Write-Host "Azure Function Web App $AzureFunctionInternalName does not exists. Create it." 
    New-AzureRmResource -ResourceType 'Microsoft.Web/Sites' -ResourceName $AzureFunctionInternalName -Kind 'Functionapp' -Location $AzureRegion -ResourceGroupName $RGName -Properties @{} -Force
}
Else
{
    Write-Host "Azure Function Web App $AzureFunctionInternalName already exists."
}
#
# Configuring Application Settings
#
$AppSettings = @{}
$StorageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=' + $AzureFunctionInternalStorageAccountname + ';AccountKey=' + $Keys[0].value
#
# bug avec ces paramètres : 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING' = $StorageAccountConnectionString;'WEBSITE_CONTENTSHARE' = $AzureFunctionInternalStorageAccountname
#
#$AppSettings = @{'AzureWebJobsDashboard' = $StorageAccountConnectionString;'AzureWebJobsStorage'=$StorageAccountConnectionString;'FUNCTIONS_EXTENSION_VERSION' = '~1';'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING' = $StorageAccountConnectionString;'WEBSITE_CONTENTSHARE' = $AzureFunctionInternalStorageAccountname; AuthorizationModuleExpirationPeriod = "$AuthorizationModuleExpirationPeriod"; 'AuthorizationModuleKeyVault' = $RGName; 'AuthorizationModuleStorageAccountMasterKey' = $AuthorizationModuleStorageAccountMasterKeyName;'AuthorizationModuleStorageAccountName'=$StorageAccountName3 }

$AppSettings = @{
    'AzureWebJobsDashboard' = $StorageAccountConnectionString;
    'AzureWebJobsStorage'=$StorageAccountConnectionString;
    'FUNCTIONS_EXTENSION_VERSION' = '~1';
    'AuthorizationModuleExpirationPeriod' = "$AuthorizationModuleExpirationPeriod"; 
    'AuthorizationModuleKeyVault' = $KeyVaultName1; 
    'AuthorizationModuleStorageAccountMasterKey' = $AuthorizationModuleStorageAccountMasterKeyName;
    'AuthorizationModuleStorageAccountName'=$StorageAccountName3;
    'WEBSITE_RUN_FROM_ZIP'=$AzureFunctionInternalAPIGitContent
}
#
# Inject Application Settings
# OK
Set-AzureRmWebApp -ResourceGroupName $RGName  -Name $AzureFunctionInternalName -AppSettings $AppSettings
#
# Enforce HTTPS access only at WebApp Level
# OK
Set-AzureRmWebApp -ResourceGroupName $RGName -Name $AzureFunctionInternalName -HttpsOnly $true | Out-Null
#
# Disable PHP support, X64 architecture
# OK
Set-AzureRmWebApp -ResourceGroupName $RGName -Name $AzureFunctionInternalName -PhpVersion Off
Set-AzureRmWebApp -ResourceGroupName $RGName -Name $AzureFunctionInternalName -Use32BitWorkerProcess $False
#
# Enable Managed Identity Service at WebApp Level
# OK
Set-AzureRmWebApp -ResourceGroupName $RGName -Name $AzureFunctionInternalName -AssignIdentity $true
$WebApp = Get-AzureRmWebApp -ResourceGroupName $RGName -Name $AzureFunctionInternalName 
#
# Give Service Principal permission to get secrets from Keyvault instance used by the solution
# OK
Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVaultName1 -ObjectId $webapp.Identity.PrincipalId -PermissionsToSecrets Get, List
#
# Restart WebApp to finalize operations
# OK
Restart-AzureRmWebApp -ResourceGroupName $RGName -Name $AzureFunctionInternalName 
#
# Restrict Verbs to be used in Azure Function
# Configuration manuelle OU ou simplement bien configurer le fichier Function.JSON!!!!!!!!!!!!!!!!!!!!
#
# Extract Azure Function API Key for configuration as secret for the API in the second Azure Function
#
# http://bloggingoncloud.com/get-azure-function-app-master-key-host-key-by-api-end-point-programmatically/
$accesstoken = Get-KuduApiAuthorisationHeaderValueAzure $RGName $AzureFunctionInternalName
$masterKey=Get-MasterAPIKey $accessToken $AzureFunctionInternalName
$allkeys=Get-HostAPIKeys $accessToken  $AzureFunctionInternalName $masterkey
#
# Publication de l'API publique Resource Group as a service
#
# BUG POTENTIEL ICI SUR LA GENERATION DE L'URL
#
$ReadKeyvaletURL = "https://" + $AzureFunctionInternalStorageAccountname + ".azurewebsites.net/api/Get-ValetKeyforAzureTableRead?code=" + $allkeys[0].masterkey
#
# Create the Storage Account to be used by the public Azure Function instance
#
$teststorage = Get-AzurermStorageAccount -ResourceGroupName $RGName -Name $AzureFunctionExternalName -ErrorAction SilentlyContinue
If ($teststorage -eq $null)
{
    Write-Host "Required Storage Account $AzureFunctionExternalName does not exists. Create it."
    New-AzureRmStorageAccount -ResourceGroupname $RGName  -AccountName $AzureFunctionExternalName -Location $AzureRegion -Skuname $StorageSKUName
}
Else
{
    Write-Host "Required Storage Account $AzureFunctionExternalName already exists."
}
#
# Get Keys of newly created storage account
#
$Keys = Get-AzureRmStorageAccountKey -ResourceGroupName $RGName -Name $AzureFunctionExternalName
#
# Create Azure Function for public usage
# TODO Reuse App Plan created for the first Azure Function
$testwebapp = Get-AzureRmWebApp -ResourceGroupName $RGName -Name $AzureFunctionExternalName -ErrorAction SilentlyContinue
If ($testwebapp -eq $null)
{
    Write-Host "Azure Function Web App $AzureFunctionExternalName does not exists. Create it." 
    New-AzureRmResource -ResourceType 'Microsoft.Web/Sites' -ResourceName $AzureFunctionExternalName -Kind 'Functionapp' -Location $AzureRegion -ResourceGroupName $RGName -Properties @{} -Force
}
Else
{
    Write-Host "Azure Function Web App $AzureFunctionExternalName already exists." 
}
#
# Configure Application Settings
#
$StorageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=' + $AzureFunctionExternalName + ';AccountKey=' + $Keys[0].value
$AppSettings = @{}
$AppSettings = @{
    'AzureWebJobsDashboard' = $StorageAccountConnectionString; 
    'AzureWebJobsStorage'=$StorageAccountConnectionString;
    'FUNCTIONS_EXTENSION_VERSION' = '~1';
    'AuthorizationModuleKeyVault' = $KeyVaultName1; 
    'AuthorizationModuleBackupTagName’ = "BACKUP";
    'AuthorizationModuleCostCenterTagName’ = "CostCenter";
    'AuthorizationModuleCreatedOnTagName’ = "CreatedOn";
    'AuthorizationModuleDefaultCostCenterTableName’ = "DefaultCostCenter";
    'AuthorizationModuleDisplayName’ = "DisplayName";
    'AuthorizationModuleEnvironnementTagname’ = "Environnement";
    'AuthorizationModuleIAMTemplateRoleTable’ = "AuthorizedIAMTemplateRole";
    'AuthorizationModuleKeyVaultSubscriptionLogin’ = "SubscriptionLogin";
    'AuthorizationModuleKeyVaultSubscriptionPassword’ = "SubscriptionPassword";
    'AuthorizationModuleOwnerTagName’ = "Owner";
    'AuthorizationModulePolicyAssignmentTable’ = "AuthorizedPolicyAssignment";
    'AuthorizationModuleProjectTagName’ = "ProjectName";
    'AuthorizationModuleSLAName’ = "SLALevel";
    'AuthorizationModuleStorageAccountName’ = $StorageAccountName3;
    'AuthorizationModuleAuthorizeTableName’ = "AuthorizedCallers";
    'WEBSITE_RUN_FROM_ZIP' = $AzureFunctionExternalAPIGitContent;
    'AuthorizationModuleReadKeyvaletURL’ = "$ReadKeyvaletURL"
  }
Set-AzureRmWebApp -ResourceGroupName $RGName  -Name $AzureFunctionExternalName -AppSettings $AppSettings
#
# Enforce HTTPS access only at WebApp Level
#
Set-AzureRmWebApp -ResourceGroupName $RGName -Name $AzureFunctionExternalName -HttpsOnly $true | Out-Null
#
# Disable PHP support, X64 architecture
#
Set-AzureRmWebApp -ResourceGroupName $RGName -Name $AzureFunctionExternalName -PhpVersion Off
Set-AzureRmWebApp -ResourceGroupName $RGName -Name $AzureFunctionExternalName -Use32BitWorkerProcess $False
Restart-AzureRmWebApp -ResourceGroupName $RGName -Name $AzureFunctionExternalName 
#
# Enable Managed Service Identity
#
Set-AzureRmWebApp -ResourceGroupName $RGName -Name $AzureFunctionExternalName  -AssignIdentity $true
$WebApp = Get-AzureRmWebApp -ResourceGroupName $RGName -Name $AzureFunctionExternalName 
#
# Create Application Secret (AKA Client Secret) limited to one year
#
$Guid = New-Guid
$startDate = Get-Date    
$PasswordCredential = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordCredential
$PasswordCredential.StartDate = $startDate
$PasswordCredential.EndDate = $startDate.AddYears(1)
$PasswordCredential.KeyId = $Guid
$PasswordCredential.Value = ([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($Guid))))+"="
Write-Warning "Client Secret to be used by API consumers : $($PasswordCredential.Value)"
#
# Creating AzureAD Application for our Web Application
# https://www.mavention.nl/blogs/creating-azure-ad-app-registration-with-powershell-part-1/
#
$AzureADAppURL = (Get-AzureRmWebApp -ResourceGroupName $rgname -Name $AzureFunctionExternalName).hostnames
If(!($myApp = Get-AzureADApplication -Filter "DisplayName eq '$($AzureADApplicationName)'"  -ErrorAction SilentlyContinue))
{
    $ReplyURLs = @($AzureADAppURL, $AzureADAppURL, "https://localhost:12345")
  #  $svcprincipal = Get-AzureADServicePrincipal -All $true | ? { $_.DisplayName -match "Windows Azure Active Directory" }
    ### Microsoft Graph
    $svcprincipal = Get-AzureADServicePrincipal -All $true | ? { $_.DisplayName -match "Microsoft Graph" }
	$reqGraph = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
	$reqGraph.ResourceAppId = $svcprincipal.AppId

	##Delegated Permissions
	$delPermission1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "0e263e50-5827-48a4-b97c-d940288653c7","Scope" #Access Directory as the signed in user

#	##Application Permissions
#	$appPermission1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "62a82d76-70ea-41e2-9197-370581804d09","Role" #Read and Write All Groups
#	$appPermission2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "19dbc75e-c2e2-444c-a770-ec69d8559fc7","Role" #Read and Write directory data

#	$reqGraph.ResourceAccess = $delPermission1, $appPermission1, $appPermission2
$reqGraph.ResourceAccess = $delPermission1		
#
# Attention, c'est une permission Graph, pas Windows Azure Active Directory
#
    $myApp = New-AzureADApplication -DisplayName $AzureADApplicationName -IdentifierUris $AzureADAppURL -Homepage ($AzureADAppURL).tostring()  -PasswordCredentials $PasswordCredential -RequiredResourceAccess $reqGraph
    #
    # Create Service Principal and Link it to Azure Application
    #
    $MyAppSP = New-AzureADServicePrincipal -AccountEnabled $true -AppId $MyApp.AppId -AppRoleAssignmentRequired $true -DisplayName $AzureADApplicationName -Tags {WindowsAzureActiveDirectoryIntegratedApp}

    Write-Host "Application Name: 	$appName"
    Write-Host "Application Id:   	$($myApp.AppId)"
    Write-Host "Secret Key:       	$($PasswordCredential.Value)"
}
Else
{
    Write-Host "Azure AD Application $AzureADApplicationName  already exists."
}
#
# Grant users in the Azure AD Tenant to consume application
# OK
$AzureADUsers = Get-AzureADUser
$ProcessedUsers = 1
ForEach($AzureADUser in $AzureADUsers)
{
    Write-Host "Processing $(($AzureADUser).UserPrincipalName) $ProcessedUsers/$($AzureADUsers.Count)"
    new-AzureADUserAppRoleAssignment -ObjectId $AzureADUser.ObjectId -PrincipalId $AzureADUser.ObjectId -ResourceId $MyAppSP.ObjectId -Id ([Guid]::Empty)
    $ProcessedUsers +=1
}

