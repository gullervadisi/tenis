param(
  [string]$GitHubKullanici = "KULLANICI_ADIN",
  [string]$DepoAdi = "guller-vadisi-tenis"
)

# =====================================================================
#  GÜLLER VADİSİ - Tenis Kortu Rezervasyon (Firebase)  |  Otomatik Kurulum
#  Proje klasorunu olusturur, tum dosyalari yazar, GitHub'a yukler.
#  Windows PowerShell'de calistirin.
# =====================================================================

$ErrorActionPreference = "Stop"
$proje = $DepoAdi
$utf8  = New-Object System.Text.UTF8Encoding($false)

Write-Host ""
Write-Host "==> Proje klasoru olusturuluyor: $proje" -ForegroundColor Green
New-Item -ItemType Directory -Force -Path $proje | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $proje "icons") | Out-Null

function Yaz($rel, $txt){
  $full = Join-Path (Get-Location) (Join-Path $proje $rel)
  $dir  = Split-Path $full -Parent
  if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [System.IO.File]::WriteAllText($full, $txt, $utf8)
  Write-Host "    yazildi: $rel"
}
$f_index_html = @'
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
  <meta name="theme-color" content="#2e6e8e" />
  <title>Güller Vadisi · Tenis Kortu Rezervasyon</title>
  <link rel="manifest" href="manifest.webmanifest" />
  <link rel="apple-touch-icon" href="icons/icon-192.png" />
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Sora:wght@600;700&display=swap" rel="stylesheet" />
  <link rel="stylesheet" href="styles.css" />
</head>
<body>
  <!-- Üst bar -->
  <header class="topbar" id="topbar" hidden>
    <div class="brand">
      <span class="brand-eyebrow" id="brand-eyebrow">GÜLLER VADİSİ</span>
      <span class="brand-title" id="brand-title">Tenis Kortu</span>
    </div>
    <div class="who">
      <span class="door-badge" id="door-badge"></span>
      <button class="btn-ghost" id="signout-btn" type="button">Çıkış</button>
    </div>
  </header>

  <main class="wrap">

    <!-- GİRİŞ / KAYIT EKRANI -->
    <section class="auth" id="auth-view">
      <div class="auth-card">
        <div class="court-mark" aria-hidden="true"></div>
        <p class="auth-eyebrow">BEN GÜLLER VADİSİ SİTESİ</p>
        <h1 class="auth-title">Tenis Kortu<br />Rezervasyon</h1>
        <p class="auth-sub">Çakışma olmasın diye herkes önceden buradan rezerve eder. Giriş yapmak için e-posta ve şifreni kullan.</p>

        <div class="tabs" role="tablist">
          <button class="tab is-active" id="tab-login" type="button" role="tab">Giriş yap</button>
          <button class="tab" id="tab-register" type="button" role="tab">Kayıt ol</button>
        </div>

        <form class="auth-form" id="auth-form" autocomplete="on">
          <label class="field">
            <span>E-posta</span>
            <input type="email" id="f-email" required placeholder="ornek@eposta.com" autocomplete="email" />
          </label>

          <label class="field">
            <span>Şifre</span>
            <input type="password" id="f-password" required minlength="6" placeholder="En az 6 karakter" autocomplete="current-password" />
          </label>

          <label class="field" id="door-field" hidden>
            <span>Kapı / Daire numarası</span>
            <input type="text" id="f-door" placeholder="Örn: 12 veya B-7" inputmode="text" maxlength="12" />
          </label>

          <button class="btn-primary" id="auth-submit" type="submit">Giriş yap</button>
          <p class="auth-msg" id="auth-msg" role="status"></p>
        </form>
      </div>
      <p class="footnote">Sitemizdeki kort 07:00–23:00 arası, haftanın 7 günü açıktır.</p>
    </section>

    <!-- REZERVASYON EKRANI -->
    <section class="board" id="board-view" hidden>

      <div class="board-head">
        <h2 id="board-day-title">Bugün</h2>
        <p class="board-hint">Boş bir saate dokun. Yan yana en fazla <strong>2 saat</strong>, en az <strong>1 saat</strong> seçebilirsin.</p>
      </div>

      <!-- Gün seçici -->
      <div class="days" id="days" role="tablist" aria-label="Gün seçimi"></div>

      <!-- Saat listesi -->
      <div class="slots" id="slots" aria-live="polite"></div>

    </section>
  </main>

  <!-- Seçim onay çubuğu (alt sabit) -->
  <div class="actionbar" id="actionbar" hidden>
    <div class="actionbar-info">
      <span id="selection-label">Seçim yok</span>
    </div>
    <div class="actionbar-buttons">
      <button class="btn-ghost" id="clear-btn" type="button">Temizle</button>
      <button class="btn-primary" id="reserve-btn" type="button" disabled>Rezerve et</button>
    </div>
  </div>

  <!-- Bilgilendirme baloncuğu -->
  <div class="toast" id="toast" hidden></div>

  <script src="config.js"></script>
  <script type="module" src="app.js"></script>
</body>
</html>

'@
Yaz "index.html" $f_index_html
$f_styles_css = @'
/* ============================================================
   GÜLLER VADİSİ — Tenis Kortu Rezervasyon
   Görsel kimlik: kortun gerçek renkleri — MAVİ zemin,
   TERRACOTTA çevre (apron), BEYAZ kort çizgileri (imza).
   ============================================================ */

