$ErrorActionPreference = "Stop"
$androidRoot = "C:\Android"
$jdkZip = "$androidRoot\jdk.zip"
$jdkDir = "$androidRoot\jdk"

if (!(Test-Path $androidRoot)) { New-Item -ItemType Directory -Force -Path $androidRoot | Out-Null }

Write-Host "Downloading JDK..."
& curl.exe -L -o $jdkZip "https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip"

Write-Host "Extracting JDK..."
Expand-Archive -Path $jdkZip -DestinationPath $androidRoot -Force

# Rename extracted folder to 'jdk'
# The zip usually extracts to 'jdk-17.something'
$extracted = Get-ChildItem -Path $androidRoot -Filter "jdk-*" -Directory | Select-Object -First 1
if ($extracted) {
    Write-Host "Found extracted JDK at $($extracted.FullName). Moving to $jdkDir..."
    if (Test-Path $jdkDir) { Remove-Item -Recurse -Force $jdkDir }
    Move-Item -Path $extracted.FullName -Destination $jdkDir
}
else {
    Write-Error "Could not find extracted JDK folder in $androidRoot"
}

Remove-Item -Force $jdkZip
Write-Host "JDK installed successfully at $jdkDir"
