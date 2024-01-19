# Function for each menu option
function Option1
{
    Write-Host "Infrastructure provisioning"
    # Connect to your Azure account
    Connect-AzAccount

    # Set variables for Resource Group and location
    $resourceGroupName = "tomasiea-test"
    $location = "North Europe"

    # Create a new resource group
    New-AzResourceGroup -Name $resourceGroupName -Location $location

    # Set variables for the VM
    $vmName = "tomasiea-test"
    $vmSize = "Standard_B1s"
    $vmUsername = "azureuser"
    $vmPassword = ConvertTo-SecureString "YourSecurePassword#2024" -AsPlainText -Force
    $vmCredential = New-Object System.Management.Automation.PSCredential ($vmUsername, $vmPassword)

    # Create a new VM
    New-AzVm `
    -ResourceGroupName $resourceGroupName `
    -Name $vmName `
    -Location $location `
    -VirtualNetworkName "tomasiea-test" `
    -SubnetName "tomasiea-test" `
    -SecurityGroupName "tomasiea-test" `
    -PublicIpAddressName "tomasiea-test" `
    -Size $vmSize `
    -Credential $vmCredential

    # Set variables for SQL Server
    $sqlServerName = "tomasiea-test" # SQL Server names need to be unique
    $sqlAdminUsername = "sqladmin"
    $sqlAdminPassword = ConvertTo-SecureString "YourOtherSecurePassword#2024" -AsPlainText -Force
    $sqlCredential = New-Object System.Management.Automation.PSCredential ($sqlAdminUsername, $sqlAdminPassword)

    # Create a new SQL Server
    New-AzSqlServer -ResourceGroupName $resourceGroupName `
    -ServerName $sqlServerName `
    -Location $location `
    -SqlAdministratorCredentials $sqlCredential

    # Set variables for SQL Database
    $sqlDbName = "tomasiea-test"

    # Create a new SQL Database
    New-AzSqlDatabase -ResourceGroupName $resourceGroupName `
    -ServerName $sqlServerName `
    -DatabaseName $sqlDbName `
    -RequestedServiceObjectiveName "S0" # Basic service tier
}

function Option2
{
    Write-Host "Infrastructure deprovisioning"
    $resourceGroupName = "tomasiea-test"
    Remove-AzResourceGroup -Name $resourceGroupName -Force -AsJob
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
