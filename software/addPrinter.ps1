param (
    [Parameter(Mandatory=$true)]
    [string]$PrinterName,

    [string]$DriverName = "Microsoft IPP Class Driver",

    [string]$PrintServer = "printserver",

    [switch]$Default
)

$Connection = "http://$PrintServer:631/printers/$PrinterName"

# Drucker anlegen, falls nicht vorhanden
if (-not (Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue)) {

    Add-Printer `
        -Name $PrinterName `
        -DriverName $DriverName `
        -ConnectionName $Connection
}

# Optional als Standarddrucker setzen
if ($Default) {
    Get-Printer | Where-Object IsDefault -eq $true | ForEach-Object {
        Set-Printer -Name $_.Name -IsDefault $false
    }
    Set-Printer -Name $PrinterName -IsDefault $true
}
