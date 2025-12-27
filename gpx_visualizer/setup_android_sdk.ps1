$ErrorActionPreference = "Stop"
$sdkPath = "C:\Android"
$cmdlineToolsZip = "$sdkPath\tools_new.zip"
$tempExtract = "$sdkPath\temp"

$finalDir = "$sdkPath\cmdline-tools\latest"

# 1. Create Directory
Write-Host "Creating SDK directory at $sdkPath..."
if (!(Test-Path $sdkPath)) { New-Item -ItemType Directory -Force -Path $sdkPath | Out-Null }
if (!(Test-Path "$sdkPath\cmdline-tools")) { New-Item -ItemType Directory -Force -Path "$sdkPath\cmdline-tools" | Out-Null }

# 2. Download
$url = "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip"
Write-Host "Downloading Command Line Tools from $url..."
& curl.exe -L -o $cmdlineToolsZip $url


# 3. Extract
Write-Host "Extracting..."
Expand-Archive -Path $cmdlineToolsZip -DestinationPath $tempExtract -Force

# 4. Move to correct structure (cmdline-tools/latest)
# The zip contains "cmdline-tools" folder at root usually
Write-Host "Configuring directory structure..."
if (Test-Path $finalDir) { Remove-Item -Recurse -Force $finalDir }

# We expect $tempExtract\cmdline-tools to exist
Move-Item -Path "$tempExtract\cmdline-tools" -Destination $finalDir

# 5. Cleanup
Remove-Item -Recurse -Force $tempExtract
Remove-Item -Force $cmdlineToolsZip

Write-Host "Android Command Line Tools installed successfully at $finalDir"
