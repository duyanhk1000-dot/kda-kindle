# KDA Kindle Local HTTP Gateway Server (Phase 1 Reader Core)
# Pure HTTP (Port 8080) - Non-Admin Compatible TcpListener

$port = 8080
$root = $PSScriptRoot

# Get local LAN IPv4 address
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" -and $_.InterfaceAlias -notlike "*vEthernet*" } | Select-Object -First 1).IPAddress
if (-not $ip) { $ip = "127.0.0.1" }

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  KDA KINDLE READER GATEWAY (PHASE 1 CORE)" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  URL cho máy Kindle Touch 4 (Mở trong cùng Wi-Fi LAN):" -ForegroundColor Yellow
Write-Host "  http://$ip`:$port/" -ForegroundColor White -BackgroundColor Black
Write-Host ""
Write-Host "  Các lối vào Gateway:" -ForegroundColor Yellow
Write-Host "  - Trang Chủ Gateway: http://$ip`:$port/"
Write-Host "  - Đọc Báo Tiếng Việt: http://$ip`:$port/news"
Write-Host "  - Đọc Truyện Chữ:    http://$ip`:$port/books"
Write-Host "  - Đọc Truyện Tranh:  http://$ip`:$port/comics"
Write-Host ""
Write-Host "  Đang lắng nghe kết nối trên Cổng HTTP $port ..." -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

function Send-File($stream, $targetPath, $contentType) {
    if (Test-Path $targetPath -PathType Leaf) {
        $bytes = [System.IO.File]::ReadAllBytes($targetPath)
        $lines = @(
            "HTTP/1.1 200 OK",
            "Content-Type: $contentType",
            "Content-Length: $($bytes.Length)",
            "Connection: close",
            "",
            ""
        )
        $headerText = $lines -join "`r`n"
        $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headerText)
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        $stream.Write($bytes, 0, $bytes.Length)
    } else {
        $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
        $lines = @(
            "HTTP/1.1 404 Not Found",
            "Content-Type: text/plain; charset=utf-8",
            "Content-Length: $($msg.Length)",
            "Connection: close",
            "",
            ""
        )
        $headerText = $lines -join "`r`n"
        $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headerText)
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        $stream.Write($msg, 0, $msg.Length)
    }
    $stream.Flush()
}

$endpoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, $port)
$tcpListener = New-Object System.Net.Sockets.TcpListener $endpoint
$tcpListener.Start()

try {
    while ($true) {
        $client = $tcpListener.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)

        $requestLine = $reader.ReadLine()
        if ([string]::IsNullOrEmpty($requestLine)) { $client.Close(); continue }

        $parts = $requestLine.Split(' ')
        if ($parts.Length -lt 2) { $client.Close(); continue }

        $method = $parts[0]
        $rawUrl = $parts[1]

        while (-not [string]::IsNullOrEmpty(($line = $reader.ReadLine()))) {}

        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Request: $method $rawUrl" -ForegroundColor White

        # Serve static assets (.css, .jpg)
        if ($rawUrl.StartsWith("/css/") -or $rawUrl.StartsWith("/images/")) {
            $filePath = Join-Path $root $rawUrl.TrimStart('/').Replace('/', '\')
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $ct = if ($ext -eq ".css") { "text/css; charset=utf-8" } else { "image/jpeg" }
            Send-File $stream $filePath $ct
            $client.Close()
            continue
        }

        # Route mapping to views
        $uPath = $rawUrl
        if ($rawUrl.Contains("?")) { $uPath = $rawUrl.Split('?')[0] }

        $viewFile = "views\home.html"

        if ($uPath -eq "/" -or $uPath -eq "/index.html") {
            $viewFile = "views\home.html"
        }
        elseif ($uPath -eq "/news") {
            $viewFile = "views\news.html"
        }
        elseif ($uPath -eq "/news/detail") {
            $viewFile = "views\news_detail.html"
        }
        elseif ($uPath -eq "/books") {
            $viewFile = "views\books.html"
        }
        elseif ($uPath -eq "/book/detail") {
            $viewFile = "views\book_detail.html"
        }
        elseif ($uPath -eq "/book/chapter") {
            if ($rawUrl.Contains("chap=2")) {
                $viewFile = "views\chapter_2.html"
            } elseif ($rawUrl.Contains("chap=3")) {
                $viewFile = "views\chapter_3.html"
            } else {
                $viewFile = "views\chapter_1.html"
            }
        }
        elseif ($uPath -eq "/comics" -or $uPath -eq "/comic/detail") {
            $viewFile = "views\comic.html"
        }

        $fullPath = Join-Path $root $viewFile
        Send-File $stream $fullPath "text/html; charset=utf-8"
        $client.Close()
    }
} finally {
    $tcpListener.Stop()
}
