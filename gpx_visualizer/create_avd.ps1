$env:JAVA_HOME = "C:\Android\jdk"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$avdManager = "C:\Android\cmdline-tools\latest\bin\avdmanager.bat"

Write-Host "Creating AVD..."
# "no" to custom hardware profile to use default
echo "no" | & $avdManager create avd -n "TestDevice" -k "system-images;android-34;google_apis;x86_64" --device "pixel" --force

Write-Host "AVD Created."
