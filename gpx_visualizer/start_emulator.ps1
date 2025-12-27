$env:JAVA_HOME = "C:\Android\jdk"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$emulator = "C:\Android\emulator\emulator.exe"

# Start emulator in background
Start-Process -FilePath $emulator -ArgumentList "-avd TestDevice -no-boot-anim" -WindowStyle Normal
