function Test-AllowedPage($Url, $Title, $Config) {
    $videoUri = $null
    if ([Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$videoUri) -and
        $videoUri.Scheme -in @('http', 'https')) {
        $videoId = ''
        if ($videoUri.Host -in @('youtube.com', 'www.youtube.com', 'm.youtube.com') -and $videoUri.AbsolutePath -eq '/watch') {
            foreach ($part in $videoUri.Query.TrimStart('?').Split('&')) {
                $pair = $part.Split('=', 2)
                if ($pair.Length -eq 2 -and $pair[0] -ceq 'v') { $videoId = [Uri]::UnescapeDataString($pair[1]); break }
            }
        } elseif ($videoUri.Host -eq 'youtu.be') { $videoId = $videoUri.AbsolutePath.Trim('/') }
        if ($videoId -and $Config.allowedYouTubeVideoIds -ccontains $videoId) { return $true }
    }
    foreach ($prefix in $Config.allowedUrlPrefixes) {
        if ($prefix -and $Url.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    foreach ($pattern in $Config.allowedTitlePatterns) {
        if ($pattern -and $Title -match $pattern) { return $true }
    }
    return $false
}

function Get-Distraction($App, $Url, $Title, $Config) {
    if (Test-AllowedPage $Url $Title $Config) { return '' }
    if ($Config.blockedApps -contains $App) { return "App: $App" }
    if ($App -notmatch '^(chrome|msedge|firefox|brave|opera|vivaldi)\.exe$') { return '' }
    $parsed = $null
    if (![Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$parsed)) { return '' }
    if ($parsed.Scheme -notin @('http', 'https')) { return '' }
    foreach ($domain in $Config.blockedDomains) {
        $domain = $domain.Trim().ToLowerInvariant()
        if ($domain -and ($parsed.Host -eq $domain -or $parsed.Host.EndsWith('.' + $domain))) {
            return "Site: $domain"
        }
    }
    return ''
}

function Test-FreshEvent($Event, $Now, $MaxAge = 25) {
    if (!$Event) { return $false }
    $end = [DateTimeOffset]::Parse($Event.timestamp).AddSeconds([double]$Event.duration)
    $age = ($Now - $end).TotalSeconds
    return $age -ge -10 -and $age -le $MaxAge
}

function New-GuardState {
    return @{ Candidate = ''; Since = 0.0; LastAlert = -100000.0; IdleNotified = $false }
}

function Step-Guard($State, $Elapsed, $Idle, $Distraction, $Config) {
    if ($Idle -ge $Config.idleSeconds) {
        $State.Candidate = ''
        if (!$State.IdleNotified) {
            $State.IdleNotified = $true
            return 'idle'
        }
        return ''
    }
    $State.IdleNotified = $false
    if (!$Distraction) { $State.Candidate = ''; return '' }
    if ($State.Candidate -ne $Distraction) {
        $State.Candidate = $Distraction
        $State.Since = $Elapsed
    }
    if (($Elapsed - $State.Since) -ge $Config.distractionSeconds -and
        ($Elapsed - $State.LastAlert) -ge $Config.cooldownSeconds) {
        $State.LastAlert = $Elapsed
        return 'distraction'
    }
    return ''
}
