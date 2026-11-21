# Runs every check before you build or push, in one go:
#   powershell -ExecutionPolicy Bypass -File check.ps1
# 1. packages, 2. analyze, 3. all app tests, 4. the Firebase security-rules attack tests (if Java and Firebase are set up).
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Step($name, [scriptblock]$run) {
  Write-Host "`n== $name ==" -ForegroundColor Cyan
  & $run
  if ($LASTEXITCODE -ne 0) {
    Write-Host "`nFAILED: $name (see the lines above)" -ForegroundColor Red
    exit 1
  }
}

Step 'Packages' { flutter pub get }
Step 'Analyze' { flutter analyze }
Step 'App tests' { flutter test }

# The attack tests need Java 21 (Temurin). Use it even if an old, broken Java is first on the PATH.
$temurin = Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($temurin) {
  $env:JAVA_HOME = $temurin.FullName
  $env:Path = "$($temurin.FullName)\bin;$env:Path"
}
if ((Get-Command firebase -ErrorAction SilentlyContinue) -and (Test-Path 'firestore\node_modules')) {
  Step 'Firebase rules attack tests' { firebase emulators:exec --only firestore "node --test firestore/rules.test.mjs" }
} else {
  Write-Host "`n(Skipped the Firebase rules tests: Firebase tools or firestore\node_modules not found)" -ForegroundColor Yellow
}

Write-Host "`nAll checks passed" -ForegroundColor Green
