# KDA Kindle Local HTTP Gateway Server (Phase 2 Live News Engine)
# Pure HTTP (Port 8080) - Non-Admin Compatible TcpListener

$port = 8080
$root = $PSScriptRoot

# Ensure TLS 1.2 for outbound RSS & article requests
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Get local LAN IPv4 address
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" -and $_.InterfaceAlias -notlike "*vEthernet*" } | Select-Object -First 1).IPAddress
if (-not $ip) { $ip = "127.0.0.1" }

Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host '  KDA KINDLE READER GATEWAY (PHASE 2 VIETNAMESE NEWS ENGINE)' -ForegroundColor Green
Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host '  URL cho máy Kindle Touch 4 (Mở trong cùng Wi-Fi LAN):' -ForegroundColor Yellow
Write-Host ('  http://' + $ip + ':' + $port + '/') -ForegroundColor White -BackgroundColor Black
Write-Host ''
Write-Host '  8 Nguồn tin tức báo chí Việt Nam:' -ForegroundColor Yellow
Write-Host ('  - VnExpress:       http://' + $ip + ':' + $port + '/news?src=vnexpress')
Write-Host ('  - Dân Trí:         http://' + $ip + ':' + $port + '/news?src=dantri')
Write-Host ('  - CafeF:           http://' + $ip + ':' + $port + '/news?src=cafef')
Write-Host ('  - VietNamNet:      http://' + $ip + ':' + $port + '/news?src=vietnamnet')
Write-Host ('  - Báo Thanh Niên:  http://' + $ip + ':' + $port + '/news?src=thanhnien')
Write-Host ('  - Báo VTC News:    http://' + $ip + ':' + $port + '/news?src=vtcnews')
Write-Host ('  - Luật Việt Nam:   http://' + $ip + ':' + $port + '/news?src=luatvietnam')
Write-Host ('  - Đời Sống & PL:   http://' + $ip + ':' + $port + '/news?src=doisongphapluat')
Write-Host ''
Write-Host ('  Đang lắng nghe kết nối trên Cổng HTTP ' + $port + ' ...') -ForegroundColor Gray
Write-Host '==========================================================' -ForegroundColor Cyan
Write-Host ''

function Send-Response($stream, $contentType, $payloadBytes) {
    $crlf = [System.Text.Encoding]::ASCII.GetString(@(13, 10))
    $headerText = 'HTTP/1.1 200 OK' + $crlf + 'Content-Type: ' + $contentType + $crlf + 'Content-Length: ' + $payloadBytes.Length + $crlf + 'Connection: close' + $crlf + $crlf
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headerText)
    $stream.Write($headerBytes, 0, $headerBytes.Length)
    $stream.Write($payloadBytes, 0, $payloadBytes.Length)
    $stream.Flush()
}

# Clean HTML tags using string splitting
function Clean-HtmlTags($text) {
    if (-not $text) { return '' }
    $str = [string]$text
    $parts = $str.Split([char]60)
    $clean = ''
    foreach ($p in $parts) {
        $gt = $p.IndexOf([char]62)
        if ($gt -ge 0) {
            $clean += $p.Substring($gt + 1)
        } else {
            $clean += $p
        }
    }
    return $clean
}

# Safely extract text from XmlNode property
function Get-XmlNodeText($node, $propName) {
    if (-not $node -or -not $node.$propName) { return '' }
    $p = $node.$propName
    if ($p.InnerText) { return $p.InnerText.Trim() }
    if ($p.'#cdata-section') { return $p.'#cdata-section'.Trim() }
    if ($p.'#text') { return $p.'#text'.Trim() }
    if ($p.href) { return $p.href.Trim() }
    return ([string]$p).Trim()
}

