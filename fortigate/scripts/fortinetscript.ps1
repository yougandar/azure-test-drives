<#
    .DESCRIPTION
THis gets the licensefile for one of the ISV. Even though the template is public, it wont run in any account.


    .NOTES
        AUTHOR: PK
        LASTEDIT: Mar 30, 2016
#>
workflow Get-FortinetLicense
{


    [OutputType([string])]
	
	
    param (
    [Parameter(Mandatory=$true)]
    [string] 
    $Tdid,
    
    [Parameter(Mandatory=$true)]
    [string] 
    $accountName,
    
    [Parameter(Mandatory=$true)]
    [string] 
    $variableName,
    
    [Parameter(Mandatory=$true)]
    [string] 
    $ISVName,
    
    [Parameter(Mandatory=$true)]
    [string] 
    $credentialName,
    
    [Parameter(Mandatory=$true)]
    [string] 
    $resourceGroupName
    
    )
    
    #The name of the Automation Credential Asset this runbook will use to authenticate to Azure.
    $CredentialAssetName = $credentialName

    #Get the credential with the above name from the Automation Asset store
    $Cred = Get-AutomationPSCredential -Name $CredentialAssetName
    if(!$Cred) {
        Throw "Could not find an Automation Credential Asset named '${CredentialAssetName}'. Make sure you have created one in this Automation Account."
    }

    #Connect to your Azure Account
    #Add-AzureAccount -Credential $Cred
    Add-AzureRmAccount -Credential $Cred
	
	

    $Account1 = $accountName
 #$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
#$headers.Add("x-api-key", 'cmwPU5D5T2aJWaGjtVlon7VqSghAkl6C1oOfrhxB')
	
	$headers = @{
    'x-api-key'= 'cmwPU5D5T2aJWaGjtVlon7VqSghAkl6C1oOfrhxB'
}
	
	
	$fnbody = @{
    testdriveid=$Tdid
}
$json = $fnbody | ConvertTo-Json
$invokeUrl = 'https://sxmguodehi.execute-api.us-west-2.amazonaws.com/prod/licenseManager/'+ $Tdid +'/reserveLicense?apikey=cmwPU5D5T2aJWaGjtVlon7VqSghAkl6C1oOfrhxB'
$response = Invoke-RestMethod $invokeUrl -Method Put -Headers $headers -Body $json -ContentType 'application/json'
	
   # $blobURL ='https://fortinetkeys.blob.core.windows.net/licensefiles/arm_template-3.json.zip?st=2016-03-29T03%3A44%3A25Z&se=2016-03-29T07%3A04%3A25Z&sp=r&sv=2015-04-05&sr=b&sig=8qXrBQF0AWcXU6XXOwjCvQhiycy4mqvMmrZhYLdaW4k%3D'
    
	
	
	Write-Output "Current Values of the variables For ISV"
	Write-Output $ISVName
  Write-Output $response


	
	#Set-AutomationVariable –Name TDidVariable –Value $Tdid
	#Set-AutomationVariable –Name LicenseBlobUrl –Value 'http://yejdjtjtj'
	
	Set-AutomationVariable -Name $variableName -Value $response.blobUrl
	
	$LicenseBlobURL = Get-AutomationVariable -Name $variableName 
		
		
		
	
	    Write-Output "New Values of the variables"	

        Write-Output $LicenseBlobURL
    
   
	
	
	
	
	
	
	

}
