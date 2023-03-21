<# EasyDHCP.ps1 - A fun and easy way to set up a DHCP server on Windows 10/11

WARNING: This script is for educational purposes only.
Please ensure you have the necessary permissions to set up a DHCP server on your network.
#> 

## Let's have some fun with ASCII art!
Write-Host @"
====================================================================
███████╗ █████╗ ███████╗██╗   ██╗██████╗ ██╗  ██╗ ██████╗██████╗ 
██╔════╝██╔══██╗██╔════╝╚██╗ ██╔╝██╔══██╗██║  ██║██╔════╝██╔══██╗
█████╗  ███████║███████╗ ╚████╔╝ ██║  ██║███████║██║     ██████╔╝
██╔══╝  ██╔══██║╚════██║  ╚██╔╝  ██║  ██║██╔══██║██║     ██╔═══╝ 
███████╗██║  ██║███████║   ██║   ██████╔╝██║  ██║╚██████╗██║     
╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝      
====================================================================
"@

## Print a list of recommended IP ranges for local networks
Write-Host "Here are some recommended IP ranges for local networks:"
$RecommendedIPRanges = @(
    @{
        Range = "192.168.0.0 - 192.168.255.255";
        Description = "Private IP addresses for home and small business networks (Class C)"
    },
    @{
        Range = "172.16.0.0 - 172.31.255.255";
        Description = "Private IP addresses for medium-sized networks (Class B)"
    },
    @{
        Range = "10.0.0.0 - 10.255.255.255";
        Description = "Private IP addresses for large networks (Class A)"
    }
)

$RecommendedIPRanges | Format-Table -AutoSize
Write-Host ""
## Prompt user for the IP address range
Write-Host "First, let's define the IP address range for your DHCP server:"
$StartIPAddress = Read-Host -Prompt 'Please enter the starting IP address (e.g., 192.168.1.2)'
$EndIPAddress = Read-Host -Prompt 'Please enter the ending IP address (e.g., 192.168.1.254)'

## Get all network adapters and prompt user to choose one
Write-Host "Now, let's find out which network adapter you want to assign an IP address to:"
$Adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -Property Name, Status
$Adapters | Format-Table -AutoSize

$AdapterName = Read-Host -Prompt 'Please enter the name of the network adapter you want to assign an IP to'

## Check if the selected adapter exists
if (-not ($Adapters.Name -contains $AdapterName)) {
    Write-Host "Oops! Looks like the adapter you selected doesn't exist. Please try again with a valid adapter name."
    exit
}

## Install the DHCP server role if not already installed
if (-not (Get-WindowsFeature -Name 'DHCP' | Where-Object { $_.InstallState -eq 'Installed' })) {
    Write-Host "Hold on tight! We're installing the DHCP server role now. 😃"
    Install-WindowsFeature -Name 'DHCP' -IncludeManagementTools
}

## Create a new DHCP scope
Write-Host "Creating your new DHCP scope..."
$ScopeName = "EasyDHCP_$((Get-Date).ToString('yyyyMMdd_HHmmss'))"
Add-DhcpServerv4Scope -Name $ScopeName -StartRange $StartIPAddress -EndRange $EndIPAddress -SubnetMask 255.255.255.0

## Set the DHCP server bindings for the selected network adapter
Write-Host "Binding the DHCP server to your selected network adapter..."
Set-DhcpServerv4Binding -InterfaceAlias $AdapterName -Enable

## Enable the DHCP server
Write-Host "Enabling the DHCP server..."
Set-DhcpServerv4OptionValue -OptionId 3 -Value ($StartIPAddress, $EndIPAddress)

# Calculate the subnet mask from the IP range and the number of usable IPs
function Get-SubnetMask {
    param($StartIP, $EndIP, $UsableIPs)

    $HostBits = [Math]::Ceiling([Math]::Log($UsableIPs + 2, 2))
    $Mask = ([System.Net.IPAddress]::Parse("255.255.255.255")).Address -shl $HostBits

    return ([System.Net.IPAddress]$Mask).ToString()
}

# Calculate the CIDR notation for the set IP range
function Get-CidrNotation {
    param($SubnetMask)

    $BinaryMask = [IPAddress]$SubnetMask
    $Bits = 0

    foreach ($Byte in $BinaryMask.GetAddressBytes()) {
        $Bits += [Convert]::ToString($Byte, 2).ToCharArray() | Where-Object { $_ -eq '1' } | Measure-Object | Select-Object -ExpandProperty Count
    }

    return $Bits
}

$UsableIPs = ([System.Net.IPAddress]::Parse($EndIPAddress)).Address - ([System.Net.IPAddress]::Parse($StartIPAddress)).Address + 1
$SubnetMask = Get-SubnetMask -StartIP $StartIPAddress -EndIP $EndIPAddress -UsableIPs $UsableIPs
$CIDR = Get-CidrNotation -SubnetMask $SubnetMask

# Print the set IP range and CIDR notation
Write-Host @"
===================================================================================
Congratulations! Your DHCP server is now set up and ready to roll! 😎
===================================================================================
Your DHCP server is now configured with the following IP range and CIDR notation:

IP Range     : $StartIPAddress - $EndIPAddress
Subnet Mask  : $SubnetMask
CIDR Notation: $StartIPAddress/$CIDR

Happy networking!
===================================================================================
"@
