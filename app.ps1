$logPath = "C:\ASC\LOG"
$logFile = "task2.log"

$resourceGroupName = "tomasiea-test"
$vmReportFile = "C:\ASC\RAPORT\VMReport.txt"
$tagReportFile = "C:\ASC\RAPORT\TagReport.txt"
$location = "North Europe"

$vmUsername = "tomasiea"
$sqlServerName = "tomasiea-test" 
$sqlAdminUsername = "sqladmin"
$sqlDbName = "tomasiea-test"




function WriteLog($action, $errorLog = $null) {
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $username = $env:USERNAME
    $logInfo = "$date; $username; $action"

    if ($error) {
        $logInfo += "; Error: $error"
    }

    #$logPath = "/Users/aleksandra/wit/asc/asc"
    $logPath = "C:\ASC\LOG"

    $logFile = "task2.log"
    $fullPath = Join-Path -Path $logPath -ChildPath $logFile

    try {
        if (-not (Test-Path -Path $logPath)) {
            New-Item -ItemType Directory -Path $logPath | Out-Null
        }

        $logInfo | Out-File -Append -FilePath $fullPath
    }
    catch {
        Write-Host "Failed to write to log file: $_"
    }
}

function CreateReport {
    $resourceGroupName = "tomasiea-test"

    $vmReportFile = "C:\ASC\RAPORT\VMReport.txt"
    # $vmReportFile = "/Users/aleksandra/wit/asc/asc/VMReport.txt"

    $tagReportFile = "C:\ASC\RAPORT\TagReport.txt"
    # $tagReportFile = "/Users/aleksandra/wit/asc/asc/TagReport.txt"

    # Wyczyść pliki, jeśli istnieją
    if (Test-Path $vmReportFile) { Clear-Content $vmReportFile }
    if (Test-Path $tagReportFile) { Clear-Content $tagReportFile }

    $vms = Get-AzVM -ResourceGroupName $resourceGroupName

    foreach ($vm in $vms) {
        $publicIps = Get-AzPublicIpAddress -ResourceGroupName $vm.ResourceGroupName | Where-Object { $_.IpConfiguration.Id -eq $vm.NetworkProfile.NetworkInterfaces.Id }

        Add-Content -Path $vmReportFile -Value "VM Name: $($vm.Name), Public IPs: $($publicIps.IpAddress -join ', ')"

        foreach ($tag in $vm.Tags.GetEnumerator()) {
        Add-Content -Path $tagReportFile -Value "Object Name: $($vm.Name), Tag: $($tag.Key) = $($tag.Value)"
    }
}

$resources = Get-AzResource -ResourceGroupName $resourceGroupName

foreach ($resource in $resources) {
    if ($resource.Tags -ne $null) {
        foreach ($tag in $resource.Tags.GetEnumerator()) {
            Add-Content -Path $tagReportFile -Value "Object Name: $($resource.Name), Tag: $($tag.Key) = $($tag.Value)"
        }
    }
}
    
}

