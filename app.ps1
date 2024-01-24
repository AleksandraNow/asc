function WriteLog($action, $errorLog = $null) {
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $username = $env:USERNAME
    $logInfo = "$date; $username; $action"

    if ($error) {
        $logInfo += "; Error: $error"
    }

    # $logPath = "/Users/aleksandra/wit/asc/asc"
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



# Function for each menu option
function Option1
{
    # Write-Host "Infrastructure provisioning"
    WriteLog "Started infrastructure provisioning"

    # Path to the CSV file in the same directory as the script
    $csvFilePath = Join-Path -Path $PSScriptRoot -ChildPath "dev-app-srv.csv"
    # Write-Host "Data loadded from: $csvFilePath"
    WriteLog "Data loaded from $csvFilePath"


    # Read the CSV file
    $vmData = Import-Csv -Path $csvFilePath -Delimiter ';'

    # Connect to your Azure account
    # Connect-AzAccount

    # Set variables for Resource Group and location
    $resourceGroupName = "tomasiea-test"
    $location = "North Europe"

    # Create a new resource group
    # Write-Host "Creating resource group"
    WriteLog "Creating resource group"

    $resourceGroupExists = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if (-not$resourceGroupExists)
    {
        New-AzResourceGroup -Name $resourceGroupName -Location $location
    }

    # Iterate over each row in the CSV
    foreach ($row in $vmData)
    {
        # Write-Host "row: $row"
        WriteLog "Processing row: $row"

        # Extract VM details from CSV
        $vmName = $row.VMname
        $vmSize = $row.VMsize
        $projectTag = @{ "Projekt" = $row.Projekt }

        # Debugging line to print VM details
        # Write-Host "Read from CSV: VM Name - $vmName, VM Size - $vmSize, Project - $( $row.Projekt )"
        WriteLog "Read from CSV: VM Name - $vmName, VM Size - $vmSize, Project - $( $row.Projekt )"

        # Check if VM name is not null or empty
        if ( [string]::IsNullOrWhiteSpace($vmName))
        {
            # Write-Host "VM name is null or empty. Skipping this entry."
            WriteLog "VM name is null or empty. Skipping this entry."

        }

        $vmUsername = "tomasiea"
        $vmPassword = ConvertTo-SecureString "YourSecurePassword#2024" -AsPlainText -Force
        $vmCredential = New-Object System.Management.Automation.PSCredential ($vmUsername, $vmPassword)

        # Create a new VM using the basic configuration
        # Adjust this part based on your network and VM requirements
        try
        {
            # Create a virtual network with a subnet configuration
            $virtualNetwork = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name "$vmName-VNet" -AddressPrefix "10.0.0.0/16"
            $virtualNetwork | Add-AzVirtualNetworkSubnetConfig -Name "$vmName-Subnet" -AddressPrefix "10.0.0.0/24" | Set-AzVirtualNetwork

            # Fetch the updated virtual network to get the subnet ID
            $updatedVirtualNetwork = Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name "$vmName-VNet"
            $subnetId = $updatedVirtualNetwork.Subnets[0].Id

            # Create a public IP address
            # $publicIp = New-AzPublicIpAddress -Name "$vmName-PublicIp" -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Dynamic -DomainNameLabel $vmName.ToLower()
            $publicIp = New-AzPublicIpAddress -Name "$vmName-PublicIp" -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -DomainNameLabel $vmName.ToLower()


            # Create a network interface with the public IP address
            $networkInterface = New-AzNetworkInterface -Name "$vmName-NIC" -ResourceGroupName $resourceGroupName -Location $location -SubnetId $subnetId -PublicIpAddressId $publicIp.Id

            # Create a VM configuration object
            $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize

            # Set the VM credential
            Set-AzVMOperatingSystem -VM $vmConfig -Windows -Credential $vmCredential -ComputerName $vmName

            # Add the network interface to the VM configuration
            Add-AzVMNetworkInterface -VM $vmConfig -Id $networkInterface.Id

            # Create the VM using the configuration object
            New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig -Tag $projectTag

            # Custom Script to run on the VM
#             $customScript = @"
# Install-WindowsFeature -name Web-Server -IncludeManagementTools
# Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value 'Imię, Nazwisko – numer indexu – praca zaliczeniowa z ASC – data'
# "@

            # Check if the VM is created successfully
            # if ($vm)
            # {
            #     # Add a delay to ensure the previous operation has completed
            #     Start-Sleep -Seconds 10

            #     # Run the commands on the VM
            #     Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName $vmName -CommandId 'RunPowerShellScript' -ScriptString 'Install-WindowsFeature -Name Web-Server -IncludeManagementTools'
            #     Invoke-AzVMRunCommand -ResourceGroupName $resourceGroupName -VMName $vmName -CommandId 'RunPowerShellScript' -ScriptString 'New-Item -ItemType file -Name index.html -Path C:\inetpub\wwwroot -Value "Aleksandra Tomasiewicz - 22202 - praca zaliczeniowa z ASC - 24.01.2024"'
            # }
            # else
            # {
            #     Write-Host "VM creation failed. Skipping command execution."
            # }
   
            # Apply the Custom Script Extension
            Set-AzVMCustomScriptExtension -ResourceGroupName $resourceGroupName -VMName $vmName -Name "InitializeWebServer" -ScriptText $customScript -Location $location

            # Write-Host "Successfully created VM: $vmName"
            WriteLog "VM $vmName created successfully"


            $publicIpAddress = (Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name "$vmName-PublicIp").IpAddress
            # Write-Host "Access the web page hosted on VM at: http://$publicIpAddress"
            WriteLog "Access the web page hosted on VM at: http://$publicIpAddress"

        }
        catch
        {
            Write-Host "Failed to create VM: $vmName. Error: $_"
            WriteLog "Failed to create VM: $_"

        }
    }

    # Wait for all jobs to complete
    Get-Job | Wait-Job

    # Write-Host "All VMs created."
    WriteLog "All VMs created."


    break

    # Set variables for SQL Server
    $sqlServerName = "tomasiea-test" # SQL Server names need to be unique
    $sqlAdminUsername = "sqladmin"
    $sqlAdminPassword = ConvertTo-SecureString "YourOtherSecurePassword#2024" -AsPlainText -Force
    $sqlCredential = New-Object System.Management.Automation.PSCredential ($sqlAdminUsername, $sqlAdminPassword)

    # Create a new SQL Server
    # Write-Host "Creating AzSqlServer"
    WriteLog "Creating AzSqlServer"

    
    New-AzSqlServer -ResourceGroupName $resourceGroupName `
    -ServerName $sqlServerName `
    -Location $location `
    -SqlAdministratorCredentials $sqlCredential

    # Set variables for SQL Database
    $sqlDbName = "tomasiea-test"

    # Create a new SQL Database
    # Write-Host "Creating AzSqlDatabase"
    WriteLog "Creating AzSqlDatabase"

    New-AzSqlDatabase -ResourceGroupName $resourceGroupName `
    -ServerName $sqlServerName `
    -DatabaseName $sqlDbName `
    -RequestedServiceObjectiveName "S0" # Basic service tier
}

function Option2
{
    # Connect to your Azure account
    Connect-AzAccount

    # Write-Host "Infrastructure deprovisioning"
    WriteLog "Infrastructure deprovisioning"

    $resourceGroupName = "tomasiea-test"
    # Remove the resource group as a background job
    # Write-Host "Removing AzResourceGroup"
    WriteLog "Removing AzResourceGroup"

    $job = Remove-AzResourceGroup -Name $resourceGroupName -Force -AsJob

    # Wait for the job to complete
    $finishedJob = Wait-Job -Job $job

    # Check if the job completed successfully
    if ($finishedJob.State -eq 'Completed')
    {
        Write-Host "Resource group '$resourceGroupName' has been successfully removed."
        WriteLog "Resource group '$resourceGroupName' has been successfully removed."

    }
    else
    {
        Write-Host "Failed to remove resource group '$resourceGroupName'."
        WriteLog "Failed to remove resource group '$resourceGroupName'."
        # Optionally, add more error handling here
    }
}

# Display the menu and handle user input
do
{
    Write-Host "Please choose an option:"
    Write-Host "1: Infrastructure provisioning"
    Write-Host "2: Infrastructure deprovisioning"
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

