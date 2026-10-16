param(
	[string]$Godot = "godot",
	[switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputPath = Join-Path $ProjectRoot "build\android\jeu-mobile.apk"
$PendingPath = Join-Path $ProjectRoot "build\android\jeu-mobile.pending.apk"
$LogPath = Join-Path $ProjectRoot "build\android\export.log"

$command = Get-Command $Godot -ErrorAction SilentlyContinue
if (-not $command) {
	throw "Godot introuvable. Utiliser -Godot avec le chemin complet de Godot 4.6.2."
}
$GodotPath = $command.Source
$settingsPath = Join-Path $env:APPDATA "Godot\editor_settings-4.6.tres"
if (-not (Test-Path -LiteralPath $settingsPath)) {
	throw "Reglages Godot 4.6 introuvables. Ouvrir Godot et configurer Export > Android."
}
$settings = Get-Content -LiteralPath $settingsPath
$issues = @()
$sdkPaths = @{}
foreach ($sdk in @(
	@{ Key = "java_sdk_path"; Label = "JDK 17"; Files = @("bin\java.exe", "bin\javac.exe", "bin\keytool.exe") },
	@{ Key = "android_sdk_path"; Label = "SDK Android"; Files = @("platform-tools\adb.exe") }
)) {
	$entry = $settings | Select-String -Pattern ('^export/android/' + $sdk.Key + '\s*=\s*"([^"]+)"\s*$') | Select-Object -First 1
	if (-not $entry) {
		$issues += "$($sdk.Label) : chemin non configure dans Godot."
		continue
	}
	$sdkPath = $entry.Matches[0].Groups[1].Value
	$sdkPaths[$sdk.Key] = $sdkPath
	foreach ($relativePath in $sdk.Files) {
		if (-not (Test-Path -LiteralPath (Join-Path $sdkPath $relativePath) -PathType Leaf)) {
			$issues += "$($sdk.Label) : fichier manquant $sdkPath/$relativePath"
		}
	}
}
$templateRoot = Join-Path $env:APPDATA "Godot\export_templates\4.6.2.stable"
if (-not (Test-Path -LiteralPath (Join-Path $templateRoot "android_debug.apk"))) {
	$issues += "Modele d'export Android 4.6.2 manquant : installer les modeles depuis Godot."
}
if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot "export_presets.cfg"))) {
	$issues += "Preset manquant : creer le preset Android APK dans Projet > Exporter."
}
if ($issues.Count -gt 0) {
	throw ("Export Android impossible :`n- " + ($issues -join "`n- "))
}
$buildToolsRoot = Join-Path $sdkPaths.android_sdk_path "build-tools"
$signer = Get-ChildItem -LiteralPath $buildToolsRoot -Directory -ErrorAction SilentlyContinue |
	Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
	Sort-Object { [version]$_.Name } -Descending |
	ForEach-Object { Join-Path $_.FullName "apksigner.bat" } |
	Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
	Select-Object -First 1
if (-not $signer) {
	throw "Android Build Tools stables introuvables : apksigner est requis pour verifier l'APK."
}
if ($CheckOnly) {
	Write-Host "Prerequis presents. La compilation reste a executer pour valider leur compatibilite."
	return
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
if (Test-Path -LiteralPath $PendingPath) { Remove-Item -LiteralPath $PendingPath }
$arguments = @("--headless", "--path", ('"' + $ProjectRoot + '"'), "--export-debug", '"Android APK"', ('"' + $PendingPath + '"'), "--log-file", ('"' + $LogPath + '"'))
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -PassThru -Wait -WindowStyle Hidden
if ($process.ExitCode -or -not (Test-Path -LiteralPath $PendingPath)) {
	throw "Export echoue. APK precedent conserve. Consulter $LogPath"
}
if ((Get-Item -LiteralPath $PendingPath).Length -eq 0 -or
	(Select-String -LiteralPath $LogPath -Pattern "ERROR:|SCRIPT ERROR:" -Quiet)) {
	throw "Export invalide. APK precedent conserve. Consulter $LogPath"
}
& (Join-Path $ProjectRoot "Tools\verify_android_apk.ps1") -ApkPath $PendingPath -JavaHome $sdkPaths.java_sdk_path -ApkSigner $signer
Move-Item -LiteralPath $PendingPath -Destination $OutputPath -Force

Write-Host "APK genere : $OutputPath"
