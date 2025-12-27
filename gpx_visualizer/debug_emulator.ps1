$env:JAVA_HOME = "C:\Android\jdk"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH;C:\Android\emulator;C:\Android\platform-tools"
$emulator = "C:\Android\emulator\emulator.exe"
$avd = "TestDevice"

Write-Host "Launching emulator $avd with verbose output..."
& $emulator -avd $avd -verbose
