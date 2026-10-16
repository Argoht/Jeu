param(
	[Parameter(Mandatory = $true)][string]$ApkPath,
	[Parameter(Mandatory = $true)][string]$JavaHome,
	[Parameter(Mandatory = $true)][string]$ApkSigner
)

$ErrorActionPreference = "Stop"
foreach ($path in @($ApkPath, $ApkSigner, (Join-Path $JavaHome "bin\java.exe"))) {
	if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
		throw "Verification APK impossible : fichier manquant $path"
	}
}

# Use the same JDK as Godot, without changing the caller's environment permanently.
$previousJavaHome = $env:JAVA_HOME
try {
	$env:JAVA_HOME = $JavaHome
	& $ApkSigner verify --verbose $ApkPath
	if ($LASTEXITCODE -ne 0) {
		throw "Signature APK invalide (code $LASTEXITCODE). APK precedent conserve."
	}
} finally {
	$env:JAVA_HOME = $previousJavaHome
}
Write-Host "Signature APK verifiee. Installation et lancement sur appareil encore a tester."
