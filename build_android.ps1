param(
	[string]$Godot = "godot"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputPath = Join-Path $ProjectRoot "build\android\jeu-mobile.apk"

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
& $Godot --headless --path $ProjectRoot --export-debug "Android APK" $OutputPath

if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}

Write-Host "APK genere : $OutputPath"