# Function for each menu option
function Option1
{
    WriteLog "Started infrastructure provisioning"

    $csvFilePath = Join-Path -Path $PSScriptRoot -ChildPath "dev-app-srv.csv"
    WriteLog "Data loaded from $csvFilePath"

    $vmData = Import-Csv -Path $csvFilePath -Delimiter ';'

    Connect-AzAccount

    $resourceGroupName = "tomasiea-test"
    $location = "North Europe"

    WriteLog "Creating resource group"

    $resourceGroupExists = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if (-not$resourceGroupExists)
    {
        New-AzResourceGroup -Name $resourceGroupName -Location $location
    }

    foreach ($row in $vmData)
    {
        WriteLog "Processing row: $row"

        $vmName = $row.VMname
        $vmSize = $row.VMsize
        $projectTag = @{ "Projekt" = $row.Projekt }

        WriteLog "Read from CSV: VM Name - $vmName, VM Size - $vmSize, Project - $( $row.Projekt )"

        if ( [string]::IsNullOrWhiteSpace($vmName))
        {
            WriteLog "VM name is null or empty. Skipping this entry."
        }

        $vmUsername = "tomasiea"
        $vmPassword = ConvertTo-SecureString "YourSecurePassword#2024" -AsPlainText -Force
        $vmCredential = New-Object System.Management.Automation.PSCredential ($vmUsername, $vmPassword)

        try
        {
            $virtualNetwork = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name "$vmName-VNet" -AddressPrefix "10.0.0.0/16"
            $virtualNetwork | Add-AzVirtualNetworkSubnetConfig -Name "$vmName-Subnet" -AddressPrefix "10.0.0.0/24" | Set-AzVirtualNetwork

            $updatedVirtualNetwork = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name "$vmName-VNet"
            $subnetId = $updatedVirtualNetwork.Subnets[0].Id

            # Create a public IP address
            # $publicIp = New-AzPublicIpAddress -Name "$vmName-PublicIp" -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Dynamic -DomainNameLabel $vmName.ToLower()
            $publicIp = New-AzPublicIpAddress -Name "$vmName-PublicIp" -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -DomainNameLabel $vmName.ToLower()


            $networkInterface = New-AzNetworkInterface -Name "$vmName-NIC" -ResourceGroupName $resourceGroupName -Location $location -SubnetId $subnetId -PublicIpAddressId $publicIp.Id

            $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize

            Set-AzVMOperatingSystem -VM $vmConfig -Windows -Credential $vmCredential -ComputerName $vmName

            Add-AzVMNetworkInterface -VM $vmConfig -Id $networkInterface.Id

            New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig -Tag $projectTag

            WriteLog "VM $vmName created successfully"

            $publicIpAddress = (Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name "$vmName-PublicIp").IpAddress
            WriteLog "Access the web page hosted on VM at: http://$publicIpAddress"

        }
        catch
        {
            Write-Host "Failed to create VM: $vmName. Error: $_"
            WriteLog "Failed to create VM: $_"
        }
    }

    Get-Job | Wait-Job

    Write-Host "All VMs created."
    WriteLog "All VMs created."

    break

    # Set variables for SQL Server
    $sqlServerName = "tomasiea-test" # SQL Server names need to be unique
    $sqlAdminUsername = "sqladmin"
    $sqlAdminPassword = ConvertTo-SecureString "YourOtherSecurePassword#2024" -AsPlainText -Force
    $sqlCredential = New-Object System.Management.Automation.PSCredential ($sqlAdminUsername, $sqlAdminPassword)

    Write-Host "Creating AzSqlServer"
    WriteLog "Creating AzSqlServer"

    New-AzSqlServer -ResourceGroupName $resourceGroupName `
    -ServerName $sqlServerName `
    -Location $location `
    -SqlAdministratorCredentials $sqlCredential

    $sqlDbName = "tomasiea-test"

    Write-Host "Creating AzSqlDatabase"
    WriteLog "Creating AzSqlDatabase"

    New-AzSqlDatabase -ResourceGroupName $resourceGroupName `
    -ServerName $sqlServerName `
    -DatabaseName $sqlDbName `
    -RequestedServiceObjectiveName "S0"
}

function Option2
{
    Connect-AzAccount

    Write-Host "Infrastructure deprovisioning"
    WriteLog "Infrastructure deprovisioning"

    $resourceGroupName = "tomasiea-test"

    Write-Host "Removing AzResourceGroup"
    WriteLog "Removing AzResourceGroup"

    $job = Remove-AzResourceGroup -Name $resourceGroupName -Force -AsJob

    # Wait for the job to complete
    $finishedJob = Wait-Job -Job $job

    if ($finishedJob.State -eq 'Completed')
    {
        Write-Host "Resource group '$resourceGroupName' has been successfully removed."
        WriteLog "Resource group '$resourceGroupName' has been successfully removed."
    }
    else
    {
        Write-Host "Failed to remove resource group '$resourceGroupName'."
        WriteLog "Failed to remove resource group '$resourceGroupName'."
    }
}

# Display the menu and handle user input
do
{
    Write-Host "Please choose an option:"
    Write-Host "1: Infrastructure provisioning"
    Write-Host "2: Infrastructure deprovisioning"
    Write-Host "3: Create report"
    Write-Host "Q: Quit"

    $input = Read-Host "Enter your choice"

    switch ($input)
    {
        '1' {
            Option1
        }
        '2' {
            Option2
        }
        '3' {
            CreateReport
        }
        'Q' {
            break
        }
        default {
            Write-Host "Invalid option, please try again."
        }
    }
} while ($input -ne 'Q')

Write-Host "Script execution completed."
WriteLog "Script execution completed."



