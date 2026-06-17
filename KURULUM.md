# Güller Vadisi · Tenis Kortu Rezervasyon

Ben Güller Vadisi Sitesi (104 hane) tenis kortu için rezervasyon uygulaması.

- Sakinler **e-posta + şifre** ile kaydolur, **kapı numarasını** girer.
- 7 gün, **07:00–23:00** arası saatler görünür.
- Boş saate dokunup **en az 1, en fazla 2 ardışık saat** rezerve edilir.
- Dolu saatlerde **kapı numarası** görünür. Çakışma engellenir.
- Biri rezerve edince herkeste **anında** güncellenir (canlı).
- Telefona uygulama gibi kurulabilir (PWA).

## Teknik

| Parça | Ne kullanıyoruz |
|---|---|
| Arayüz | Saf HTML/CSS/JS — Netlify'da yayınlanır |
| Üyelik + veritabanı | **Firebase** (Authentication + Firestore) — ortak ve canlı veri |
| Kaynak kodu | GitHub |
| Alan adı | gullervadisi.com → Netlify |

## Çakışma nasıl engelleniyor?

Her saat dilimi, kimliği `TARİH_SAAT` olan tek bir Firestore kaydıdır (örn. `2026-06-18_10`).
Bu kimlik benzersiz olduğu için aynı saat ikinci kez **oluşturulamaz**. Rezervasyon bir
**transaction** içinde yapılır: önce saat dolu mu bakılır, doluysa iptal; boşsa atomik yazılır.
İki kişi aynı anda denese bile yalnızca biri alır.

## Kurulum sırası
1. **Firebase** projesi aç → Authentication (E-posta/Şifre) ve Firestore'u etkinleştir.
2. `firestore.rules` içeriğini Firestore > Rules'a yapıştır → Publish.
3. Web uygulaması ekle, `firebaseConfig`'i kopyala → `config.js`'e yapıştır.
4. `kurulum.ps1` ile GitHub'a yükle.
5. Netlify'da depoyu bağla → yayınla.
6. gullervadisi.com (veya tenis.gullervadisi.com) alan adını Netlify'a bağla.

Adım adım PowerShell komutları sohbette verilmiştir.

## Yönetim / devir
- Tüm servisler (Firebase, GitHub, Netlify, GoDaddy) **yonetim@gullervadisi.com** ile açılmalı.
- Firebase bir Google hesabıdır; bir sonraki yöneticiyi Google Cloud IAM'den "Owner" ekleyerek
  şifre paylaşmadan devredebilirsin.
