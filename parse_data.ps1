param (
    [string]$InputPath = "calisanListTable.xls",
    [string]$OutputPath = "calisanlar.json",
    [string]$HistoryPath = "egitim_kayitlari.json"
)

Write-Host "Parsing $InputPath..."
$html = [System.IO.File]::ReadAllText($InputPath, [System.Text.Encoding]::UTF8)

# Match rows
$rowRegex = [System.Text.RegularExpressions.Regex]::new('(?si)<tr[^>]*>(.*?)</tr>')
$cellRegex = [System.Text.RegularExpressions.Regex]::new('(?si)<t[dh][^>]*>(.*?)</t[dh]>')

$rowMatches = $rowRegex.Matches($html)
Write-Host "Found $($rowMatches.Count) total rows (including header)."

if ($rowMatches.Count -lt 2) {
    Write-Error "No data rows found."
    exit 1
}

# Header row
$headers = @()
foreach ($m in $cellRegex.Matches($rowMatches[0].Groups[1].Value)) {
    $val = [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value).Trim()
    $val = [System.Text.RegularExpressions.Regex]::Replace($val, '<[^>]+>', '').Trim()
    $headers += $val
}

$today = [DateTime]::Today
Write-Host "Referans Tarih (Bugün): $($today.ToString('yyyy-MM-dd'))"

$employees = [System.Collections.Generic.List[PSObject]]::new()

$validCount = 0
$criticalCount = 0 # <= 90 days and >= 0
$expiredCount = 0  # < 0
$noTrainingCount = 0

