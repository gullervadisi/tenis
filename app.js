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
const OPEN = CFG.ACILIS_SAATI;
const CLOSE = CFG.KAPANIS_SAATI;
const DAYS = CFG.GUN_SAYISI;

// Giriş kapı numarası + 4 haneli PIN ile yapılır.
// Kapı numarasından Firebase için sentetik bir e-posta üretiriz; PIN'i de
// Firebase'in 6 karakter şartını sağlamak için sabit bir ekle tamamlarız.
const PIN_SUFFIX = "gv7t";
const SYNTH_DOMAIN = "guller-vadisi-tenis.web.app";

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
  enteredDoor: null,
  selectedDate: null,
  dates: [],
  reservations: new Map(),
  selection: [],
  mode: "login",
};
let unsub = null;

/* ====================== Yardımcılar ====================== */
const $ = (id) => document.getElementById(id);
const pad = (n) => String(n).padStart(2, "0");
const DOW = ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"];
const DOW_LONG = ["Pazar", "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi"];
const MONTHS = ["Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"];

function fmtDate(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
function parseDate(s) { const p = s.split("-").map(Number); return new Date(p[0], p[1] - 1, p[2]); }
function slotId(date, hour) { return date + "_" + hour; }

function doorKey(d) { return String(d).trim().toLowerCase().replace(/[^a-z0-9]/g, ""); }
function doorDisplay(d) { return String(d).trim().toUpperCase(); }
function synthEmail(d) { return "kapi." + doorKey(d) + "@" + SYNTH_DOMAIN; }
function derivePassword(pin) { return String(pin) + PIN_SUFFIX; }

function toast(msg, isErr) {
  const t = $("toast");
  t.textContent = msg;
  t.className = "toast" + (isErr ? " err" : "");
  t.hidden = false;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => { t.hidden = true; }, 3600);
}

/* ====================== Giriş / Kayıt ekranı ====================== */
function setMode(mode) {
  state.mode = mode;
  const isReg = mode === "register";
  $("tab-login").classList.toggle("is-active", !isReg);
  $("tab-register").classList.toggle("is-active", isReg);
  $("email-field").hidden = !isReg;        // e-posta yalnızca kayıtta
  $("f-email").required = isReg;
  $("login-foot").hidden = isReg;          // "şifreni unuttuysan" yalnızca girişte
  $("auth-submit").textContent = isReg ? "Kayıt ol" : "Giriş yap";
  $("auth-msg").textContent = "";
}

$("tab-login").addEventListener("click", () => setMode("login"));
$("tab-register").addEventListener("click", () => setMode("register"));

$("auth-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  if (!auth) return;
  const email = $("f-email").value.trim();
  const doorRaw = $("f-door").value.trim();
  const pin = $("f-password").value.trim();
  const msg = $("auth-msg");
  const btn = $("auth-submit");
  msg.className = "auth-msg";
  msg.textContent = "";

  if (!doorKey(doorRaw)) { msg.classList.add("err"); msg.textContent = "Kapı numaranı gir (örn. 8B)."; return; }
  if (!/^\d{4}$/.test(pin)) { msg.classList.add("err"); msg.textContent = "Şifre 4 haneli rakam olmalı."; return; }
  if (state.mode === "register" && (!email || !email.includes("@"))) {
    msg.classList.add("err"); msg.textContent = "Geçerli bir e-posta gir."; return;
  }

  state.enteredDoor = doorDisplay(doorRaw);
  btn.disabled = true;
  btn.textContent = "Lütfen bekle…";
  try {
    if (state.mode === "register") {
      const cred = await createUserWithEmailAndPassword(auth, synthEmail(doorRaw), derivePassword(pin));
      await setDoc(doc(db, "users", cred.user.uid), {
        email: email, doorNumber: doorDisplay(doorRaw), createdAt: serverTimestamp()
      });
      toast("Hesap başarıyla oluşturuldu. Hoş geldin!");
      // (İstenirse buraya hoş geldin e-postası gönderimi -EmailJS- eklenebilir.)
    } else {
      await signInWithEmailAndPassword(auth, synthEmail(doorRaw), derivePassword(pin));
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
  if (c.includes("email-already-in-use")) return "Bu kapı numarası zaten kayıtlı. Giriş yap sekmesini kullan.";
  if (c.includes("invalid-credential") || c.includes("wrong-password") || c.includes("user-not-found"))
    return "Kapı numarası veya şifre hatalı.";
  if (c.includes("too-many-requests")) return "Çok fazla deneme. Biraz sonra tekrar dene.";
  if (c.includes("network")) return "İnternet bağlantısı sorunlu görünüyor.";
  return "Bir sorun oldu: " + (err.message || "bilinmeyen hata");
}

$("signout-btn").addEventListener("click", () => { if (auth) signOut(auth); });

/* ====================== Oturum dinleyici ====================== */
if (auth) {
  onAuthStateChanged(auth, async (user) => {
    if (user) { state.user = user; await afterLogin(); }
    else { state.user = null; if (unsub) { unsub(); unsub = null; } showAuth(); }
  });
}

async function afterLogin() {
  $("brand-eyebrow").textContent = (CFG.SITE_ADI || "GÜLLER VADİSİ").toUpperCase();
  $("brand-title").textContent = CFG.KORT_ADI || "Tenis Kortu";

  let door = state.enteredDoor || "?";
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
      state.selectedDate = ds; state.selection = [];
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
      for (const r of refs) snaps.push(await tx.get(r));
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
