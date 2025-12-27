$ErrorActionPreference = "Stop"
$sdkRoot = "C:\Android"
$sdkManager = "$sdkRoot\cmdline-tools\latest\bin\sdkmanager.bat"
$env:JAVA_HOME = "$sdkRoot\jdk"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

if (!(Test-Path "$env:JAVA_HOME\bin\java.exe")) {
    Write-Error "Java executable not found at $env:JAVA_HOME\bin\java.exe. Setup JDK first."
}


if (!(Test-Path $sdkManager)) {
    Write-Error "sdkmanager not found at $sdkManager. Did the setup script finish?"
}

Write-Host "Installing Android SDK components..."

# Accept licenses
# We pipe 'y' multiple times to cover all licenses
$yes = "y`ny`ny`ny`ny`ny`n" 

# Install commands
# Note: --install is implied if packages are listed, but good to be explicit.
# We need to accept licenses via --licenses first or pipe 'y' to install.
# Standard way: yes | sdkmanager --licenses
# Then install.

$components = @(
    "platform-tools",
    "platforms;android-34",
    "build-tools;34.0.0",
    "emulator",
    "system-images;android-34;google_apis;x86_64"
)

Write-Host "Components to install: $components"

# We use cmd /c to handle piping correctly in PS sometimes, or just PS piping.
# PS piping to batch files can be tricky.
# Using a loop to install and accept licenses.

$proc = Start-Process -FilePath $sdkManager -ArgumentList "$components" -PassThru -RedirectStandardInput (New-Item -Path "input.txt" -Value $yes -Force) -NoNewWindow -Wait

Write-Host "Installation finished with exit code $($proc.ExitCode)"

# Verify
Get-ChildItem "$sdkRoot\platforms"
Get-ChildItem "$sdkRoot\build-tools"
