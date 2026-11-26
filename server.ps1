param (
    [int]$Port = 5050,
    [switch]$NoBrowser
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$dataPath = Join-Path $scriptDir "calisanlar.json"
$historyPath = Join-Path $scriptDir "egitim_kayitlari.json"
$htmlPath = Join-Path $scriptDir "index.html"

# Ensure data exists
if (-not (Test-Path $dataPath)) {
    Write-Host "calisanlar.json bulunamadı, parse_data.ps1 çalıştırılıyor..." -ForegroundColor Yellow
    & powershell -ExecutionPolicy Bypass -File (Join-Path $scriptDir "parse_data.ps1")
}

function Get-RefreshedData {
    $raw = [System.IO.File]::ReadAllText($dataPath, [System.Text.Encoding]::UTF8)
    $obj = $raw | ConvertFrom-Json
    
    $today = [DateTime]::Today
    $validCount = 0
    $criticalCount = 0
    $expiredCount = 0
    $noTrainingCount = 0

    $deptSet = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($emp in $obj.employees) {
        if (-not [string]::IsNullOrWhiteSpace($emp.bolumu)) {
            $null = $deptSet.Add($emp.bolumu)
        }

        if ([string]::IsNullOrWhiteSpace($emp.sonEgitimTarihi)) {
            $emp.durum = "Eğitimsiz"
            $emp.durumKodu = "no_training"
            $emp.kalanGun = $null
            if ($emp.aktifMi) { $noTrainingCount++ }
            continue
        }

        try {
            $sonEgitimDate = [DateTime]::ParseExact($emp.sonEgitimTarihi, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
            $gecerlilikDate = $sonEgitimDate.AddYears(2)
            $emp.gecerlilikBitisTarihi = $gecerlilikDate.ToString("yyyy-MM-dd")
            $emp.gecerlilikBitisGosterim = $gecerlilikDate.ToString("dd.MM.yyyy")
            
            $diff = ($gecerlilikDate - $today).TotalDays
            $kalan = [int][Math]::Floor($diff)
            $emp.kalanGun = $kalan

            if ($kalan -lt 0) {
                $emp.durum = "Süresi Dolmuş"
                $emp.durumKodu = "expired"
                if ($emp.aktifMi) { $expiredCount++ }
            } elseif ($kalan -le 90) {
                $emp.durum = "Eğitim Yaklaştı (<90 Gün)"
                $emp.durumKodu = "warning"
                if ($emp.aktifMi) { $criticalCount++ }
            } else {
                $emp.durum = "Geçerli"
                $emp.durumKodu = "valid"
                if ($emp.aktifMi) { $validCount++ }
            }
        } catch {
            $emp.durum = "Eğitimsiz"
            $emp.durumKodu = "no_training"
            if ($emp.aktifMi) { $noTrainingCount++ }
        }
    }

    $obj.summary.validCount = $validCount
    $obj.summary.warningCount = $criticalCount
    $obj.summary.expiredCount = $expiredCount
    $obj.summary.noTrainingCount = $noTrainingCount
    $obj.summary | Add-Member -MemberType NoteProperty -Name "today" -Value $today.ToString("yyyy-MM-dd") -Force
    $obj.summary | Add-Member -MemberType NoteProperty -Name "todayGosterim" -Value $today.ToString("dd.MM.yyyy") -Force

    $deptList = @($deptSet) | Sort-Object

    # Training history
    $trainings = @()
    if (Test-Path $historyPath) {
        $rawHist = [System.IO.File]::ReadAllText($historyPath, [System.Text.Encoding]::UTF8)
        $trainings = $rawHist | ConvertFrom-Json
    }

    return [PSCustomObject]@{
        summary = $obj.summary
        employees = $obj.employees
        departments = $deptList
        trainings = $trainings
    }
}

# Start HTTP Listener
$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
} catch {
    Write-Host "Port $Port dinlenemedi, 5055 deneniyor..." -ForegroundColor Yellow
    $Port = 5055
    $prefix = "http://localhost:$Port/"
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($prefix)
    $listener.Start()
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  İSG EĞİTİM TAKİP VE BİLDİRİM SİSTEMİ ÇALIŞIYOR" -ForegroundColor Green
Write-Host "  Adres: $prefix" -ForegroundColor Yellow
Write-Host "  Durdurmak için Ctrl+C tuşlarına basınız." -ForegroundColor Gray
Write-Host "==========================================================" -ForegroundColor Cyan

if (-not $NoBrowser) {
    Start-Process $prefix
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $urlPath = $request.Url.AbsolutePath
        $method = $request.HttpMethod

        # CORS headers
        $response.AddHeader("Access-Control-Allow-Origin", "*")
        $response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        $response.AddHeader("Access-Control-Allow-Headers", "Content-Type")

        if ($method -eq "OPTIONS") {
            $response.StatusCode = 200
            $response.Close()
            continue
        }

        if ($urlPath -eq "/" -or $urlPath -eq "/index.html") {
            if (Test-Path $htmlPath) {
                $bytes = [System.IO.File]::ReadAllBytes($htmlPath)
                $response.ContentType = "text/html; charset=utf-8"
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $response.StatusCode = 404
            }
            $response.Close()
            continue
        }

        if ($urlPath -eq "/api/data" -and $method -eq "GET") {
            $data = Get-RefreshedData
            $json = $data | ConvertTo-Json -Depth 6
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json; charset=utf-8"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.Close()
            continue
        }

        if ($urlPath -eq "/api/add-training" -and $method -eq "POST") {
            $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $body = $reader.ReadToEnd()
            $reqObj = $body | ConvertFrom-Json

            $egitimTarihi = $reqObj.egitimTarihi # yyyy-MM-dd
            $egitimSaati = $reqObj.egitimSaati   # örn: 09:00 - 13:00 (4 Saat)
            $egitimSuresiSaat = if ($reqObj.egitimSuresiSaat) { [int]$reqObj.egitimSuresiSaat } else { 4 }
            $egitimKonusu = if ($reqObj.egitimKonusu) { $reqObj.egitimKonusu } else { "Temel İş Sağlığı ve Güvenliği Eğitimi" }
            $egitmen = if ($reqObj.egitmen) { $reqObj.egitmen } else { "İş Güvenliği Uzmanı / İşyeri Hekimi" }
            $egitimYeri = if ($reqObj.egitimYeri) { $reqObj.egitimYeri } else { "Belediye Eğitim Salonu" }
            $notlar = if ($reqObj.notlar) { $reqObj.notlar } else { "" }
            $tcList = @($reqObj.katilimciTcListesi)

            Write-Host "Yeni Eğitim Kaydı Alındı: $egitimKonusu - Tarih: $egitimTarihi - Saat: $egitimSaati - Katılımcı: $($tcList.Count) kişi" -ForegroundColor Green

            # Load calisanlar.json
            $raw = [System.IO.File]::ReadAllText($dataPath, [System.Text.Encoding]::UTF8)
            $db = $raw | ConvertFrom-Json

            $trainingDateObj = [DateTime]::ParseExact($egitimTarihi, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
            $gecerlilikDateObj = $trainingDateObj.AddYears(2)
            $today = [DateTime]::Today

            $updatedCount = 0
            $tcSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$tcList)

            foreach ($emp in $db.employees) {
                if ($tcSet.Contains($emp.tc)) {
                    $emp.sonEgitimTarihi = $trainingDateObj.ToString("yyyy-MM-dd")
                    $emp.sonEgitimTarihiGosterim = $trainingDateObj.ToString("dd.MM.yyyy")
                    $emp.sonEgitimSaati = $egitimSaati
                    $emp.sonEgitimKonusu = $egitimKonusu
                    $emp.sonEgitimEgitmen = $egitmen
                    $emp.gecerlilikBitisTarihi = $gecerlilikDateObj.ToString("yyyy-MM-dd")
                    $emp.gecerlilikBitisGosterim = $gecerlilikDateObj.ToString("dd.MM.yyyy")
                    
                    $kalan = [int][Math]::Floor(($gecerlilikDateObj - $today).TotalDays)
                    $emp.kalanGun = $kalan
                    $emp.durum = if ($kalan -lt 0) { "Süresi Dolmuş" } elseif ($kalan -le 90) { "Eğitim Yaklaştı (<90 Gün)" } else { "Geçerli" }
                    $emp.durumKodu = if ($kalan -lt 0) { "expired" } elseif ($kalan -le 90) { "warning" } else { "valid" }
                    $updatedCount++
                }
            }

            # Save calisanlar.json
            $updatedJson = $db | ConvertTo-Json -Depth 6
            [System.IO.File]::WriteAllText($dataPath, $updatedJson, [System.Text.Encoding]::UTF8)

            # Record to training history
            $historyList = [System.Collections.Generic.List[PSObject]]::new()
            if (Test-Path $historyPath) {
                $rawHist = [System.IO.File]::ReadAllText($historyPath, [System.Text.Encoding]::UTF8)
                $oldList = $rawHist | ConvertFrom-Json
                foreach ($h in $oldList) { $historyList.Add($h) }
            }

            $newRecord = [PSCustomObject]@{
                id = $historyList.Count + 1
                egitimTarihi = $egitimTarihi
                egitimTarihiGosterim = $trainingDateObj.ToString("dd.MM.yyyy")
                egitimSaati = $egitimSaati
                egitimSuresiSaat = $egitimSuresiSaat
                egitimKonusu = $egitimKonusu
                egitmen = $egitmen
                egitimYeri = $egitimYeri
                katilimciSayisi = $updatedCount
                katilimciTcListesi = $tcList
                notlar = $notlar
                kayitTarihi = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
            $historyList.Add($newRecord)

            $histJson = $historyList | ConvertTo-Json -Depth 6
            [System.IO.File]::WriteAllText($historyPath, $histJson, [System.Text.Encoding]::UTF8)

            # Response
            $respObj = [PSCustomObject]@{
                success = $true
                message = "$updatedCount personelin eğitimi başarıyla güncellendi. Geçerlilik süresi 2 yıl olarak ayarlandı."
                updatedCount = $updatedCount
                newTrainingId = $newRecord.id
            }
            $respJson = $respObj | ConvertTo-Json
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($respJson)
            $response.ContentType = "application/json; charset=utf-8"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.Close()
            continue
        }

        if ($urlPath -eq "/api/send-toast" -and $method -eq "POST") {
            try {
                Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
                Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
                
                $data = Get-RefreshedData
                $warnCount = $data.summary.warningCount
                $expCount = $data.summary.expiredCount

                [System.Media.SystemSounds]::Exclamation.Play()
                $notification = New-Object System.Windows.Forms.NotifyIcon
                $notification.Icon = [System.Drawing.SystemIcons]::Warning
                $notification.BalloonTipTitle = "İSG Eğitim Bildirimi"
                $notification.BalloonTipText = "$warnCount çalışanın eğitimi 90 günden az kaldı! $expCount çalışanın eğitim süresi doldu."
                $notification.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
                $notification.Visible = $true
                $notification.ShowBalloonTip(5000)
                Start-Sleep -Milliseconds 1200
                $notification.Dispose()

                $respJson = '{"success":true}'
            } catch {
                $respJson = '{"success":false,"error":"' + $_.Exception.Message + '"}'
            }

            $bytes = [System.Text.Encoding]::UTF8.GetBytes($respJson)
            $response.ContentType = "application/json; charset=utf-8"
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.Close()
            continue
        }

        # 404
        $response.StatusCode = 404
        $response.Close()

    } catch {
        Write-Host "İstek hatası: $_" -ForegroundColor Red
        try {
            if ($response) {
                $response.StatusCode = 500
                $errBytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Sunucu hatası"}')
                $response.ContentType = "application/json; charset=utf-8"
                $response.ContentLength64 = $errBytes.Length
                $response.OutputStream.Write($errBytes, 0, $errBytes.Length)
                $response.Close()
            }
        } catch {}
    }
}

$listener.Close()
