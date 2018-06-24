$RGName = "CellenzaResourceGroupAsAServiceTESTV4"
$AzureADApplicationName = "CellenzaResourceGroupAsAService"
$AzureFunctionExternalName = "cellenzaexternalapi4976" 
$KeyVaultName1 = "cellenzaapi36"
$MySecretKeyVault = "mysecrets5786"
#
# Azure AD Identity of First Azure Function (internal) must have access to Keyvault used by the solution
# OK
$webapp = Get-AzureRmWebApp -ResourceGroupName $rgname -Name $AzureFunctionExternalName
Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVaultName1 -ObjectId $webapp.Identity.PrincipalId -PermissionsToSecrets Get, List
#
# Azure AD IDentity of the second Azure Function (Public) must have access to Keyvault dedicated to subscription secrets
# OK
# Question : Est ce que c'est pas l'identity de la Key Vault qu'il faudrait? validé, c'est pas la bonne
$AzureADApplication = Get-AzureADApplication -SearchString $AzureADApplicationName
Set-AzureRmKeyVaultAccessPolicy -VaultName $MySecretKeyVault -ObjectID $AzureADApplication.ObjectID -PermissionsToSecrets Get, List
#
# Store secrets into the second Key Vault (using credential of current user by default)
# OK
$SubscriptionCredential = Get-Credential (Get-AzureRmContext).account.id
$SubscriptionLoginSecret = ConvertTo-SecureString -String $SubscriptionCredential.username -AsPlainText -Force
$SubscriptionPasswordSecret = ConvertTo-SecureString -String $SubscriptionCredential.GetNetworkcredential().password -AsPlainText -Force
Set-AzureKeyVaultSecret -VaultName $MySecretKeyVault -Name 'SubscriptionLogin' -SecretValue $SubscriptionLoginSecret
Set-AzureKeyVaultSecret -VaultName $MySecretKeyVault -Name 'SubscriptionPassword' -SecretValue $SubscriptionPasswordSecret
#
# Reference subscription in the first KeyVault instance (Named with SubscriptionID of the subscription)
# OK
$SubscriptionVault = Get-AzurermKeyVault -VaultName $MySecretKeyVault -ResourceGroupName $MySecretsRG 
$SubscriptionSecret = ConvertTo-SecureString -String $($SubscriptionVault.VaultUri) -AsPlainText -Force
Set-AzureKeyVaultSecret -VaultName $KeyVaultName1 -Name $((Get-AzureRmContext).Subscription.ID) -SecretValue $SubscriptionSecret 

#
# A ce stade, il faut faire le lien entre WebApp et Application Azure AD Manuellement, cela reste à creuser
#


