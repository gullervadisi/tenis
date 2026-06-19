import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import {
  getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword,
  onAuthStateChanged, signOut, setPersistence, browserLocalPersistence
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
  // Cihazı hatırla: bir kez giriş yapınca tekrar şifre sormaz (çıkış yapana kadar).
  setPersistence(auth, browserLocalPersistence).catch(() => {});
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

/* ====================== Kayıt / Giriş ====================== */
// Cihaz daha önce kullanıldıysa "Giriş", ilk kez ise "Kayıt" öne çıkar.
function setMode(mode) {
  state.mode = mode;
  const isReg = mode === "register";
  $("auth-submit").textContent = isReg ? "Kayıt ol" : "Giriş yap";
  $("auth-switch").textContent = isReg
    ? "Hesabınız var mı? Giriş yapın"
    : "Başka bir kapı numarasıyla kayıt olun";
  $("auth-msg").className = "auth-msg";
  $("auth-msg").textContent = "";
}

$("auth-switch").addEventListener("click", () => {
  setMode(state.mode === "register" ? "login" : "register");
});

$("auth-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  if (!auth) return;
  const doorRaw = $("f-door").value.trim();
  const pin = $("f-password").value.trim();
  const msg = $("auth-msg");
  const btn = $("auth-submit");
  msg.className = "auth-msg";
  msg.textContent = "";

  if (!doorKey(doorRaw)) { msg.classList.add("err"); msg.textContent = "Kapı numaranızı girin (örn. 8B)."; return; }
  if (!/^\d{4}$/.test(pin)) { msg.classList.add("err"); msg.textContent = "Şifreniz 4 haneli rakam olmalıdır."; return; }

  state.enteredDoor = doorDisplay(doorRaw);
  const synem = synthEmail(doorRaw);
  const pw = derivePassword(pin);
  const isReg = state.mode === "register";
  btn.disabled = true;
  btn.textContent = "Lütfen bekleyin…";
  try {
    if (isReg) {
      let cred;
      try {
        cred = await createUserWithEmailAndPassword(auth, synem, pw);
      } catch (e2) {
        if (e2 && e2.code && e2.code.includes("email-already-in-use")) {
          setMode("login");
          msg.classList.add("err");
          msg.textContent = "Bu kapı numarası zaten kayıtlı. Lütfen giriş yapın.";
          return;
        }
        throw e2;
      }
      await setDoc(doc(db, "users", cred.user.uid), {
        doorNumber: doorDisplay(doorRaw), createdAt: serverTimestamp()
      });
      saveCred(doorRaw, pin);
      toast("Hoş geldiniz! Kaydınız oluşturuldu.");
    } else {
      await signInWithEmailAndPassword(auth, synem, pw);
      saveCred(doorRaw, pin);
    }
  } catch (err) {
    msg.classList.add("err");
    msg.textContent = turkceHata(err, isReg);
  } finally {
    btn.disabled = false;
    btn.textContent = state.mode === "register" ? "Kayıt ol" : "Giriş yap";
  }
});

function turkceHata(err, isReg) {
  const c = (err && err.code) ? err.code : "";
  if (c.includes("invalid-credential") || c.includes("wrong-password") || c.includes("user-not-found"))
    return isReg ? "Bilgiler hatalı görünüyor." : "Kapı numaranız veya şifreniz hatalı. Kaydınız yoksa “kayıt olun”.";
  if (c.includes("too-many-requests")) return "Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.";
  if (c.includes("network")) return "İnternet bağlantınız sorunlu görünüyor.";
  return "Bir sorun oluştu: " + (err.message || "bilinmeyen hata");
}

function saveCred(door, pin) {
  try { localStorage.setItem("gv_cred", JSON.stringify({ door: door, pin: pin })); } catch (e) { /* yoksay */ }
}

$("signout-btn").addEventListener("click", () => {
  try { localStorage.removeItem("gv_cred"); } catch (e) { /* yoksay */ }
  autoTried = true; // çıkıştan sonra otomatik giriş denenmesin
  if (auth) signOut(auth);
});

/* ====================== Oturum dinleyici ====================== */
let autoTried = false;