:root{
  --court:        #4fa3cc;   /* kort mavisi (oyun zemini) */
  --court-dark:   #2e6e8e;   /* koyu mavi (başlıklar) */
  --court-deep:   #1f506a;
  --line:         #ffffff;   /* kort çizgileri — imza */
  --clay:         #b85742;   /* terracotta çevre — vurgu / birincil işlem */
  --clay-deep:    #9c4634;
  --clay-soft:    #f4ddd5;
  --ink:          #18272e;
  --ink-soft:     #566970;
  --bg:           #edf1f3;   /* güneşli beton — açık nötr */
  --panel:        #ffffff;
  --panel-2:      #f1f6f8;
  --busy-bg:      #eef1f2;
  --busy-ink:     #6e7d83;
  --danger:       #b23b3b;
  --radius:       14px;
  --shadow:       0 1px 2px rgba(31,80,106,.08), 0 8px 24px rgba(31,80,106,.10);
  --shadow-soft:  0 1px 3px rgba(31,80,106,.10);
  --ring:         0 0 0 3px rgba(184,87,66,.30);
}

*{ box-sizing: border-box; }
html,body{ margin:0; padding:0; }

body{
  font-family:"Inter", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  color: var(--ink);
  background: radial-gradient(1200px 600px at 50% -10%, #f4f8fa 0%, var(--bg) 60%);
  min-height:100dvh; -webkit-font-smoothing:antialiased;
  padding-bottom: env(safe-area-inset-bottom);
}

/* ---------- Üst bar ---------- */
.topbar{
  display:flex; align-items:center; justify-content:space-between; gap:12px;
  padding:14px 18px; padding-top: calc(14px + env(safe-area-inset-top));
  background: linear-gradient(180deg, var(--court) 0%, var(--court-dark) 100%);
  color:#fff; position:sticky; top:0; z-index:20;
  box-shadow:0 6px 18px rgba(31,80,106,.20);
}
.brand{ display:flex; flex-direction:column; line-height:1; }
.brand-eyebrow{ font-size:10px; letter-spacing:.22em; font-weight:600; color: rgba(255,255,255,.78); }
.brand-title{ font-family:"Sora",sans-serif; font-weight:700; font-size:19px; margin-top:4px; }
.who{ display:flex; align-items:center; gap:10px; }
.door-badge{
  background: rgba(255,255,255,.18); border:1px solid rgba(255,255,255,.32);
  padding:6px 12px; border-radius:999px; font-size:13px; font-weight:600; white-space:nowrap;
}

/* ---------- Genel ---------- */
.wrap{ max-width:760px; margin:0 auto; padding:18px 16px 120px; }

/* ---------- Butonlar ---------- */
.btn-primary{
  appearance:none; border:none; cursor:pointer; font-family:inherit;
  background: var(--clay); color:#fff; font-weight:600; font-size:15px;
  padding:13px 18px; border-radius:12px;
  transition: background .15s, transform .05s, opacity .15s;
  box-shadow:0 6px 16px rgba(184,87,66,.28);
}
.btn-primary:hover{ background: var(--clay-deep); }
.btn-primary:active{ transform: translateY(1px); }
.btn-primary:disabled{ background:#c9d4d8; box-shadow:none; cursor:not-allowed; }

.btn-ghost{
  appearance:none; cursor:pointer; font-family:inherit; font-weight:600; font-size:14px;
  background:transparent; color:inherit; border:1px solid rgba(255,255,255,.42);
  padding:8px 14px; border-radius:10px; transition: background .15s;
}
.btn-ghost:hover{ background: rgba(255,255,255,.14); }

/* ---------- Giriş ekranı ---------- */
.auth{ display:flex; flex-direction:column; align-items:center; gap:18px; padding-top:26px; }
.auth-card{
  width:100%; max-width:420px; background: var(--panel); border-radius:20px;
  box-shadow: var(--shadow); padding:30px 26px 26px; position:relative; overflow:hidden;
  border:1px solid #e3eaed;
}
/* İmza: gerçek kort kesiti — terracotta çerçeve, mavi zemin, beyaz çizgiler */
.court-mark{ height:92px; margin:-30px -26px 22px; position:relative; background: var(--clay); }
.court-mark::before{   /* mavi oyun alanı */
  content:""; position:absolute; inset:12px 22px; background: var(--court);
}
.court-mark::after{    /* beyaz dış çizgi + orta file */
  content:""; position:absolute; inset:20px 30px;
  border:2px solid var(--line);
  box-shadow: inset 0 0 0 0 transparent;
  background:
    linear-gradient(var(--line),var(--line)) center/2px 100% no-repeat;
}
.auth-eyebrow{ margin:0; font-size:11px; letter-spacing:.2em; font-weight:600; color: var(--court-dark); }
.auth-title{ font-family:"Sora",sans-serif; font-weight:700; font-size:30px; line-height:1.05; margin:6px 0 12px; }
.auth-sub{ margin:0 0 22px; color: var(--ink-soft); font-size:14px; line-height:1.5; }

.tabs{ display:flex; background: var(--panel-2); border-radius:12px; padding:4px; margin-bottom:18px; }
.tab{
  flex:1; appearance:none; border:none; background:transparent; cursor:pointer; font-family:inherit;
  font-weight:600; font-size:14px; color: var(--ink-soft); padding:10px; border-radius:9px; transition: all .15s;
}
.tab.is-active{ background:#fff; color: var(--court-dark); box-shadow: var(--shadow-soft); }

.auth-form{ display:flex; flex-direction:column; gap:14px; }
.field{ display:flex; flex-direction:column; gap:6px; }
.field > span{ font-size:13px; font-weight:600; }
.field input{
  font-family:inherit; font-size:16px; padding:12px 14px;
  border:1px solid #d6e0e4; border-radius:11px; background:#fff; color: var(--ink);
  transition: border-color .15s, box-shadow .15s;
}
.field input:focus{ outline:none; border-color: var(--clay); box-shadow: var(--ring); }
.auth-form .btn-primary{ margin-top:6px; }
.auth-msg{ margin:4px 2px 0; font-size:13.5px; min-height:18px; }
.auth-msg.err{ color: var(--danger); }
.auth-msg.ok{ color: var(--court-dark); }
.footnote{ color: var(--ink-soft); font-size:12.5px; text-align:center; margin:0; }

/* ---------- Pano ---------- */
.board-head{ margin-bottom:14px; }
.board-head h2{ font-family:"Sora",sans-serif; font-size:22px; margin:0 0 4px; }
.board-hint{ margin:0; color: var(--ink-soft); font-size:13px; line-height:1.5; }
.board-hint strong{ color: var(--clay-deep); }

/* Gün seçici */
.days{ display:flex; gap:8px; overflow-x:auto; padding:4px 2px 12px; margin:14px -2px 6px;
  -webkit-overflow-scrolling:touch; scrollbar-width:none; }
.days::-webkit-scrollbar{ display:none; }
.day-chip{
  flex:0 0 auto; min-width:62px; cursor:pointer; appearance:none; font-family:inherit;
  background:#fff; border:1px solid #d9e3e7; border-radius:14px; padding:10px 8px;
  display:flex; flex-direction:column; align-items:center; gap:2px; transition: all .15s; color: var(--ink);
}
.day-chip .dow{ font-size:11px; font-weight:600; color: var(--ink-soft); letter-spacing:.04em; }
.day-chip .dnum{ font-family:"Sora",sans-serif; font-weight:700; font-size:18px; }
.day-chip.is-active{ background: var(--court-dark); border-color: var(--court-dark); color:#fff;
  box-shadow:0 6px 16px rgba(31,80,106,.24); }
.day-chip.is-active .dow{ color: rgba(255,255,255,.82); }
.day-chip.is-today .dnum::after{ content:""; display:block; width:5px; height:5px; border-radius:50%;
  background: var(--clay); margin:3px auto 0; }
.day-chip.is-active.is-today .dnum::after{ background:#fff; }

/* Saat listesi */
.slots{ display:flex; flex-direction:column; gap:8px; margin-top:8px; }
.slot{
  display:flex; align-items:center; gap:14px; width:100%; padding:14px 16px; border-radius: var(--radius);
  border:1px solid #dfe8eb; background:#fff; text-align:left; font-family:inherit; cursor:pointer;
  transition: all .12s ease; color: var(--ink); position:relative;
}
.slot .time{ font-family:"Sora",sans-serif; font-weight:700; font-size:16px; min-width:104px; }
.slot .state{ font-size:13.5px; color: var(--court-dark); font-weight:600; }
.slot .pill{ margin-left:auto; font-size:12.5px; font-weight:600; padding:5px 11px; border-radius:999px;
  background: var(--clay-soft); color: var(--clay-deep); white-space:nowrap; }

.slot.free:hover{ border-color: var(--clay); box-shadow: var(--ring); }
.slot.selected{ border-color: var(--clay); background: var(--clay-soft);
  box-shadow:0 6px 16px rgba(184,87,66,.18); }
.slot.selected .state{ color: var(--clay-deep); }

.slot.busy{ background: var(--busy-bg); cursor:default; border-color:#e6ebed; }
.slot.busy .time{ color: var(--busy-ink); }
.slot.busy .state{ color: var(--busy-ink); font-weight:500; }
.slot.busy .pill{ background:#e3e8ea; color: var(--busy-ink); }

.slot.mine{ background:#fff; border-color: var(--court); }
.slot.mine .time{ color: var(--court-dark); }
.slot.mine .state{ color: var(--court-dark); }
.slot.mine .pill{ background: var(--court); color:#fff; }
.slot .cancel{ margin-left:auto; appearance:none; border:1px solid var(--danger); color: var(--danger);
  background:#fff; font-family:inherit; font-weight:600; font-size:12.5px; padding:6px 12px;
  border-radius:999px; cursor:pointer; transition: all .12s; }
.slot .cancel:hover{ background: var(--danger); color:#fff; }

.slot.past{ opacity:.45; cursor:default; }
.slot.past .state{ color: var(--ink-soft); font-weight:500; }
.slot:focus-visible{ outline:none; box-shadow: var(--ring); }

/* Alt aksiyon çubuğu */
.actionbar{
  position:fixed; left:0; right:0; bottom:0; z-index:30; display:flex; align-items:center; gap:12px;
  padding:14px 16px calc(14px + env(safe-area-inset-bottom));
  background: rgba(255,255,255,.94); backdrop-filter: blur(8px);
  border-top:1px solid #dfe8eb; box-shadow:0 -8px 24px rgba(31,80,106,.10);
}
.actionbar-info{ flex:1; font-size:14px; font-weight:600; }
.actionbar-info small{ display:block; font-weight:500; color: var(--ink-soft); font-size:12px; }
.actionbar-buttons{ display:flex; gap:10px; }
.actionbar .btn-ghost{ border-color:#d6e0e4; color: var(--ink-soft); }
.actionbar .btn-ghost:hover{ background: var(--panel-2); }

/* Toast */
.toast{
  position:fixed; left:50%; bottom:96px; transform: translateX(-50%);
  background: var(--court-deep); color:#fff; padding:12px 18px; border-radius:12px; font-size:14px;
  font-weight:500; z-index:50; box-shadow:0 10px 30px rgba(0,0,0,.25); max-width:90vw; text-align:center;
  animation: toast-in .25s ease;
}
.toast.err{ background: var(--danger); }
@keyframes toast-in{ from{ opacity:0; transform: translate(-50%,8px);} to{ opacity:1; transform: translate(-50%,0);} }

@media (min-width:720px){ .auth{ padding-top:56px; } .slot .time{ min-width:120px; } }
@media (prefers-reduced-motion: reduce){ *{ animation:none !important; transition:none !important; } }

'@
Yaz "styles.css" $f_styles_css
$f_app_js = @'
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import {
  getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword,
  onAuthStateChanged, signOut
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js";
import {
  getFirestore, collection, doc, getDoc, setDoc, deleteDoc,
  query, where, onSnapshot, runTransaction, serverTimestamp
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js";

/* ====================== Ayarlar ====================== */
const CFG = window.GV_CONFIG;
const OPEN = CFG.ACILIS_SAATI;     // 7
const CLOSE = CFG.KAPANIS_SAATI;   // 23  (son slot 22:00-23:00)
const DAYS = CFG.GUN_SAYISI;       // 7

let app, auth, db;
try {
  if (!window.GV_FIREBASE || String(window.GV_FIREBASE.apiKey).startsWith("BURAYA")) {
    throw new Error("config.js içine Firebase bilgilerini girmelisin.");
  }
  app = initializeApp(window.GV_FIREBASE);
  auth = getAuth(app);
  db = getFirestore(app);
} catch (e) {
  document.getElementById("auth-msg").textContent = "Ayar eksik: " + e.message;
}

/* ====================== Durum ====================== */
const state = {
  user: null,
  doorNumber: null,
  selectedDate: null,
  dates: [],
  reservations: new Map(),   // "date_hour" -> {id, uid, doorNumber, hour, date}
  selection: [],
  mode: "login",
};
let unsub = null;            // canlı dinleyiciyi durdurmak için

/* ====================== Yardımcılar ====================== */
const $ = (id) => document.getElementById(id);
const pad = (n) => String(n).padStart(2, "0");
const DOW = ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"];
const DOW_LONG = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"];
const MONTHS = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];

function fmtDate(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
function parseDate(s) { const p = s.split("-").map(Number); return new Date(p[0], p[1] - 1, p[2]); }
function slotId(date, hour) { return date + "_" + hour; }   // dikkat: saat 0-padsiz (kurallarla uyumlu)

function toast(msg, isErr) {
  const t = $("toast");
  t.textContent = msg;
  t.className = "toast" + (isErr ? " err" : "");
  t.hidden = false;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => { t.hidden = true; }, 3200);
}

/* ====================== Giriş / Kayıt ekranı ====================== */
function setMode(mode) {
  state.mode = mode;
  const isReg = mode === "register";
  $("tab-login").classList.toggle("is-active", !isReg);
  $("tab-register").classList.toggle("is-active", isReg);
  $("door-field").hidden = !isReg;
  $("f-door").required = isReg;
  $("auth-submit").textContent = isReg ? "Kayıt ol" : "Giriş yap";
  $("f-password").autocomplete = isReg ? "new-password" : "current-password";
  $("auth-msg").textContent = "";
}

$("tab-login").addEventListener("click", () => setMode("login"));
$("tab-register").addEventListener("click", () => setMode("register"));

$("auth-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  if (!auth) return;
  const email = $("f-email").value.trim();
  const password = $("f-password").value;
  const door = $("f-door").value.trim();
  const msg = $("auth-msg");
  const btn = $("auth-submit");
  msg.className = "auth-msg";
  msg.textContent = "";

  if (state.mode === "register" && !door) {
    msg.classList.add("err");
    msg.textContent = "Lütfen kapı / daire numaranı gir.";
    return;
  }

  btn.disabled = true;
  btn.textContent = "Lütfen bekle…";
  try {
    if (state.mode === "register") {
      const cred = await createUserWithEmailAndPassword(auth, email, password);
      await setDoc(doc(db, "users", cred.user.uid), {
        email: email, doorNumber: door, createdAt: serverTimestamp()
      });
      // onAuthStateChanged otomatik panoya geçirir
    } else {
      await signInWithEmailAndPassword(auth, email, password);
    }
  } catch (err) {
    msg.classList.add("err");
    msg.textContent = turkceHata(err);
  } finally {
    btn.disabled = false;
    btn.textContent = state.mode === "register" ? "Kayıt ol" : "Giriş yap";
  }
});

function turkceHata(err) {
  const c = (err && err.code) ? err.code : "";
  if (c.includes("invalid-credential") || c.includes("wrong-password") || c.includes("user-not-found"))
    return "E-posta veya şifre hatalı.";
  if (c.includes("email-already-in-use")) return "Bu e-posta zaten kayıtlı. Giriş yap sekmesini kullan.";
  if (c.includes("weak-password")) return "Şifre en az 6 karakter olmalı.";
  if (c.includes("invalid-email")) return "Geçerli bir e-posta gir.";
  if (c.includes("too-many-requests")) return "Çok fazla deneme. Biraz sonra tekrar dene.";
  if (c.includes("network")) return "İnternet bağlantısı sorunlu görünüyor.";
  return "Bir sorun oldu: " + (err.message || "bilinmeyen hata");
}

$("signout-btn").addEventListener("click", () => { if (auth) signOut(auth); });

/* ====================== Oturum dinleyici ====================== */
if (auth) {
  onAuthStateChanged(auth, async (user) => {
    if (user) {
      state.user = user;
      await afterLogin();
    } else {
      state.user = null;
      if (unsub) { unsub(); unsub = null; }
      showAuth();
    }
  });
}

async function afterLogin() {
  $("brand-eyebrow").textContent = (CFG.SITE_ADI || "GÜLLER VADİSİ").toUpperCase();
  $("brand-title").textContent = CFG.KORT_ADI || "Tenis Kortu";

  // Kapı numarası
  let door = "?";
  try {
    const snap = await getDoc(doc(db, "users", state.user.uid));
    if (snap.exists() && snap.data().doorNumber) door = snap.data().doorNumber;
  } catch (e) { /* yoksay */ }
  state.doorNumber = door;
  $("door-badge").textContent = "Kapı " + door;

  showBoard();
  buildDates();
  state.selectedDate = state.dates[0];
  listenReservations();
  renderDays();
  renderSlots();
}

function showAuth() {
  $("topbar").hidden = true;
  $("auth-view").hidden = false;
  $("board-view").hidden = true;
  $("actionbar").hidden = true;
}
function showBoard() {
  $("topbar").hidden = false;
  $("auth-view").hidden = true;
  $("board-view").hidden = false;
}

/* ====================== Tarihler ====================== */
function buildDates() {
  state.dates = [];
  const today = new Date(); today.setHours(0, 0, 0, 0);
  for (let i = 0; i < DAYS; i++) {
    const d = new Date(today); d.setDate(today.getDate() + i);
    state.dates.push(fmtDate(d));
  }
}

/* ====================== Canlı rezervasyon dinleme ====================== */
function listenReservations() {
  if (unsub) { unsub(); unsub = null; }
  const first = state.dates[0];
  const last = state.dates[state.dates.length - 1];
  const q = query(
    collection(db, "reservations"),
    where("date", ">=", first),
    where("date", "<=", last)
  );
  unsub = onSnapshot(q, (snap) => {
    state.reservations.clear();
    snap.forEach((docSnap) => {
      const r = docSnap.data();
      state.reservations.set(slotId(r.date, r.hour), { id: docSnap.id, ...r });
    });
    renderSlots();
  }, (err) => { toast("Veriler yüklenemedi: " + err.message, true); });
}

/* ====================== Gün seçici ====================== */
function renderDays() {
  const wrap = $("days");
  wrap.innerHTML = "";
  const todayStr = state.dates[0];
  state.dates.forEach((ds) => {
    const d = parseDate(ds);
    const btn = document.createElement("button");
    btn.className = "day-chip";
    btn.type = "button";
    if (ds === state.selectedDate) btn.classList.add("is-active");
    if (ds === todayStr) btn.classList.add("is-today");
    btn.innerHTML = '<span class="dow">' + DOW[d.getDay()] + '</span><span class="dnum">' + d.getDate() + '</span>';
    btn.addEventListener("click", () => {
      state.selectedDate = ds;
      state.selection = [];
      renderDays(); renderSlots(); updateActionbar();
    });
    wrap.appendChild(btn);
  });
}

/* ====================== Saat listesi ====================== */
function renderSlots() {
  const wrap = $("slots");
  wrap.innerHTML = "";
  const d = parseDate(state.selectedDate);
  const todayStr = fmtDate(new Date());
  const isToday = state.selectedDate === todayStr;
  const nowHour = new Date().getHours();

  $("board-day-title").textContent = (state.selectedDate === state.dates[0])
    ? "Bugün"
    : DOW_LONG[d.getDay()] + ", " + d.getDate() + " " + MONTHS[d.getMonth()];

  for (let h = OPEN; h < CLOSE; h++) {
    const res = state.reservations.get(slotId(state.selectedDate, h));
    const isPast = isToday && h <= nowHour;
    const isSelected = state.selection.includes(h);
    const tag = (res || isPast) ? "div" : "button";
    const el = document.createElement(tag);
    el.className = "slot";
    if (tag === "button") el.type = "button";
    const timeLabel = pad(h) + ":00 – " + pad(h + 1) + ":00";

    if (res) {
      const mine = res.uid === state.user.uid;
      el.classList.add(mine ? "mine" : "busy");
      el.innerHTML =
        '<span class="time">' + timeLabel + '</span>' +
        '<span class="state">' + (mine ? "Senin rezervasyonun" : "Dolu") + '</span>' +
        '<span class="pill">Kapı ' + escapeHtml(res.doorNumber || "?") + '</span>';
      if (mine && !isPast) {
        const cancel = document.createElement("button");
        cancel.className = "cancel"; cancel.type = "button"; cancel.textContent = "İptal";
        cancel.addEventListener("click", (e) => { e.stopPropagation(); cancelReservation(res); });
        el.querySelector(".pill").after(cancel);
      }
    } else if (isPast) {
      el.classList.add("past");
      el.innerHTML = '<span class="time">' + timeLabel + '</span><span class="state">Saat geçti</span>';
    } else {
      el.classList.add("free");
      if (isSelected) el.classList.add("selected");
      el.innerHTML = '<span class="time">' + timeLabel + '</span>' +
        '<span class="state">' + (isSelected ? "Seçildi" : "Boş — dokun") + '</span>';
      el.addEventListener("click", () => toggleSelect(h));
    }
    wrap.appendChild(el);
  }
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

/* ====================== Seçim mantığı (1–2 ardışık saat) ====================== */
function toggleSelect(h) {
  const sel = state.selection;
  if (sel.includes(h)) {
    state.selection = sel.filter((x) => x !== h);
  } else if (sel.length === 0) {
    state.selection = [h];
  } else if (sel.length === 1 && Math.abs(sel[0] - h) === 1) {
    state.selection = [sel[0], h].sort((a, b) => a - b);
  } else {
    state.selection = [h];
    toast("En fazla 2 yan yana saat seçebilirsin. Yeni seçim başlatıldı.");
  }
  renderSlots(); updateActionbar();
}

function updateActionbar() {
  const n = state.selection.length;
  $("actionbar").hidden = n === 0;
  $("reserve-btn").disabled = n === 0;
  if (n === 0) { $("selection-label").textContent = "Seçim yok"; return; }
  const hrs = state.selection.slice().sort((a, b) => a - b);
  const from = pad(hrs[0]) + ":00";
  const to = pad(hrs[hrs.length - 1] + 1) + ":00";
  $("selection-label").innerHTML = from + " – " + to + ' <small>' + n + ' saat seçildi</small>';
}

$("clear-btn").addEventListener("click", () => { state.selection = []; renderSlots(); updateActionbar(); });
$("reserve-btn").addEventListener("click", reserve);

/* ====================== Rezerve et (atomik transaction) ====================== */
async function reserve() {
  if (!state.selection.length || !db) return;
  const btn = $("reserve-btn"); btn.disabled = true;
  const hrs = state.selection.slice().sort((a, b) => a - b);
  const date = state.selectedDate;

  try {
    await runTransaction(db, async (tx) => {
      const refs = hrs.map((h) => doc(db, "reservations", slotId(date, h)));
      const snaps = [];
      for (const r of refs) snaps.push(await tx.get(r));   // önce tüm okumalar
      for (const s of snaps) if (s.exists()) throw new Error("DOLU");
      hrs.forEach((h, i) => {
        tx.set(refs[i], {
          date: date, hour: h, uid: state.user.uid,
          doorNumber: state.doorNumber, createdAt: serverTimestamp()
        });
      });
    });
    toast("Rezervasyon alındı. İyi oyunlar!");
    state.selection = []; updateActionbar();
  } catch (err) {
    if (err.message === "DOLU") toast("Üzgünüm, seçtiğin saatlerden biri az önce dolduruldu.", true);
    else toast("Rezervasyon yapılamadı: " + (err.message || ""), true);
  }
  btn.disabled = state.selection.length === 0;
}

/* ====================== İptal ====================== */
async function cancelReservation(res) {
  if (!confirm("Bu rezervasyonu iptal etmek istediğine emin misin?")) return;
  try {
    await deleteDoc(doc(db, "reservations", res.id));
    toast("Rezervasyon iptal edildi.");
  } catch (err) {
    toast("İptal edilemedi: " + (err.message || ""), true);
  }
}

/* ====================== Başlangıç ====================== */
setMode("login");

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => navigator.serviceWorker.register("sw.js").catch(() => {}));
}

'@
Yaz "app.js" $f_app_js
$f_config_js = @'
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

'@
Yaz "config.js" $f_config_js
$f_manifest_webmanifest = @'
{
  "name": "Güller Vadisi Tenis Kortu",
  "short_name": "Tenis Kortu",
  "description": "Ben Güller Vadisi Sitesi tenis kortu rezervasyon uygulaması",
  "lang": "tr",
  "start_url": "./",
  "scope": "./",
  "display": "standalone",
  "background_color": "#1f506a",
  "theme_color": "#2e6e8e",
  "icons": [
    {
      "src": "icons/icon-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "icons/icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ]
}
'@
Yaz "manifest.webmanifest" $f_manifest_webmanifest
$f_sw_js = @'
// Basit PWA service worker — uygulama kabuğunu önbelleğe alır.
const CACHE = "gv-tenis-v1";
const ASSETS = [
  "./",
  "./index.html",
  "./styles.css",
  "./app.js",
  "./config.js",
  "./manifest.webmanifest",
  "./icons/icon-192.png",
  "./icons/icon-512.png"
];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const url = new URL(e.request.url);
  // Supabase ve diğer API çağrıları her zaman ağdan gitsin (önbelleğe alma)
  if (url.origin !== self.location.origin) return;
  e.respondWith(
    caches.match(e.request).then((hit) => hit || fetch(e.request))
  );
});

'@
Yaz "sw.js" $f_sw_js
$f_netlify_toml = @'
[build]
  publish = "."

# Tek sayfalık uygulama: bilinmeyen yolları index.html'e yönlendir
[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200

# Service worker'ın güncel kalması için önbelleksiz servis et
[[headers]]
  for = "/sw.js"
  [headers.values]
    Cache-Control = "no-cache"

[[headers]]
  for = "/config.js"
  [headers.values]
    Cache-Control = "no-cache"

'@
Yaz "netlify.toml" $f_netlify_toml
$f_firestore_rules = @'
rules_version = '2';

// =====================================================================
//  GÜLLER VADİSİ — Tenis Kortu Rezervasyon  |  Firestore Güvenlik Kuralları
//  Firebase Console > Firestore Database > Rules sekmesine yapıştır > Publish
// =====================================================================

service cloud.firestore {
  match /databases/{database}/documents {

    function girisli() { return request.auth != null; }

    // --- Profiller (kapı numarası) ---
    // Kişi yalnızca kendi profilini görür ve yazar.
    match /users/{uid} {
      allow read:          if girisli() && request.auth.uid == uid;
      allow create, update: if girisli() && request.auth.uid == uid;
      allow delete:        if false;
    }

    // --- Rezervasyonlar ---
    // Belge kimliği "TARİH_SAAT" biçimindedir (örn. 2026-06-18_10).
    // Bu kimlik benzersiz olduğu için aynı gün+saat ikinci kez OLUŞTURULAMAZ
    // => çakışma engellenir. Üzerine yazma (update) tamamen kapalı.
    match /reservations/{id} {

      // Giriş yapan herkes müsaitliği ve kapı numaralarını görebilir.
      allow read: if girisli();

      // Yalnızca kendi adına, doğru biçimde ve kimlik = TARİH_SAAT olacak şekilde.
      allow create: if girisli()
        && request.resource.data.uid == request.auth.uid
        && request.resource.data.keys().hasOnly(['date', 'hour', 'uid', 'doorNumber', 'createdAt'])
        && request.resource.data.date is string
        && request.resource.data.hour is int
        && request.resource.data.hour >= 0 && request.resource.data.hour <= 23
        && request.resource.data.doorNumber is string
        && id == request.resource.data.date + '_' + string(request.resource.data.hour);

      // Dolu bir saatin üzerine yazmak yasak.
      allow update: if false;

      // Yalnızca rezervasyonu yapan kişi iptal edebilir.
      allow delete: if girisli() && resource.data.uid == request.auth.uid;
    }
  }
}

'@
Yaz "firestore.rules" $f_firestore_rules
$f__gitignore = @'
.DS_Store
Thumbs.db
node_modules/
*.log

'@
Yaz ".gitignore" $f__gitignore
$f_KURULUM_md = @'
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

'@
Yaz "KURULUM.md" $f_KURULUM_md
$b64_icon_192_png = "iVBORw0KGgoAAAANSUhEUgAAAMAAAADACAIAAADdvvtQAAACxUlEQVR4nO3dsY0TQRiAUR+iIzq4GAlnl5AS0AAhASENEJC6AJAIrgn3RIBkIXGA7c/MzIr3QtvameDTP5J3Ld89Ptzv4FrPZm+AbRMQiYBIBEQiIBIBkQiIREAkAiIREImASAREIiASAZEIiERAJAIiERCJgEgERCIgEgGRPL/JVT69/HiT6zDY22/v4hVMIBIBkQiIREAkAiIREImASAREIiASAZEIiERAJAIiERDJbR7nuMiX1y/GL/r/2B+OI5czgUgERDLhCDsZPGyvcDptN7TVwUwgEgGRCIhEQCQCIhEQiYBIZn4PxO98fvX+1xfffP0wfid/JaC1PJnOz2+tlpEjbCF/qOeiz4wkoFWcX8ZSDQloCZc2sU5DAprvuhoWaUhAJAKarAySFYaQgEgERCIgEgGRCIhEQCQCmqzcHF3hxqqASAQ033WDZIXxsxPQIi6tYZF6dgJax/lNrFPPTkBLOaeMperZeaR1NT/68Ew0yZqtPMkRRiIgEgGRCIhEQCQCIhEQiYBIBEQiIBIBkQiIREAkAiIREImASAREIiASAZEIiERAJAIiERCJgEgERDLzl6mz/qn6Chva6mAmEMnMCbQ/HCeufo7T4NnQVgczgUgERCIgEgGRCIhEQCQCIhEQiYBIBEQiIBIBkQiIREAkAiIREImASAREIiASAZEIiERAJAIiERCJgEgERCIgEgGRCIhEQCQCIhEQiYBIBEQiIBIBkQiIREAkAiIREImASAREIiASAZEIiERAJAIiERCJgEgERCIgEgGRCIjE/8afZUNbHcwEIhEQyYQjbH84jl+Uf8QEIhEQiYBIBEQiIBIBkQiIREAkAiIREImASAREIiASAZHcPT7cz94DG2YCkQiIREAkAiIREImASAREIiASAZEIiERAJAIiERCJgEgERCIgEgGRCIhEQCQCIhEQyXcJyEiMviK97wAAAABJRU5ErkJggg=="
[System.IO.File]::WriteAllBytes((Join-Path (Get-Location) (Join-Path $proje "icons\icon-192.png")), [Convert]::FromBase64String($b64_icon_192_png))
Write-Host "    yazildi: icons/icon-192.png"
$b64_icon_512_png = "iVBORw0KGgoAAAANSUhEUgAAAgAAAAIACAIAAAB7GkOtAAAIrklEQVR4nO3dPW5TQRSAUYO8o+yAGol0NGkp2AAlBSUboKDNAoJEwSayJwqQwk+cxInzZt77zqmDuZKl+808x8qLH29f7QDoeTl6AADGEACAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAICo/egBHunL68+jRwC48f77h9EjHM0NACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAovajB1ifq4uz0SMAtzu/vB49wpq4AQBECQBAlAAARAkAQJQAAEQJAECUAABE+R7AyfgF5BU59GUOb+Ja+DrOSbgBAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAET5m8DA43198/HuH3j37dMyk/AIAgAc596lf+iHxWA2AgA81FGr/9A/l4F5CABwvyeu/v9fSgZmIADAXU64+v9/WRkYy28BAQc90/Zf7PW5mwAAt1tmO2vAQB4BAf9aeCl7HDSKGwDwl1FHcleB5QkAcGPsFtaAhQkAQJQAAL/NcACfYYYOAQB2u5k27zyTbJ4AANPt3Nnm2SoBAIgSAKib87g951QbIwAAUQIAaTMftGeebRsEACBKAKBr/iP2/BOumgAARAkAQJQAAEQJAESt5fH6WuZcIwEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAYCod98+jR7hQdYy5xoJAECUAABECQBAlABA1/yP1+efcNUEACBKACBt5iP2zLNtgwAARAkA1M150J5zqo0RAIAoAQCmO27PNs9WCQCw2820c+eZZPMEAPhths07wwwdAgAQJQDAjbEHcMf/hQkA8JdRW9j2X95+9ADAdH7t4q9vPi7537E8NwDgdsvsZdt/IAEADnru7Wz7j+UREHCXZ3ocZPXPQACA+50wA1b/PAQAeKgnZsDqn40AAMf5c4/fGwNLf2YCADye/b5qfgsIIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAogQAIEoAAKIEACBKAACiBAAgSgAAovajB9iOq4uz0SPwVN5EUtwAAKIEACBKAACiBAAgyofAJ3N+eT16BB7q0Ie93sS18HH9SbgBAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARAkAQJQAAEQJAECUAABECQBAlAAARO1HD7AdVxdno0fgqbyJpLgBAEQJAECUAABECQBAlAAARAkAQJQAAET5HsDRzi+vR48AcAJuAABRAgAQJQAAUQIAECUAAFECABAlAABRAgAQJQAAUQIAECUAAFECABAlAABRAgAQJQAAUQIAECUAAFECABAlAABRAgAQJQAAUQIAECUAAFECABAlAABRAgAQJQAAUQIAECUAAFECABAlAABRAgAQJQAAUQIAECUAAFECABAlAABRAgAQJQAAUQIAEPXix9tXo2cAYAA3AIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgCgBAIgSAIAoAQCIEgCAKAEAiBIAgKiflymTHFcVS3cAAAAASUVORK5CYII="
[System.IO.File]::WriteAllBytes((Join-Path (Get-Location) (Join-Path $proje "icons\icon-512.png")), [Convert]::FromBase64String($b64_icon_512_png))
Write-Host "    yazildi: icons/icon-512.png"

Write-Host ""
Write-Host "==> Git deposu hazirlaniyor" -ForegroundColor Green
Push-Location $proje
git init -b main | Out-Null
git add .
git commit -m "Guller Vadisi tenis kortu rezervasyon (Firebase) - ilk surum" | Out-Null

$remote = "https://github.com/$GitHubKullanici/$DepoAdi.git"
if (Get-Command gh -ErrorAction SilentlyContinue) {
  Write-Host "==> GitHub CLI bulundu, depo olusturulup yukleniyor" -ForegroundColor Green
  gh repo create $DepoAdi --public --source=. --remote=origin --push
} else {
  Write-Host "==> GitHub'a baglaniliyor: $remote" -ForegroundColor Green
  git remote remove origin 2>$null
  git remote add origin $remote
  git branch -M main
  Write-Host "    (Once GitHub'da BOS bir '$DepoAdi' deposu actiginizdan emin olun.)" -ForegroundColor Yellow
  git push -u origin main
}
Pop-Location

Write-Host ""
Write-Host "BITTI. Sirada Firebase ayarlari, Netlify ve alan adi var (sohbete bak)." -ForegroundColor Cyan