# Fetch Live RSS items with robust property extraction
function Fetch-RssItems($feedUrl, $sourceName) {
    $items = @()
    try {
        $req = [System.Net.HttpWebRequest]::Create($feedUrl)
        $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) KDAKindleReader/1.0'
        $req.Timeout = 7000
        $res = $req.GetResponse()
        $reader = New-Object System.IO.StreamReader($res.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $xmlContent = $reader.ReadToEnd()
        
        [xml]$xml = $xmlContent
        $nodes = $xml.SelectNodes('//item')
        if ($nodes.Count -eq 0) { $nodes = $xml.SelectNodes('//entry') }

        $count = 0
        foreach ($node in $nodes) {
            if ($count -ge 12) { break }
            
            $title = Get-XmlNodeText $node 'title'
            $link = Get-XmlNodeText $node 'link'
            if (-not $link) { $link = Get-XmlNodeText $node 'guid' }
            
            $pubDate = Get-XmlNodeText $node 'pubDate'
            if (-not $pubDate) { $pubDate = Get-XmlNodeText $node 'updated' }
            if (-not $pubDate) { $pubDate = (Get-Date -Format 'dd/MM/yyyy HH:mm') }

            $desc = Get-XmlNodeText $node 'description'
            if (-not $desc) { $desc = Get-XmlNodeText $node 'summary' }

            $cleanDesc = Clean-HtmlTags $desc
            if ($cleanDesc.Length -gt 150) { $cleanDesc = $cleanDesc.Substring(0, 150) + '...' }

            if ($title -and $link) {
                $items += @{
                    id = $count
                    title = $title
                    link = $link
                    pubDate = $pubDate
                    desc = $cleanDesc
                    source = $sourceName
                }
                $count++
            }
        }
    } catch {
        Write-Host "Loi lay RSS $sourceName" -ForegroundColor Red
    }
    return $items
}

# Fetch Luật Việt Nam via Scraper
function Fetch-LuatVietnam() {
    $items = @()
    try {
        $html = & curl.exe -s -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) KDAKindle/1.0" "https://luatvietnam.vn/tin-tuc.html"
        if (-not $html) { return $items }
        $delim = @('<h3 class="title-news">', 'class="post-title">', 'class="title-news">')
        $parts = $html.Split($delim, [System.StringSplitOptions]::RemoveEmptyEntries)
        $count = 0
        for ($i = 1; $i -lt $parts.Length; $i++) {
            if ($count -ge 10) { break }
            $p = $parts[$i]
            $aIdx = $p.IndexOf('href=')
            if ($aIdx -ge 0) {
                $sub = $p.Substring($aIdx + 6)
                $endHref = $sub.IndexOf([char]34)
                if ($endHref -gt 0) {
                    $link = $sub.Substring(0, $endHref)
                    $gt = $sub.IndexOf('>')
                    $closeA = $sub.IndexOf('</a>')
                    if ($gt -gt 0 -and $closeA -gt $gt) {
                        $rawT = $sub.Substring($gt + 1, $closeA - $gt - 1)
                        $t = Clean-HtmlTags $rawT
                        $t = $t.Trim()
                        if ($t.Length -gt 15) {
                            $items += @{
                                id = $count
                                title = $t
                                link = if ($link.StartsWith('http')) { $link } else { 'https://luatvietnam.vn' + $link }
                                pubDate = (Get-Date -Format 'dd/MM/yyyy')
                                desc = 'Văn bản pháp luật và thông tin chính sách pháp lý mới nhất từ Luật Việt Nam.'
                                source = 'Luật Việt Nam'
                            }
                            $count++
                        }
                    }
                }
            }
        }
    } catch {
        Write-Host 'Loi bóc tách LuatVietnam' -ForegroundColor Red
    }
    return $items
}

# Fetch Full Article Paragraphs from live URL
function Fetch-FullArticleParagraphs($url, $fallbackDesc) {
    $paragraphs = @()
    if (-not $url -or $url.Length -lt 8 -or -not $url.StartsWith('http')) {
        $paragraphs += $fallbackDesc
        return $paragraphs
    }
    try {
        $req = [System.Net.HttpWebRequest]::Create($url)
        $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) KDAKindleReader/1.0'
        $req.Timeout = 7000
        $res = $req.GetResponse()
        $reader = New-Object System.IO.StreamReader($res.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $html = $reader.ReadToEnd()

        # Standard <p> paragraph extractor
        $pParts = $html.Split([char]60)
        foreach ($p in $pParts) {
            $gt = $p.IndexOf([char]62)
            if ($gt -ge 0) {
                if ($p.StartsWith('p') -or $p.StartsWith('P')) {
                    $pText = $p.Substring($gt + 1)
                    $closeP = $pText.IndexOf('</p>')
                    if ($closeP -gt 0) { $pText = $pText.Substring(0, $closeP) }
                    $cleanP = Clean-HtmlTags $pText
                    $cleanP = $cleanP.Trim()
                    if ($cleanP.Length -gt 35 -and -not $cleanP.Contains('bản quyền') -and -not $cleanP.Contains('Copyright')) {
                        $paragraphs += $cleanP
                    }
                }
            }
        }
    } catch {
        Write-Host 'Loi bóc tách bai viet live' -ForegroundColor Red
    }

    if ($paragraphs.Count -eq 0) {
        $paragraphs += $fallbackDesc
    }
    return $paragraphs
}

$endpoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, $port)
$tcpListener = New-Object System.Net.Sockets.TcpListener $endpoint
$tcpListener.Start()

$amp = [char]38
$quote = [char]34

try {
    while ($true) {
        $client = $tcpListener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)

            $requestLine = $reader.ReadLine()
            if ([string]::IsNullOrEmpty($requestLine)) { $client.Close(); continue }

            $parts = $requestLine.Split(' ')
            if ($parts.Length -lt 2) { $client.Close(); continue }

            $method = $parts[0]
            $rawUrl = $parts[1]

            while (-not [string]::IsNullOrEmpty(($line = $reader.ReadLine()))) {}

            $timeStr = Get-Date -Format 'HH:mm:ss'
            Write-Host ('[' + $timeStr + '] Request: ' + $method + ' ' + $rawUrl) -ForegroundColor White

            # Serve static assets (.css, .jpg)
            if ($rawUrl.StartsWith('/css/') -or $rawUrl.StartsWith('/images/')) {
                $filePath = Join-Path $root $rawUrl.TrimStart('/').Replace('/', '\')
                if (Test-Path $filePath -PathType Leaf) {
                    $bytes = [System.IO.File]::ReadAllBytes($filePath)
                    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                    $ct = if ($ext -eq '.css') { 'text/css; charset=utf-8' } else { 'image/jpeg' }
                    Send-Response $stream $ct $bytes
                    $client.Close()
                    continue
                }
            }

            # Route matching
            $uPath = $rawUrl
            if ($rawUrl.Contains('?')) { $uPath = $rawUrl.Split('?')[0] }

            # ROUTE: Home
            if ($uPath -eq '/' -or $uPath -eq '/index.html') {
                Send-Response $stream 'text/html; charset=utf-8' ([System.IO.File]::ReadAllBytes((Join-Path $root 'views\home.html')))
                $client.Close()
                continue
            }
            # ROUTE: News Portal / Specific Feed Router
            elseif ($uPath -eq '/news') {
                $src = 'all'
                if ($rawUrl.Contains('src=vnexpress')) { $src = 'vnexpress' }
                elseif ($rawUrl.Contains('src=dantri')) { $src = 'dantri' }
                elseif ($rawUrl.Contains('src=cafef')) { $src = 'cafef' }
                elseif ($rawUrl.Contains('src=vietnamnet')) { $src = 'vietnamnet' }
                elseif ($rawUrl.Contains('src=thanhnien')) { $src = 'thanhnien' }
                elseif ($rawUrl.Contains('src=vtcnews')) { $src = 'vtcnews' }
                elseif ($rawUrl.Contains('src=luatvietnam')) { $src = 'luatvietnam' }
                elseif ($rawUrl.Contains('src=doisongphapluat')) { $src = 'doisongphapluat' }

                if ($src -eq 'all') {
                    Send-Response $stream 'text/html; charset=utf-8' ([System.IO.File]::ReadAllBytes((Join-Path $root 'views\news.html')))
                    $client.Close()
                    continue
                }

                # Fetch live items based on source
                $items = @()
                $sourceTitle = 'TIN TÚC VIỆT NAM CẬP NHẬT'
                
                if ($src -eq 'vnexpress') {
                    $sourceTitle = 'VnExpress - Tin Mới Nhất'
                    $items = Fetch-RssItems 'https://vnexpress.net/rss/tin-moi-nhat.rss' 'VnExpress'
                } elseif ($src -eq 'dantri') {
                    $sourceTitle = 'Dân Trí - Sự Kiện Nổi Bật'
                    $items = Fetch-RssItems 'https://dantri.com.vn/rss/su-kien.rss' 'Dân Trí'
                } elseif ($src -eq 'cafef') {
                    $sourceTitle = 'CafeF - Tài Chính & Chứng Khoán'
                    $items = Fetch-RssItems 'https://cafef.vn/home.rss' 'CafeF'
                } elseif ($src -eq 'vietnamnet') {
                    $sourceTitle = 'Báo VietNamNet - Thời Sự'
                    $items = Fetch-RssItems 'https://vietnamnet.vn/rss/thoi-su.rss' 'VietNamNet'
                } elseif ($src -eq 'thanhnien') {
                    $sourceTitle = 'Báo Thanh Niên - Tin 24h'
                    $items = Fetch-RssItems 'https://thanhnien.vn/rss/home.rss' 'Thanh Niên'
                } elseif ($src -eq 'vtcnews') {
                    $sourceTitle = 'Báo VTC News - Thời Sự'
                    $items = Fetch-RssItems 'https://vtcnews.vn/rss/thoi-su.rss' 'VTC News'
                } elseif ($src -eq 'luatvietnam') {
                    $sourceTitle = 'Luật Việt Nam - Văn Bản Pháp Luật'
                    $items = Fetch-LuatVietnam
                } elseif ($src -eq 'doisongphapluat') {
                    $sourceTitle = 'Đời Sống & Pháp Luật'
                    $items = Fetch-RssItems 'https://www.doisongphapluat.com.vn/rss/phap-luat.rss' 'Đời Sống & PL'
                }

                $itemsHtml = ''
                if ($items.Count -eq 0) {
                    $itemsHtml = '<p>Đang cập nhật luồng tin tức trực tiếp...</p>'
                } else {
                    $idx = 0
                    foreach ($item in $items) {
                        $itemsHtml += '<p><b>' + ($idx + 1) + '. <a href=' + $quote + '/news/detail?src=' + $src + $amp + 'idx=' + $idx + $quote + '>' + $item.title + '</a></b><br><small><i>' + $item.source + ' - ' + $item.pubDate + '</i></small><br>' + $item.desc + '</p><hr>'
                        $idx++
                    }
                }

                $tplText = [System.IO.File]::ReadAllText((Join-Path $root 'views\news_list.html'))
                $pageHtml = $tplText.Replace('{{TITLE}}', $sourceTitle).Replace('{{ITEMS}}', $itemsHtml)
                
                Send-Response $stream 'text/html; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($pageHtml))
                $client.Close()
                continue
            }
            # ROUTE: Full News Article Reader + Real Live Scraping
            elseif ($uPath -eq '/news/detail') {
                $src = 'vnexpress'
                if ($rawUrl.Contains('src=dantri')) { $src = 'dantri' }
                elseif ($rawUrl.Contains('src=cafef')) { $src = 'cafef' }
                elseif ($rawUrl.Contains('src=vietnamnet')) { $src = 'vietnamnet' }
                elseif ($rawUrl.Contains('src=thanhnien')) { $src = 'thanhnien' }
                elseif ($rawUrl.Contains('src=vtcnews')) { $src = 'vtcnews' }
                elseif ($rawUrl.Contains('src=luatvietnam')) { $src = 'luatvietnam' }
                elseif ($rawUrl.Contains('src=doisongphapluat')) { $src = 'doisongphapluat' }

                # Parse exact article index robustly
                $idx = 0
                if ($rawUrl.Contains('idx=')) {
                    $idxStr = $rawUrl.Substring($rawUrl.IndexOf('idx=') + 4)
                    $ampPos = $idxStr.IndexOf('&')
                    if ($ampPos -ge 0) { $idxStr = $idxStr.Substring(0, $ampPos) }
                    $parsedIdx = 0
                    if ([int]::TryParse($idxStr, [ref]$parsedIdx)) {
                        $idx = $parsedIdx
                    }
                }

                $items = @()
                if ($src -eq 'vnexpress') { $items = Fetch-RssItems 'https://vnexpress.net/rss/tin-moi-nhat.rss' 'VnExpress' }
                elseif ($src -eq 'dantri') { $items = Fetch-RssItems 'https://dantri.com.vn/rss/su-kien.rss' 'Dân Trí' }
                elseif ($src -eq 'cafef') { $items = Fetch-RssItems 'https://cafef.vn/home.rss' 'CafeF' }
                elseif ($src -eq 'vietnamnet') { $items = Fetch-RssItems 'https://vietnamnet.vn/rss/thoi-su.rss' 'VietNamNet' }
                elseif ($src -eq 'thanhnien') { $items = Fetch-RssItems 'https://thanhnien.vn/rss/home.rss' 'Thanh Niên' }
                elseif ($src -eq 'vtcnews') { $items = Fetch-RssItems 'https://vtcnews.vn/rss/thoi-su.rss' 'VTC News' }
                elseif ($src -eq 'luatvietnam') { $items = Fetch-LuatVietnam }
                elseif ($src -eq 'doisongphapluat') { $items = Fetch-RssItems 'https://www.doisongphapluat.com.vn/rss/phap-luat.rss' 'Đời Sống & PL' }

                $targetItem = if ($items.Count -gt $idx) { $items[$idx] } else { @{ title='Chi tiết bài báo'; link=''; source='KDA News'; pubDate=(Get-Date -Format 'dd/MM/yyyy'); desc='Nội dung bài viết đang được bóc tách.' } }

                # Fetch REAL live full article paragraphs from original website link!
                $fullParagraphs = Fetch-FullArticleParagraphs $targetItem.link $targetItem.desc

                # Format full article body HTML
                $articleBodyHtml = ''
                foreach ($p in $fullParagraphs) {
                    $articleBodyHtml += '<p>' + $p + '</p>'
                }

                # Summary based on real 1st paragraph
                $summaryText = if ($fullParagraphs.Count -gt 0) { $fullParagraphs[0] } else { 'Thông tin cập nhật nổi bật từ ' + $targetItem.source }

                $tplText = [System.IO.File]::ReadAllText((Join-Path $root 'views\news_detail.html'))
                $pageHtml = $tplText.Replace('{{TITLE}}', $targetItem.title).Replace('{{SOURCE}}', $targetItem.source).Replace('{{PUBDATE}}', $targetItem.pubDate).Replace('{{SUMMARY_TEXT}}', $summaryText).Replace('{{DESC}}', $articleBodyHtml).Replace('{{SRC_PARAM}}', $src)

                Send-Response $stream 'text/html; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($pageHtml))
                $client.Close()
                continue
            }
            # ROUTE: Books List & Detail
            elseif ($uPath -eq '/books') {
                Send-Response $stream 'text/html; charset=utf-8' ([System.IO.File]::ReadAllBytes((Join-Path $root 'views\books.html')))
                $client.Close()
                continue
            }
            elseif ($uPath -eq '/book/detail') {
                Send-Response $stream 'text/html; charset=utf-8' ([System.IO.File]::ReadAllBytes((Join-Path $root 'views\book_detail.html')))
                $client.Close()
                continue
            }
            elseif ($uPath -eq '/book/chapter') {
                $chapFile = 'views\chapter_1.html'
                if ($rawUrl.Contains('chap=2')) { $chapFile = 'views\chapter_2.html' }
                elseif ($rawUrl.Contains('chap=3')) { $chapFile = 'views\chapter_3.html' }
                Send-Response $stream 'text/html; charset=utf-8' ([System.IO.File]::ReadAllBytes((Join-Path $root $chapFile)))
                $client.Close()
                continue
            }
            # ROUTE: Comics Reader
            elseif ($uPath -eq '/comics' -or $uPath -eq '/comic/detail') {
                Send-Response $stream 'text/html; charset=utf-8' ([System.IO.File]::ReadAllBytes((Join-Path $root 'views\comic.html')))
                $client.Close()
                continue
            }
            else {
                Send-Response $stream 'text/html; charset=utf-8' ([System.IO.File]::ReadAllBytes((Join-Path $root 'views\404.html')))
                $client.Close()
                continue
            }
        } catch {
            Write-Host 'Loi xu ly request: ' $_.Exception.Message -ForegroundColor Red
        } finally {
            $client.Close()
        }
    }
} finally {
    $tcpListener.Stop()
}
