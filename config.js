// ============================================================
//  AYARLAR  —  Firebase bilgilerini buraya gir.
//  Firebase Console > Proje Ayarları (dişli) > "Web uygulaması"
//  ekleyince sana bu firebaseConfig nesnesini verir; aynen yapıştır.
//  (Bu değerler tarayıcıda görünür olacak şekilde tasarlanmıştır.
//   Güvenlik, Firestore kurallarıyla -firestore.rules- sağlanır.)
// ============================================================

window.GV_FIREBASE = {
  apiKey:            "BURAYA_apiKey",
  authDomain:        "BURAYA_authDomain",       // genelde proje-adi.firebaseapp.com
  projectId:         "BURAYA_projectId",
  storageBucket:     "BURAYA_storageBucket",
  messagingSenderId: "BURAYA_messagingSenderId",
  appId:             "BURAYA_appId"
};

window.GV_CONFIG = {
  SITE_ADI: "Ben Güller Vadisi Sitesi",
  KORT_ADI: "Tenis Kortu",

  // Kort saatleri (07:00 - 23:00). İlk slot 07:00, son slot 22:00-23:00.
  ACILIS_SAATI: 7,
  KAPANIS_SAATI: 23,

  // Kaç gün ileriye rezervasyon açılsın (bugün dahil)
  GUN_SAYISI: 7
};
