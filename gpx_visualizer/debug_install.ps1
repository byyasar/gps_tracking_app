$env:JAVA_HOME = "C:\Android\jdk"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
Write-Host "Checking Java..."
& java -version

$sdkManager = "C:\Android\cmdline-tools\latest\bin\sdkmanager.bat"
$sdkRoot = "C:\Android"

Write-Host "Listing Installed..."
& $sdkManager --list_installed --sdk_root=$sdkRoot

Write-Host "Attempting install of platform-tools..."
$yes = "y`ny`ny`ny`n"
$yes | & $sdkManager "platform-tools" --sdk_root=$sdkRoot --verbose