// Firebase oturumu silinmişse (özellikle iPhone'da olabilir) cihazda
// kayıtlı bilgiyle sessizce tekrar giriş dener.
async function tryAutoLogin() {
  let saved = null;
  try { saved = JSON.parse(localStorage.getItem("gv_cred") || "null"); } catch (e) { saved = null; }
  if (!saved || !saved.door || !saved.pin) return false;
  try {
    state.enteredDoor = doorDisplay(saved.door);
    await signInWithEmailAndPassword(auth, synthEmail(saved.door), derivePassword(saved.pin));
    return true; // onAuthStateChanged yeniden, kullanıcıyla tetiklenecek
  } catch (e) {
    try { localStorage.removeItem("gv_cred"); } catch (_) { /* yoksay */ }
    return false;
  }
}

if (auth) {
  onAuthStateChanged(auth, async (user) => {
    if (user) { state.user = user; await afterLogin(); return; }
    state.user = null;
    if (unsub) { unsub(); unsub = null; }
    if (!autoTried) {
      autoTried = true;
      const ok = await tryAutoLogin();
      if (ok) return; // giriş başarılı; ekranı dinleyici tekrar çizecek
    }
    showAuth();
  });
}

async function afterLogin() {
  try { localStorage.setItem("gv_seen", "1"); } catch (e) { /* yoksay */ }
  let door = state.enteredDoor || "?";
  try {
    const snap = await getDoc(doc(db, "users", state.user.uid));
    if (snap.exists() && snap.data().doorNumber) door = snap.data().doorNumber;
  } catch (e) { /* yoksay */ }
  state.doorNumber = door;
  $("door-badge").textContent = "Kapı " + door;

  showBoard();
  window.scrollTo(0, 0);
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
  $("f-door").value = "";
  $("f-password").value = "";
  try {
    setMode(localStorage.getItem("gv_seen") === "1" ? "login" : "register");
  } catch (e) { setMode("login"); }
  window.scrollTo(0, 0);
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

/* ====================== Seçim mantığı (1–3 ardışık saat) ====================== */
function toggleSelect(h) {
  const sel = state.selection;
  if (sel.includes(h)) {
    // Yalnız uçtaki saat kaldırılır; ortadakine basılırsa o saatten yeniden başlar
    if (h === sel[0] || h === sel[sel.length - 1]) {
      state.selection = sel.filter((x) => x !== h);
    } else {
      state.selection = [h];
    }
  } else if (sel.length === 0) {
    state.selection = [h];
  } else {
    const min = sel[0], max = sel[sel.length - 1];
    const bitisik = (h === min - 1 || h === max + 1);
    if (bitisik && sel.length < 3) {
      state.selection = [...sel, h].sort((a, b) => a - b);
    } else if (bitisik) {
      state.selection = [h];
      toast("En fazla 3 yan yana saat seçebilirsiniz. Yeni seçim başlatıldı.");
    } else {
      state.selection = [h]; // bitişik değil → yeni seçim başlat
    }
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

  // Günlük sınır: bir kişi aynı günde en fazla 3 saat tutabilir.
  const myHoursToday = Array.from(state.reservations.values())
    .filter((r) => r.date === date && r.uid === state.user.uid).length;
  if (myHoursToday + hrs.length > 3) {
    toast("Aynı gün en fazla 3 saat rezerve edebilirsiniz" +
      (myHoursToday ? " (bugün zaten " + myHoursToday + " saatiniz var)." : "."), true);
    btn.disabled = state.selection.length === 0;
    return;
  }

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
    if (err.message === "DOLU") toast("Üzgünüz, seçtiğiniz saatlerden biri az önce dolduruldu.", true);
    else toast("Rezervasyon yapılamadı: " + (err.message || ""), true);
  }
  btn.disabled = state.selection.length === 0;
}

/* ====================== İptal ====================== */
async function cancelReservation(res) {
  if (!confirm("Bu rezervasyonu iptal etmek istediğinize emin misiniz?")) return;
  try {
    await deleteDoc(doc(db, "reservations", res.id));
    toast("Rezervasyon iptal edildi.");
  } catch (err) {
    toast("İptal edilemedi: " + (err.message || ""), true);
  }
}

/* ====================== Başlangıç ====================== */
// Cihaz daha önce kullanıldıysa Giriş, ilk kez ise Kayıt modunu öne çıkar.
try {
  setMode(localStorage.getItem("gv_seen") === "1" ? "login" : "register");
} catch (e) { setMode("register"); }

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => navigator.serviceWorker.register("sw.js").catch(() => {}));
}
