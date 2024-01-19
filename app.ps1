# Function for each menu option
function Option1
{
    Write-Host "Infrastructure provisioning"

    # Path to the CSV file in the same directory as the script
    $csvFilePath = Join-Path -Path $PSScriptRoot -ChildPath "dev-app-srv.csv"
    Write-Host "Data loadded from: $csvFilePath"

    # Read the CSV file
    $vmData = Import-Csv -Path $csvFilePath -Delimiter ';'

    # Connect to your Azure account
#    Connect-AzAccount

    # Set variables for Resource Group and location
    $resourceGroupName = "tomasiea-test"
    $location = "North Europe"

    # Create a new resource group
    Write-Host "Creating resource group"
    $resourceGroupExists = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if (-not $resourceGroupExists) {
        New-AzResourceGroup -Name $resourceGroupName -Location $location
    }

    # Set variables for the VM
#    $vmName = "tomasiea-test"
#    $vmSize = "Standard_B1s"
#    $vmUsername = "tomasiea"
#    $vmPassword = ConvertTo-SecureString "YourSecurePassword#2024" -AsPlainText -Force
#    $vmCredential = New-Object System.Management.Automation.PSCredential ($vmUsername, $vmPassword)

    # Iterate over each row in the CSV
    foreach ($row in $vmData) {
        Write-Host "row: $row"
        # Extract VM details from CSV
        $vmName = $row.VMname
        $vmSize = $row.VMsize
        $projectTag = @{ "Projekt" = $row.Projekt }

        # Debugging line to print VM details
        Write-Host "Read from CSV: VM Name - $vmName, VM Size - $vmSize, Project - $($row.Projekt)"

        # Check if VM name is not null or empty
        if ([string]::IsNullOrWhiteSpace($vmName)) {
            Write-Host "VM name is null or empty. Skipping this entry."
        }

        # Define VM Configuration
        $vmConfig = @{
            ResourceGroupName = $resourceGroupName
            Name = $vmName
            Location = $location
            VMSize = $vmSize
            Credential = $vmCredential
            Tag = $projectTag
        }

        $vmUsername = "tomasiea"
        $vmPassword = ConvertTo-SecureString "YourSecurePassword#2024" -AsPlainText -Force
        $vmCredential = New-Object System.Management.Automation.PSCredential ($vmUsername, $vmPassword)

        # Create a new VM using the basic configuration
        # Adjust this part based on your network and VM requirements
        try {
            # Create a virtual network and subnet configuration
            $virtualNetwork = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Location $location -Name "$vmName-VNet" -AddressPrefix "10.0.0.0/16"
            $subnetConfig = Add-AzVirtualNetworkSubnetConfig -Name "$vmName-Subnet" -VirtualNetwork $virtualNetwork -AddressPrefix "10.0.0.0/24"
            $virtualNetwork | Set-AzVirtualNetwork

            # Create a public IP address with a Static allocation method
            $publicIp = New-AzPublicIpAddress -Name "$vmName-PublicIp" -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -Sku Standard

            # Create a network interface
            $networkInterface = New-AzNetworkInterface -Name "$vmName-NIC" -ResourceGroupName $resourceGroupName -Location $location -SubnetId $subnetConfig.Id -PublicIpAddressId $publicIp.Id

            # Add the network interface to the VM configuration
            $vmConfig += @{
                NetworkInterfaceId = $networkInterface.Id
            }

            # Create the VM
            New-AzVM @vmConfig
            Write-Host "Creating VM: $vmName with size $vmSize for project $($row.Projekt)"
        } catch {
            Write-Host "Failed to create VM: $vmName. Error: $_"
        }

        # Create a new VM
#        $newVM = @{
#            ResourceGroupName = $resourceGroupName
#            Name = $vmName
#            Location = $location
#            VirtualNetworkName = "$vmName-VNet"
#            SubnetName = "$vmName-Subnet"
#            SecurityGroupName = "$vmName-NSG"
#            PublicIpAddressName = "$vmName-IP"
#            Size = $vmSize
#            Credential = $vmCredential
#            Tag = $projectTag
#            AsJob = $true # Run in the background
#        }
#
#        New-AzVm @newVM
#        Write-Host "Creating VM: $vmName with size $vmSize for project $($row.Projekt)"
    }

    # Wait for all jobs to complete
    Get-Job | Wait-Job

    Write-Host "All VMs created."

    break

    # Create a new VM
#    New-AzVm `
#    -ResourceGroupName $resourceGroupName `
#    -Name $vmName `
#    -Location $location `
#    -VirtualNetworkName "tomasiea-test" `
#    -SubnetName "tomasiea-test" `
#    -SecurityGroupName "tomasiea-test" `
#    -PublicIpAddressName "tomasiea-test" `
#    -Size $vmSize `
#    -Credential $vmCredential

    # Set variables for SQL Server
    $sqlServerName = "tomasiea-test" # SQL Server names need to be unique
    $sqlAdminUsername = "sqladmin"
    $sqlAdminPassword = ConvertTo-SecureString "YourOtherSecurePassword#2024" -AsPlainText -Force
    $sqlCredential = New-Object System.Management.Automation.PSCredential ($sqlAdminUsername, $sqlAdminPassword)

    # Create a new SQL Server
    Write-Host "Creating AzSqlServer"
    New-AzSqlServer -ResourceGroupName $resourceGroupName `
    -ServerName $sqlServerName `
    -Location $location `
    -SqlAdministratorCredentials $sqlCredential

    # Set variables for SQL Database
    $sqlDbName = "tomasiea-test"

    # Create a new SQL Database
    Write-Host "Creating AzSqlDatabase"
    New-AzSqlDatabase -ResourceGroupName $resourceGroupName `
    -ServerName $sqlServerName `
    -DatabaseName $sqlDbName `
    -RequestedServiceObjectiveName "S0" # Basic service tier
}

function Option2
{
    Write-Host "Infrastructure deprovisioning"
    $resourceGroupName = "tomasiea-test"
    # Remove the resource group as a background job
    Write-Host "Removing AzResourceGroup"
    $job = Remove-AzResourceGroup -Name $resourceGroupName -Force -AsJob

    # Wait for the job to complete
    $finishedJob = Wait-Job -Job $job

    # Check if the job completed successfully
    if ($finishedJob.State -eq 'Completed') {
        Write-Host "Resource group '$resourceGroupName' has been successfully removed."
    } else {
        Write-Host "Failed to remove resource group '$resourceGroupName'."
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
