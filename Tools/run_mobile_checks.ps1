param(
	[string]$Godot = "C:\Users\matis\OneDrive\Desktop\Godot_v4.6.2-stable_win64.exe",
	[switch]$Visual,
	[switch]$MobileRenderer
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$fixtureRoot = Join-Path $PSScriptRoot "MobileChecks"
foreach ($folder in @("Scripts", "Data", "Scenes", "Assets")) {
	$linkPath = Join-Path $fixtureRoot $folder
	$targetPath = Join-Path $projectRoot $folder
	if (-not (Test-Path -LiteralPath $linkPath)) {
		New-Item -ItemType Junction -Path $linkPath -Target $targetPath | Out-Null
	} elseif ((Get-Item -LiteralPath $linkPath).Target -ne $targetPath) {
		throw "Unexpected validation junction: $linkPath"
	}
}
$logPath = Join-Path $projectRoot "tmp\mobile_checks.log"
$arguments = @("--path", $fixtureRoot, "--editor", "--headless", "--quit", "--log-file", $logPath)
$process = Start-Process -FilePath $Godot -ArgumentList $arguments -PassThru -Wait -WindowStyle Hidden
if ($process.ExitCode) { throw "Godot import failed" }
if (Select-String -LiteralPath $logPath -Pattern "SCRIPT ERROR:|Parse Error:" -Quiet) {
	Get-Content -LiteralPath $logPath
	throw "Godot import reported a script error; runtime checks were not started."
}
$arguments = @("--path", $fixtureRoot, "--log-file", $logPath)
if ($MobileRenderer) { $arguments += @("--rendering-method", "mobile", "--rendering-driver", "d3d12") }
if ($Visual) { $arguments += @("--", "--visual") } else { $arguments += "--headless" }
$process = Start-Process -FilePath $Godot -ArgumentList $arguments -PassThru -Wait -WindowStyle Hidden
Get-Content -LiteralPath $logPath
if ($process.ExitCode) { throw "Mobile checks failed" }
if (Select-String -LiteralPath $logPath -Pattern "SCRIPT ERROR:|CHECK FAILED:" -Quiet) {
	throw "Godot reported a script or assertion error"
}
if (-not (Select-String -LiteralPath $logPath -Pattern "MOBILE_CHECKS_PASSED" -Quiet)) {
	throw "Godot did not confirm successful validation"
}
