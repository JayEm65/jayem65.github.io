$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$analyticsPath = Join-Path $root 'analytics.json'
$port = 3000
$prefix = "http://localhost:$port/"

if (-not (Test-Path $analyticsPath)) {
    Set-Content -Path $analyticsPath -Value '{}' -Encoding utf8
}

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($prefix)
$listener.Start()

Write-Host "Analytics server running at $prefix"

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        $url = $request.Url
        $path = [System.Uri]::UnescapeDataString($url.AbsolutePath)

        if ($path -eq '/api/analytics') {
            if ($request.HttpMethod -eq 'GET') {
                $stats = Get-Content -Path $analyticsPath -Raw -ErrorAction SilentlyContinue
                if ([string]::IsNullOrWhiteSpace($stats)) { $stats = '{}' }
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($stats)
                $response.ContentType = 'application/json; charset=utf-8'
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
                $response.OutputStream.Close()
                continue
            }

            if ($request.HttpMethod -eq 'POST') {
                $body = ''
                $reader = New-Object System.IO.StreamReader($request.InputStream)
                $body = $reader.ReadToEnd()
                $reader.Close()

                if ([string]::IsNullOrWhiteSpace($body)) {
                    $body = '{}'
                }

                try {
                    $payload = $body | ConvertFrom-Json -Depth 10 -ErrorAction Stop
                } catch {
                    $response.StatusCode = 400
                    $message = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Invalid JSON"}')
                    $response.ContentType = 'application/json; charset=utf-8'
                    $response.ContentLength64 = $message.Length
                    $response.OutputStream.Write($message, 0, $message.Length)
                    $response.OutputStream.Close()
                    continue
                }

                if ($payload.action -eq 'reset') {
                    Set-Content -Path $analyticsPath -Value '{}' -Encoding utf8
                    $message = [System.Text.Encoding]::UTF8.GetBytes('{}')
                    $response.ContentType = 'application/json; charset=utf-8'
                    $response.ContentLength64 = $message.Length
                    $response.OutputStream.Write($message, 0, $message.Length)
                    $response.OutputStream.Close()
                    continue
                }

                $photo = $payload.photo
                $action = $payload.action

                if ([string]::IsNullOrWhiteSpace($photo) -or [string]::IsNullOrWhiteSpace($action)) {
                    $response.StatusCode = 400
                    $message = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Missing photo or action"}')
                    $response.ContentType = 'application/json; charset=utf-8'
                    $response.ContentLength64 = $message.Length
                    $response.OutputStream.Write($message, 0, $message.Length)
                    $response.OutputStream.Close()
                    continue
                }

                $statsText = Get-Content -Path $analyticsPath -Raw -ErrorAction SilentlyContinue
                if ([string]::IsNullOrWhiteSpace($statsText)) { $statsText = '{}' }
                $stats = $statsText | ConvertFrom-Json -AsHashtable -Depth 10

                if (-not $stats.ContainsKey($photo)) {
                    $stats[$photo] = @{ opens = 0; saves = 0 }
                }

                if ($action -eq 'open') {
                    $stats[$photo].opens += 1
                } elseif ($action -eq 'save') {
                    $stats[$photo].saves += 1
                } else {
                    $response.StatusCode = 400
                    $message = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Invalid action"}')
                    $response.ContentType = 'application/json; charset=utf-8'
                    $response.ContentLength64 = $message.Length
                    $response.OutputStream.Write($message, 0, $message.Length)
                    $response.OutputStream.Close()
                    continue
                }

                $updatedJson = $stats | ConvertTo-Json -Depth 10
                Set-Content -Path $analyticsPath -Value $updatedJson -Encoding utf8

                $message = [System.Text.Encoding]::UTF8.GetBytes($updatedJson)
                $response.ContentType = 'application/json; charset=utf-8'
                $response.ContentLength64 = $message.Length
                $response.OutputStream.Write($message, 0, $message.Length)
                $response.OutputStream.Close()
                continue
            }
        }

        $requestedPath = if ($path -eq '/') { '/index.html' } else { $path }
        $fullPath = Join-Path $root $requestedPath.TrimStart('/')

        if (-not [System.IO.Path]::GetFullPath($fullPath).StartsWith([System.IO.Path]::GetFullPath($root))) {
            $response.StatusCode = 403
            $response.Close()
            continue
        }

        if (Test-Path $fullPath) {
            $content = [System.IO.File]::ReadAllBytes($fullPath)
            $extension = [System.IO.Path]::GetExtension($fullPath).ToLowerInvariant()
            $mime = switch ($extension) {
                '.html' { 'text/html; charset=utf-8' }
                '.css' { 'text/css; charset=utf-8' }
                '.js' { 'application/javascript; charset=utf-8' }
                '.json' { 'application/json; charset=utf-8' }
                '.jpg' { 'image/jpeg' }
                '.jpeg' { 'image/jpeg' }
                '.png' { 'image/png' }
                '.gif' { 'image/gif' }
                '.svg' { 'image/svg+xml' }
                '.ico' { 'image/x-icon' }
                default { 'application/octet-stream' }
            }
            $response.ContentType = $mime
            $response.ContentLength64 = $content.Length
            $response.OutputStream.Write($content, 0, $content.Length)
            $response.OutputStream.Close()
        } else {
            $response.StatusCode = 404
            $response.Close()
        }
    } catch {
        if ($response) {
            $response.StatusCode = 500
            $response.Close()
        }
    }
}

$listener.Stop()
$listener.Close()
