param (
    [string]$DataPath = "calisanlar.json",
    [switch]$ShowDialog,
    [switch]$Quiet
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $DataPath)) {
    Write-Host "Veri dosyası bulunamadı: $DataPath. Önce parse_data.ps1 çalıştırılıyor..."
    & powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\parse_data.ps1"
}

$raw = [System.IO.File]::ReadAllText($DataPath, [System.Text.Encoding]::UTF8)
$data = $raw | ConvertFrom-Json

$today = [DateTime]::Today

$warningList = [System.Collections.Generic.List[PSObject]]::new()
$expiredList = [System.Collections.Generic.List[PSObject]]::new()
$noTrainingList = [System.Collections.Generic.List[PSObject]]::new()

foreach ($emp in $data.employees) {
    if (-not $emp.aktifMi) { continue }

    if ([string]::IsNullOrWhiteSpace($emp.sonEgitimTarihi)) {
        $noTrainingList.Add($emp)
        continue
    }

    try {
        $sonEgitimDate = [DateTime]::ParseExact($emp.sonEgitimTarihi, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
        $gecerlilikDate = $sonEgitimDate.AddYears(2)
        $kalanGun = [int][Math]::Floor(($gecerlilikDate - $today).TotalDays)
        $emp.kalanGun = $kalanGun

        if ($kalanGun -lt 0) {
            $emp.durum = "Süresi Dolmuş"
            $emp.durumKodu = "expired"
            $expiredList.Add($emp)
        } elseif ($kalanGun -le 90) {
            $emp.durum = "Eğitim Yaklaştı (<90 Gün)"
            $emp.durumKodu = "warning"
            $warningList.Add($emp)
        }
    } catch {}
}

$totalAlerts = $warningList.Count + $expiredList.Count

Write-Host "=========================================================="
Write-Host "  İSG EĞİTİM GEÇERLİLİK VE BİLDİRİM KONTROL RAPORU"
Write-Host "  Tarih: $($today.ToString('dd.MM.yyyy'))"
Write-Host "=========================================================="
Write-Host "Toplam Çalışan: $($data.employees.Count)"
Write-Host "⚠️ Eğitimi Yaklaşanlar (90 Günden Az Kaldı): $($warningList.Count)"
Write-Host "⛔ Eğitimi Süresi Dolanlar: $($expiredList.Count)"
Write-Host "⭕ Henüz Eğitim Almamış Olanlar: $($noTrainingList.Count)"
Write-Host "=========================================================="

if ($warningList.Count -gt 0) {
    Write-Host "`n--- ⚠️ EĞİTİMİ YAKLAŞAN ÇALIŞANLAR (90 GÜNDEN AZ KALDI) ---" -ForegroundColor Yellow
    $warningList | Select-Object tc, adSoyad, sonEgitimTarihiGosterim, gecerlilikBitisGosterim, kalanGun, bolumu, gsm | Format-Table -AutoSize
}

if ($expiredList.Count -gt 0) {
    Write-Host "`n--- ⛔ EĞİTİM SÜRESİ DOLMUŞ ÇALIŞANLAR ---" -ForegroundColor Red
    $expiredList | Select-Object tc, adSoyad, sonEgitimTarihiGosterim, gecerlilikBitisGosterim, kalanGun, bolumu, gsm | Format-Table -AutoSize
}

# Windows Balloon Tip Notification
if ($totalAlerts -gt 0) {
    $msgTitle = "İSG EĞİTİM BİLDİRİMİ"
    $msgText = "$($warningList.Count) personelin eğitimi 90 günden az kaldı!`n$($expiredList.Count) personelin eğitim süresi doldu."
    
    try {
        [System.Media.SystemSounds]::Exclamation.Play()
        $notification = New-Object System.Windows.Forms.NotifyIcon
        $notification.Icon = [System.Drawing.SystemIcons]::Warning
        $notification.BalloonTipTitle = $msgTitle
        $notification.BalloonTipText = $msgText
        $notification.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
        $notification.Visible = $true
        $notification.ShowBalloonTip(7000)
        Start-Sleep -Milliseconds 1500
        $notification.Dispose()
    } catch {
        Write-Host "Bildirim gösterilemedi: $_"
    }

    # Save alert file
    $alertReport = "==========================================================`r`n" +
                   "İSG EĞİTİMİ YAKLAŞAN PERSONEL LİSTESİ BİLDİRİMİ (<90 GÜN)`r`n" +
                   "Rapor Tarihi: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')`r`n" +
                   "==========================================================`r`n`r`n"

    $alertReport += "EĞİTİMİ YAKLAŞANLAR (1-90 GÜN ARASI):`r`n"
    foreach ($w in $warningList) {
        $alertReport += "TC: $($w.tc) | $($w.adSoyad) | Bölüm: $($w.bolumu) | Son Eğitim: $($w.sonEgitimTarihiGosterim) | Bitiş: $($w.gecerlilikBitisGosterim) | KALAN GÜN: $($w.kalanGun) | GSM: $($w.gsm)`r`n"
    }

    $alertReport += "`r`nSÜRESİ DOLMUŞ OLANLAR:`r`n"
    foreach ($e in $expiredList) {
        $alertReport += "TC: $($e.tc) | $($e.adSoyad) | Bölüm: $($e.bolumu) | Son Eğitim: $($e.sonEgitimTarihiGosterim) | Bitiş: $($e.gecerlilikBitisGosterim) | GECİKEN GÜN: $([Math]::Abs($e.kalanGun)) | GSM: $($e.gsm)`r`n"
    }

    [System.IO.File]::WriteAllText("$PSScriptRoot\isg_egitim_bildirimleri.txt", $alertReport, [System.Text.Encoding]::UTF8)
    Write-Host "`nBildirim listesi kaydedildi: isg_egitim_bildirimleri.txt" -ForegroundColor Green

    if ($ShowDialog) {
        $dialogText = "DİKKAT: İSG Eğitim Süresi Yaklaşan Personeller Tespit Edildi!`n`n" +
                      "• 90 Günden Az Kalanlar: $($warningList.Count) Kişi`n" +
                      "• Süresi Dolmuş Olanlar: $($expiredList.Count) Kişi`n`n" +
                      "Detaylı takip ve yeni eğitim formu girişi için web paneli açmak ister misiniz?"
        $res = [System.Windows.Forms.MessageBox]::Show($dialogText, "İSG Eğitim Takip Bildirimi", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.ToolTipIcon]::Warning)
        if ($res -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-Process "http://localhost:5050"
        }
    }
} else {
    Write-Host "`nTüm çalışanların İSG eğitimleri güncel. 90 günden az kalan eğitim bulunmamaktadır." -ForegroundColor Green
}
