param(
    [Parameter(Mandatory = $true)][string]$SavePath
)

$ErrorActionPreference = "Stop"
$save = Get-Content -LiteralPath $SavePath -Raw | ConvertFrom-Json
$metrics = $save.metrics
if (-not $metrics -or -not $metrics.first_seen) {
    throw "Aucune mesure locale dans cette sauvegarde. Lancer une version avec les compteurs actives."
}
$first = [DateTimeOffset]::FromUnixTimeSeconds([long]$metrics.first_seen)
$last = [DateTimeOffset]::FromUnixTimeSeconds([long]$metrics.last_seen)
$days = @($metrics.days.PSObject.Properties | Sort-Object { [long]$_.Name })
$rows = @($days | ForEach-Object {
    [ordered]@{
        day_utc = [DateTimeOffset]::FromUnixTimeSeconds(([long]$_.Name) * 86400).ToString("yyyy-MM-dd")
        sessions_started = [long]$_.Value
    }
})
$milestones = [ordered]@{}
foreach ($name in @("mission_started", "mission_completed", "item_equipped", "dungeon_started", "base_upgraded")) {
    $property = $metrics.milestones.PSObject.Properties[$name]
    $milestones[$name] = if ($null -eq $property) { $null } else { [long]$property.Value }
}
[ordered]@{
    first_observation_utc = $first.ToString("o")
    last_observation_utc = $last.ToString("o")
    session_gap_minutes = 30
    retained_observed_days = $days.Count
    days_with_multiple_session_starts = @($days | Where-Object { [long]$_.Value -ge 2 }).Count
    days = $rows
    first_action_elapsed_seconds = $milestones
    scope = "Local observation only; foreground is not proof of active play; no cohort retention inferred."
} | ConvertTo-Json -Depth 6
