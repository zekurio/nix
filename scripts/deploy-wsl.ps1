# NixOS WSL Deployment Script for Windows
# This script helps deploy NixOS WSL distributions on Windows

param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$TarballPath,

    [Parameter(Mandatory=$false)]
    [string]$DistroName = "NixOS-Tabris",

    [Parameter(Mandatory=$false)]
    [string]$InstallPath = "C:\WSL\nixos-tabris",

    [switch]$SkipWSLCheck = $false,
    [switch]$Force = $false,
    [switch]$Help = $false
)

# Color output helpers
function Write-Success {
    param([string]$Message)
    Write-Host "$Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "$Message" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host "$Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "$Message" -ForegroundColor Red
}

function Show-Help {
    @"
NixOS WSL Deployment Script

Usage:
  .\deploy-wsl.ps1 -TarballPath <path> [-DistroName <name>] [-InstallPath <path>] [-Force] [-SkipWSLCheck]

Parameters:
  -TarballPath      (Required) Path to the NixOS WSL tarball (*.tar.gz)
  -DistroName       Name for the WSL distribution (default: NixOS-Tabris)
  -InstallPath      Installation path for WSL (default: C:\WSL\nixos-tabris)
  -SkipWSLCheck     Skip WSL 2 availability check
  -Force            Skip confirmation prompts
  -Help             Show this help message

Examples:
  .\deploy-wsl.ps1 -TarballPath .\nixos-wsl-tabris.tar.gz
  .\deploy-wsl.ps1 -TarballPath C:\builds\nixos-wsl-tabris.tar.gz -DistroName MyNixOS -Force

Requirements:
  - Windows 10/11 with WSL 2 installed
  - Administrator privileges
  - At least 20GB free disk space

"@
}

# Show help if requested
if ($Help) {
    Show-Help
    exit 0
}

# Verify running as administrator
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match "S-1-5-32-544")
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

Write-Info "NixOS WSL Deployment Script"
Write-Info "=============================="
Write-Host ""

# Check WSL 2 installation
if (-not $SkipWSLCheck) {
    Write-Info "Checking WSL 2 installation..."
    $wslVersion = wsl --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "WSL 2 is not installed or not properly configured"
        Write-Info "Please install WSL 2 first: wsl --install"
        exit 1
    }
    Write-Success "WSL 2 is installed"
}

# Validate tarball
Write-Info "Validating tarball..."
$tarballPath = Resolve-Path $TarballPath
$tarballSize = (Get-Item $tarballPath).Length / 1GB
Write-Info "Tarball path: $tarballPath"
Write-Info "Tarball size: $([math]::Round($tarballSize, 2)) GB"

if ($tarballSize -lt 0.1) {
    Write-Error "Tarball seems too small or invalid"
    exit 1
}

Write-Success "Tarball validation passed"

# Check if distribution already exists
Write-Info "Checking for existing distributions..."
$existingDistro = wsl --list --all 2>/dev/null | Select-String -Pattern $DistroName
if ($existingDistro -and -not $Force) {
    Write-Warning "Distribution '$DistroName' already exists"
    $response = Read-Host "Do you want to replace it? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Info "Deployment cancelled"
        exit 0
    }

    Write-Info "Unregistering existing distribution..."
    wsl --unregister $DistroName 2>$null | Out-Null
    Start-Sleep -Seconds 2
    Write-Success "Distribution unregistered"
}

# Create installation directory
Write-Info "Preparing installation directory: $InstallPath"
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Write-Success "Directory created"
} else {
    Write-Warning "Directory already exists"
    Remove-Item -Path "$InstallPath\*" -Recurse -Force 2>$null
}

# Confirm before import
Write-Host ""
Write-Host "Installation Summary:" -ForegroundColor Cyan
Write-Host "  Distribution Name: $DistroName"
Write-Host "  Installation Path: $InstallPath"
Write-Host "  Tarball: $tarballPath"
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "Proceed with deployment? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Info "Deployment cancelled"
        exit 0
    }
}

# Import distribution
Write-Host ""
Write-Info "Importing NixOS distribution..."
Write-Info "This may take several minutes..."

$startTime = Get-Date
try {
    wsl --import $DistroName $InstallPath $tarballPath --version 2
    if ($LASTEXITCODE -ne 0) {
        throw "WSL import failed"
    }
} catch {
    Write-Error "Failed to import distribution: $_"
    exit 1
}

$endTime = Get-Date
$duration = $endTime - $startTime
Write-Success "Distribution imported successfully"
Write-Info "Import time: $([math]::Round($duration.TotalSeconds)) seconds"

# Verify installation
Write-Info "Verifying installation..."
$distros = wsl --list --all 2>/dev/null
if ($distros -match $DistroName) {
    Write-Success "Distribution verified"
} else {
    Write-Error "Distribution verification failed"
    exit 1
}

# Display post-deployment instructions
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        NixOS WSL Deployment Completed Successfully        ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Launch the distribution:"
Write-Host "   wsl -d $DistroName" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. On first boot, update and rebuild:"
Write-Host "   nix flake update" -ForegroundColor Cyan
Write-Host "   sudo nixos-rebuild switch" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Configure WSL (optional):"
Write-Host "   Edit /etc/wsl.conf for WSL-specific settings" -ForegroundColor Cyan
Write-Host ""

Write-Host "Useful WSL Commands:" -ForegroundColor Yellow
Write-Host "  List distributions:     wsl --list --all" -ForegroundColor Gray
Write-Host "  Set default:            wsl --set-default $DistroName" -ForegroundColor Gray
Write-Host "  Terminate:              wsl --terminate $DistroName" -ForegroundColor Gray
Write-Host "  Open distribution:      wsl -d $DistroName" -ForegroundColor Gray
Write-Host "  Run command:            wsl -d $DistroName -e <command>" -ForegroundColor Gray
Write-Host "  Backup:                 wsl --export $DistroName backup.tar.gz" -ForegroundColor Gray
Write-Host "  Unregister:             wsl --unregister $DistroName" -ForegroundColor Gray
Write-Host ""

Write-Host "Documentation:" -ForegroundColor Yellow
Write-Host "  WSL Build Guide: See WSL_BUILD_GUIDE.md" -ForegroundColor Gray
Write-Host "  WSL Docs: https://learn.microsoft.com/en-us/windows/wsl/" -ForegroundColor Gray
Write-Host ""

Write-Success "Deployment script completed!"
