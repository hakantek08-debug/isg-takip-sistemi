# İSG Eğitim Takip Formu ve Bildirim Sistemi

Osmangazi Belediyesi Personel A.Ş. için geliştirilmiş web tabanlı İş Sağlığı ve Güvenliği (İSG) periyodik eğitim takip, 2 yıllık geçerlilik denetimi ve 90 gün öncesi otomatik bildirim sistemi.

---

## 📌 Özellikler

* **2 Yıl Geçerlilik Kontrolü:** 6331 Sayılı İSG Kanunu ve ilgili yönetmelikler kapsamında, tamamlanan eğitimlerin geçerlilik süresi otomatik olarak tam 2 yıl (24 ay) olarak işletilir.
* **90 Gün Öncesi Otomatik Bildirim:** Geçerlilik süresinin dolmasına 90 günden az kalan personeller için:
  * Web arayüzünde acil uyarı şeritleri ve bildirim rozetleri,
  * Windows masaüstü balon bildirimleri (Toast / BalloonTip) ve sistem sesli uyarıları,
  * Tek tıkla ilgili personele/amirine gönderilmek üzere hazır **WhatsApp & SMS bildirim metni** üretimi.
* **Yeni Eğitim Giriş Formu:** Eğitim tarihi, eğitim saati/aralığı (örn. 09:00 - 13:00), eğitim süresi (saat), konu, eğitici ve katılımcı listesi girişi.
* **Resmi İSG Eğitim Katılım Formu (PDF / Yazdır):** 6331 sayılı kanun standartlarına uygun, A4 formatında kurum başlıklı, katılımcı çizelgeli ve imza alanlı resmi çıktı şablonu.
* **Excel Dışa Aktarma:** Filtrelenmiş veya tüm personel listesini tek tıkla `.xls` Excel formatında indirme.
* **Eğitim Tarihçesi Arşivi:** Gerçekleştirilen tüm eğitim oturumlarının geriye dönük arşivi ve formları tekrar yazdırabilme imkanı.

---

## 🚀 Hızlı Başlangıç

Sistemi çalıştırmak için herhangi bir harici kurulum gerekmez:

1. **`ISG_Egitim_Takip_Sistemi.bat`** dosyasına çift tıklayın.
2. Sistem otomatik olarak:
   * 90 günden az kalan eğitimleri denetler ve bildirim raporunu günceller,
   * Yerel web sunucusunu `http://localhost:5050` adresinde başlatır,
   * Varsayılan internet tarayıcınızı otomatik olarak açar.

Alternatif olarak, yalnızca bildirim kontrolü yapmak için **`Bildirim_Kontrol.bat`** dosyasını çalıştırabilirsiniz.

---

## 📂 Proje Yapısı

```
İSG Yazılım/
├── index.html                  # Modern web arayüzü ve yönetim paneli
├── server.ps1                  # Yerel REST API ve HTTP sunucusu
├── parse_data.ps1              # Veri işleme ve geçerlilik hesaplama motoru
├── bildirim_kontrol.ps1        # Masaüstü bildirim ve raporlama scripti
├── ISG_Egitim_Takip_Sistemi.bat# 1 tıkla başlatıcı
├── Bildirim_Kontrol.bat        # Hızlı bildirim kontrolü
├── calisanlar.json             # Çalışan ve eğitim veritabanı
├── egitim_kayitlari.json       # Geçmiş eğitim oturumları arşivi
└── README.md                   # Proje dokümantasyonu
```

---

## ⚖️ Yasal Dayanak

Bu sistem; **6331 Sayılı İş Sağlığı ve Güvenliği Kanunu** ile **Çalışanların İş Sağlığı ve Güvenliği Eğitimlerinin Usul ve Esasları Hakkında Yönetmelik** hükümlerine tam uyumlu olarak tasarlanmıştır.
