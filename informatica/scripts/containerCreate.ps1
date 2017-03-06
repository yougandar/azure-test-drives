workflow container {
    param(
       
        [Parameter(Mandatory=$true)]
        [string]
        $destContainer,

        [Parameter(Mandatory=$true)]
        [string]
        $destStorageAccountName,

        [Parameter(Mandatory=$true)]
        [string]
        $destStorageAccountKey
      
    )

    InlineScript{
   
        
        $destContainer = $Using:destContainer
        $destStorageAccountName = $Using:destStorageAccountName
        $destStorageAccountKey = $Using:destStorageAccountKey
        
        Write-Output $destStorageAccountName,
      
        Write-Output $destContainer

        $destStorageCtx = New-AzureStorageContext -StorageAccountName $destStorageAccountName -StorageAccountKey $destStorageAccountKey
	
        New-AzureStorageContainer -Name $destContainer -Context $destStorageCtx -Permission Container

    }
    
}