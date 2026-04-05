# Updated Visual Studio Components Installer for Flutter
# This includes the specific MSVC v142 component required by Flutter.
# Run this script as Administrator.

$installerPath = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe"

if (-not (Test-Path $installerPath)) {
    Write-Error "Visual Studio Installer not found at $installerPath. Please install it first."
    exit
}

Write-Host "Updating Visual Studio components to include v142 Build Tools..." -ForegroundColor Cyan

# Define workloads and components to add
$args = @(
    "modify",
    "--installPath", "`"C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools`"",
    "--add", "Microsoft.VisualStudio.Workload.NativeDesktop",
    "--add", "Microsoft.VisualStudio.Component.VC.v142.x86.x64",
    "--add", "Microsoft.VisualStudio.Component.VC.CMake.Project",
    "--add", "Microsoft.VisualStudio.Component.Windows10SDK.19041",
    "--includeRecommended",
    "--passive",
    "--norestart"
)

# Combine arguments into a single string for execution
$fullCommand = "$installerPath $args"
Write-Host "Executing command: $fullCommand"

Start-Process -FilePath $installerPath -ArgumentList $args -Wait -Verb RunAs

Write-Host "Update process triggered. Please wait for the Installer to finish." -ForegroundColor Green
Write-Host "After the installer completes, please let me know to run 'flutter doctor' again." -ForegroundColor Yellow