for ($i = 1; $i -lt $rowMatches.Count; $i++) {
    $cells = @()
    foreach ($m in $cellRegex.Matches($rowMatches[$i].Groups[1].Value)) {
        $val = [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value).Trim()
        $val = [System.Text.RegularExpressions.Regex]::Replace($val, '<[^>]+>', '').Trim()
        $cells += $val
    }
    
    if ($cells.Count -lt 3) { continue }

    $tc = if ($cells.Count -gt 0) { $cells[0].Trim() } else { "" }
    $ad = if ($cells.Count -gt 1) { $cells[1].Trim() } else { "" }
    $soyad = if ($cells.Count -gt 2) { $cells[2].Trim() } else { "" }
    $cinsiyet = if ($cells.Count -gt 3) { $cells[3].Trim() } else { "" }
    $dogumTarihi = if ($cells.Count -gt 4) { $cells[4].Trim() } else { "" }
    $yas = if ($cells.Count -gt 5) { $cells[5].Trim() } else { "" }
    $firmasi = if ($cells.Count -gt 6) { $cells[6].Trim() } else { "" }
    $sicil = if ($cells.Count -gt 7) { $cells[7].Trim() } else { "" }
    $meslegi = if ($cells.Count -gt 8) { $cells[8].Trim() } else { "" }
    $gorevi = if ($cells.Count -gt 9) { $cells[9].Trim() } else { "" }
    $girisi = if ($cells.Count -gt 10) { $cells[10].Trim() } else { "" }
    $cikisi = if ($cells.Count -gt 11) { $cells[11].Trim() } else { "" }
    $sonPeriyodik = if ($cells.Count -gt 12) { $cells[12].Trim() } else { "" }
    $ilkIgm = if ($cells.Count -gt 13) { $cells[13].Trim() } else { "" }
    $sonEgitimStr = if ($cells.Count -gt 14) { $cells[14].Trim() } else { "" }
    $bolumu = if ($cells.Count -gt 15) { $cells[15].Trim() } else { "" }
    $kisimi = if ($cells.Count -gt 16) { $cells[16].Trim() } else { "" }
    $gsm = if ($cells.Count -gt 17) { $cells[17].Trim() } else { "" }
    $kanGrubu = if ($cells.Count -gt 18) { $cells[18].Trim() } else { "" }
    $uyrugu = if ($cells.Count -gt 19) { $cells[19].Trim() } else { "" }

    # Parse son egitim
    $sonEgitimDate = $null
    $gecerlilikDate = $null
    $kalanGun = $null
    $durum = "Eğitimsiz"
    $durumKodu = "no_training" # no_training, expired, warning, valid

    if (-not [string]::IsNullOrWhiteSpace($sonEgitimStr)) {
        try {
            $cleaned = $sonEgitimStr.Trim()
            if ($cleaned -match '^\d{1,2}\.\d{1,2}\.\d{4}$') {
                $sonEgitimDate = [DateTime]::ParseExact($cleaned, "dd.MM.yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
            } elseif ($cleaned -match '^\d{4}-\d{2}-\d{2}$') {
                $sonEgitimDate = [DateTime]::ParseExact($cleaned, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
            } else {
                $sonEgitimDate = [DateTime]::Parse($cleaned)
            }
        } catch {
            $sonEgitimDate = $null
        }

        if ($sonEgitimDate) {
            # Geçerlilik süresi 2 yıl
            $gecerlilikDate = $sonEgitimDate.AddYears(2)
            $diff = ($gecerlilikDate - $today).TotalDays
            $kalanGun = [int][Math]::Floor($diff)

            if ($kalanGun -lt 0) {
                $durum = "Süresi Dolmuş"
                $durumKodu = "expired"
                $expiredCount++
            } elseif ($kalanGun -le 90) {
                $durum = "Eğitim Yaklaştı (<90 Gün)"
                $durumKodu = "warning"
                $criticalCount++
            } else {
                $durum = "Geçerli"
                $durumKodu = "valid"
                $validCount++
            }
        } else {
            $noTrainingCount++
        }
    } else {
        $noTrainingCount++
    }

    $emp = [PSCustomObject]@{
        id = $i
        tc = $tc
        ad = $ad
        soyad = $soyad
        adSoyad = "$ad $soyad"
        cinsiyet = $cinsiyet
        dogumTarihi = $dogumTarihi
        yas = $yas
        firmasi = $firmasi
        firmaSicil = $sicil
        meslegi = $meslegi
        gorevi = $gorevi
        iseGiris = $girisi
        istenCikis = $cikisi
        sonPeriyodikMuayene = $sonPeriyodik
        ilkIgm = $ilkIgm
        sonEgitimTarihi = if ($sonEgitimDate) { $sonEgitimDate.ToString("yyyy-MM-dd") } else { "" }
        sonEgitimTarihiGosterim = if ($sonEgitimDate) { $sonEgitimDate.ToString("dd.MM.yyyy") } else { "" }
        sonEgitimSaati = if ($sonEgitimDate) { "09:00 - 13:00 (4 Saat)" } else { "" }
        sonEgitimKonusu = if ($sonEgitimDate) { "Temel İş Sağlığı ve Güvenliği Eğitimi" } else { "" }
        sonEgitimEgitmen = if ($sonEgitimDate) { "İSG Uzmanı / İşyeri Hekimi" } else { "" }
        gecerlilikBitisTarihi = if ($gecerlilikDate) { $gecerlilikDate.ToString("yyyy-MM-dd") } else { "" }
        gecerlilikBitisGosterim = if ($gecerlilikDate) { $gecerlilikDate.ToString("dd.MM.yyyy") } else { "" }
        kalanGun = $kalanGun
        durum = $durum
        durumKodu = $durumKodu
        bolumu = if ([string]::IsNullOrWhiteSpace($bolumu)) { "DİĞER" } else { $bolumu }
        kisimi = $kisimi
        gsm = $gsm
        kanGrubu = $kanGrubu
        uyrugu = $uyrugu
        aktifMi = [string]::IsNullOrWhiteSpace($cikisi)
    }

    $employees.Add($emp)
}

$summary = [PSCustomObject]@{
    total = $employees.Count
    activeEmployees = ($employees | Where-Object { $_.aktifMi }).Count
    inactiveEmployees = ($employees | Where-Object { -not $_.aktifMi }).Count
    validCount = $validCount
    warningCount = $criticalCount
    expiredCount = $expiredCount
    noTrainingCount = $noTrainingCount
    generatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

Write-Host "Veri Özeti:"
Write-Host "Toplam Personel: $($summary.total)"
Write-Host "Geçerli (>90 Gün): $validCount"
Write-Host "Yaklaşan (<=90 Gün Kaldı): $criticalCount"
Write-Host "Süresi Dolan (<0 Gün): $expiredCount"
Write-Host "Eğitimsiz: $noTrainingCount"

$outputObj = [PSCustomObject]@{
    summary = $summary
    employees = $employees
}

$json = $outputObj | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.Encoding]::UTF8)
Write-Host "Başarıyla yazıldı: $OutputPath"

# Initialize training history if doesn't exist
if (-not (Test-Path $HistoryPath)) {
    $initHistory = @(
        [PSCustomObject]@{
            id = 1
            egitimTarihi = "2026-10-14"
            egitimSaati = "09:00 - 13:00 (4 Saat)"
            egitimSuresiSaat = 4
            egitimKonusu = "Temel İş Sağlığı ve Güvenliği Eğitimi"
            egitmen = "İş Güvenliği Uzmanı A Sınıfı"
            egitimYeri = "Belediye Meclis Salonu"
            katilimciSayisi = 12
            notlar = "Park ve Bahçeler Müdürlüğü personeli temel eğitimi"
            kayitTarihi = "2026-10-14 13:30:00"
        }
    )
    $histJson = $initHistory | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($HistoryPath, $histJson, [System.Text.Encoding]::UTF8)
    Write-Host "Eğitim geçmişi oluşturuldu: $HistoryPath"
}
