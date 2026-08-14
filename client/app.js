const THEME_KEY = "wakeedApiApp.theme";
const WP = () => window.WakeedPlatform;
const API = () => window.WakeedApi;

let serverLedgerCache = [];
let saveLocalTimer = null;

const els = {
  loginScreen: document.getElementById("loginScreen"),
  appScreen: document.getElementById("appScreen"),
  server: document.getElementById("server"),
  buildNumber: document.getElementById("buildNumber"),
  ownerKey: document.getElementById("ownerKey"),
  ownerUrl: document.getElementById("ownerUrl"),
  token: document.getElementById("token"),
  username: document.getElementById("username"),
  password: document.getElementById("password"),
  loginBtn: document.getElementById("loginBtn"),
  logoutBtn: document.getElementById("logoutBtn"),
  subscription: document.getElementById("subscription"),
  connBadge: document.getElementById("connBadge"),
  connStatus: document.getElementById("connStatus"),
  entryDate: document.getElementById("entryDate"),
  journalType: document.getElementById("journalType"),
  costCenter: document.getElementById("costCenter"),
  debitAccount: document.getElementById("debitAccount"),
  debitAccountBtn: document.getElementById("debitAccountBtn"),
  debitAccountLabel: document.getElementById("debitAccountLabel"),
  debitAccountSearch: document.getElementById("debitAccountSearch"),
  saveDebitDefault: document.getElementById("saveDebitDefault"),
  debitDefaultHint: document.getElementById("debitDefaultHint"),
  accountModal: document.getElementById("accountModal"),
  accountModalBackdrop: document.getElementById("accountModalBackdrop"),
  accountModalClose: document.getElementById("accountModalClose"),
  accountModalList: document.getElementById("accountModalList"),
  accountModalMeta: document.getElementById("accountModalMeta"),
  notes: document.getElementById("notes"),
  notesPreview: document.getElementById("notesPreview"),
  notesEach: document.getElementById("notesEach"),
  notesPreviewEach: document.getElementById("notesPreviewEach"),
  data: document.getElementById("data"),
  copyTemplate: document.getElementById("copyTemplate"),
  previewBtn: document.getElementById("previewBtn"),
  submitBtn: document.getElementById("submitBtn"),
  useOpposite: document.getElementById("useOpposite"),
  includeCostCenter: document.getElementById("includeCostCenter"),
  status: document.getElementById("status"),
  submitModal: document.getElementById("submitModal"),
  submitModalBackdrop: document.getElementById("submitModalBackdrop"),
  submitModalIcon: document.getElementById("submitModalIcon"),
  submitModalTitle: document.getElementById("submitModalTitle"),
  submitModalMessage: document.getElementById("submitModalMessage"),
  submitModalDetails: document.getElementById("submitModalDetails"),
  submitModalClose: document.getElementById("submitModalClose"),
  submitModalMinimize: document.getElementById("submitModalMinimize"),
  submitModalDock: document.getElementById("submitModalDock"),
  submitModalDockIcon: document.getElementById("submitModalDockIcon"),
  submitModalDockTitle: document.getElementById("submitModalDockTitle"),
  submitModalDockMessage: document.getElementById("submitModalDockMessage"),
  previewBody: document.getElementById("previewBody"),
  countCustomers: document.getElementById("countCustomers"),
  countLines: document.getElementById("countLines"),
  sumDebit: document.getElementById("sumDebit"),
  sumCredit: document.getElementById("sumCredit"),
  dataEach: document.getElementById("dataEach"),
  copyTemplateEach: document.getElementById("copyTemplateEach"),
  previewBtnEach: document.getElementById("previewBtnEach"),
  submitBtnEach: document.getElementById("submitBtnEach"),
  previewBodyEach: document.getElementById("previewBodyEach"),
  countVouchersEach: document.getElementById("countVouchersEach"),
  countCustomersEach: document.getElementById("countCustomersEach"),
  sumDebitEach: document.getElementById("sumDebitEach"),
  sumCreditEach: document.getElementById("sumCreditEach"),
  panelManual: document.getElementById("panelManual"),
  notesManual: null,
  notesPreviewManual: null,
  manualEntriesList: document.getElementById("manualEntriesList"),
  manualEntryCount: document.getElementById("manualEntryCount"),
  addManualEntryBtn: document.getElementById("addManualEntryBtn"),
  previewBtnManual: document.getElementById("previewBtnManual"),
  submitBtnManual: document.getElementById("submitBtnManual"),
  countVouchersManual: document.getElementById("countVouchersManual"),
  sumDebitManual: document.getElementById("sumDebitManual"),
  sumCreditManual: document.getElementById("sumCreditManual"),
  previewBodyManual: document.getElementById("previewBodyManual"),
  submitModeModal: document.getElementById("submitModeModal"),
  submitModeBackdrop: document.getElementById("submitModeBackdrop"),
  submitModeSummary: document.getElementById("submitModeSummary"),
  submitModeBatch: document.getElementById("submitModeBatch"),
  submitModeEach: document.getElementById("submitModeEach"),
  submitModeCancel: document.getElementById("submitModeCancel"),
  accountModalTitle: document.getElementById("accountModalTitle"),
  createView: document.getElementById("createView"),
  ledgerView: document.getElementById("ledgerView"),
  ledgerCountBadge: document.getElementById("ledgerCountBadge"),
  ledgerSearch: document.getElementById("ledgerSearch"),
  ledgerFrom: document.getElementById("ledgerFrom"),
  ledgerTo: document.getElementById("ledgerTo"),
  ledgerKind: document.getElementById("ledgerKind"),
  ledgerSheetsBtn: document.getElementById("ledgerSheetsBtn"),
  ledgerFileBtn: document.getElementById("ledgerFileBtn"),
  ledgerClearFilters: document.getElementById("ledgerClearFilters"),
  ledgerBody: document.getElementById("ledgerBody"),
  ledgerVoucherCount: document.getElementById("ledgerVoucherCount"),
  ledgerNameCount: document.getElementById("ledgerNameCount"),
  ledgerSum: document.getElementById("ledgerSum"),
  themeToggle: document.getElementById("themeToggle"),
  loginThemeToggle: document.getElementById("loginThemeToggle"),
  mobileNav: document.getElementById("mobileNav"),
  createSideNav: document.getElementById("createSideNav"),
};

const navState = { view: "create", tab: "batch" };

const JOURNAL_PARALLEL = 2;

const submitJob = {
  active: false,
  collapsed: false,
  phase: "loading",
  title: "",
  message: "",
  details: "",
};

const state = {
  connected: false,
  journalTypes: [],
  costCenters: [],
  currency: null,
  sampleDetail: null,
  sampleEntry: null,
  accounts: [],
  debitDefaults: {},
  pendingDebitCode: "",
  journalPostPath: "",
  accountCache: new Map(),
  manualEntries: [],
  accountPickTarget: "debit",
  userDisplayName: "",
  subscriptions: [],
};

function todayInputValue() {
  const d = new Date();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${m}-${day}`;
}

function setStatus(msg, type = "") {
  if (!els.status || els.status.hidden) return;
  els.status.textContent = msg;
  els.status.className = "status" + (type ? " " + type : "");
}

function setConnStatus(msg, type = "") {
  if (!els.connStatus) return;
  els.connStatus.textContent = msg;
  els.connStatus.className = "status-line" + (type ? " " + type : "");
}

function logLine(_msg) {}

function manualEntryId() {
  return `m-${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
}

function ensureManualEntries() {
  if (!state.manualEntries?.length) {
    state.manualEntries = [{ id: manualEntryId(), name: "", amount: "", credit: "", note: "" }];
  }
}

function syncCreateButtons() {
  const busy = submitJob.active;
  const hint = busy ? "التسجيل قيد التنفيذ — انتظر أو اضغط شريط التقدّم للعودة" : "";
  for (const btn of [els.submitBtn, els.submitBtnEach, els.submitBtnManual]) {
    if (!btn) continue;
    btn.disabled = busy;
    btn.title = hint;
  }
}

function beginSubmitJob() {
  submitJob.active = true;
  submitJob.collapsed = false;
  syncCreateButtons();
}

function finishSubmitJob() {
  submitJob.active = false;
  syncCreateButtons();
}

function guardSubmitJob() {
  if (!submitJob.active) return true;
  expandSubmitModal();
  return false;
}

function updateSubmitModalContent({ phase, title, message, details = "" }) {
  if (els.submitModalIcon) {
    els.submitModalIcon.className = "submit-modal-icon " + (phase || "loading");
  }
  if (els.submitModalTitle) els.submitModalTitle.textContent = title || "";
  if (els.submitModalMessage) els.submitModalMessage.textContent = message || "";
  if (els.submitModalDetails) els.submitModalDetails.textContent = details || "";
  if (els.submitModalClose) {
    els.submitModalClose.hidden = phase === "loading";
  }
  if (els.submitModalMinimize) {
    els.submitModalMinimize.hidden = phase !== "loading" || !submitJob.active;
  }
}

function renderSubmitDock() {
  if (!els.submitModalDock) return;
  const phase = submitJob.phase || "loading";
  if (els.submitModalDockIcon) {
    els.submitModalDockIcon.className = "submit-dock-icon " + phase;
  }
  if (els.submitModalDockTitle) {
    els.submitModalDockTitle.textContent = submitJob.title || "جارٍ التسجيل...";
  }
  if (els.submitModalDockMessage) {
    const line = String(submitJob.message || "").split("\n").find(Boolean) || "";
    els.submitModalDockMessage.textContent = line;
    els.submitModalDockMessage.hidden = !line;
  }
  els.submitModalDock.classList.toggle("done", phase === "success" || phase === "error");
}

function showSubmitModalExpanded() {
  submitJob.collapsed = false;
  if (els.submitModal) els.submitModal.hidden = false;
  if (els.submitModalDock) els.submitModalDock.hidden = true;
}

function showSubmitDock() {
  if (!submitJob.active) return;
  submitJob.collapsed = true;
  if (els.submitModal) els.submitModal.hidden = true;
  if (els.submitModalDock) {
    renderSubmitDock();
    els.submitModalDock.hidden = false;
  }
}

function collapseSubmitModal() {
  if (!submitJob.active || submitJob.phase !== "loading") return;
  showSubmitDock();
}

function expandSubmitModal() {
  if (!submitJob.active && els.submitModal?.hidden && els.submitModalDock?.hidden) return;
  showSubmitModalExpanded();
  updateSubmitModalContent({
    phase: submitJob.phase,
    title: submitJob.title,
    message: submitJob.message,
    details: submitJob.details,
  });
}

function openSubmitModal({ phase, title, message, details = "", job = false }) {
  if (submitJob.active && !job) return;
  if (!els.submitModal) return;

  updateSubmitModalContent({ phase, title, message, details });

  if (job) {
    submitJob.phase = phase;
    submitJob.title = title || "";
    submitJob.message = message || "";
    submitJob.details = details || "";
  }

  if (job && phase !== "loading" && submitJob.collapsed) {
    submitJob.collapsed = false;
    showSubmitModalExpanded();
    return;
  }

  if (job && submitJob.collapsed && phase === "loading") {
    renderSubmitDock();
    return;
  }

  showSubmitModalExpanded();
}

function closeSubmitModal() {
  if (submitJob.active) return;
  if (els.submitModal) els.submitModal.hidden = true;
  if (els.submitModalDock) els.submitModalDock.hidden = true;
  submitJob.collapsed = false;
}

function showSubmitError(title, message, details = "", job = false) {
  openSubmitModal({ phase: "error", title, message, details, job });
}

function showSubmitSuccess(title, message, details = "", job = false) {
  openSubmitModal({ phase: "success", title, message, details, job });
}

function setConnected(ok, label) {
  state.connected = ok;
  els.connBadge.className = "badge" + (ok ? " ok" : label && !ok ? " err" : "");
  els.connBadge.textContent = label || (ok ? "متصل" : "غير متصل");
}

function extractOwnerKey(raw) {
  const text = String(raw || "").trim();
  if (!text) return "";
  const hash = text.includes("#") ? text.split("#").pop() : text;
  const segment = hash.replace(/^\/+/, "").split(/[/?]/).filter(Boolean)[0] || "";
  if (/^owner[_-][a-z0-9]+$/i.test(segment)) return segment;
  if (/^owner[_-][a-z0-9]+$/i.test(text) && !/[\/#]/.test(text)) return text;
  return text.replace(/^#\/?/, "");
}

function ownerKeyVariants(raw) {
  const key = extractOwnerKey(raw);
  if (!key) return [];
  const variants = [key];
  if (/^owner_/i.test(key)) variants.push(key.replace(/^owner_/i, ""));
  else variants.push(`owner_${key}`);
  return [...new Set(variants.filter(Boolean))];
}

function applyOwnerFromUrl() {
  const key = extractOwnerKey(els.ownerUrl.value);
  if (key && key !== els.ownerUrl.value.trim()) {
    els.ownerKey.value = key;
  } else if (key && !els.ownerUrl.value.includes("://") && key === els.ownerUrl.value.trim()) {
    els.ownerKey.value = key;
  } else if (key) {
    els.ownerKey.value = key;
  }
}

function decodeJwtExp(token) {
  try {
    const payload = JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    if (!payload.exp) return "";
    return new Date(payload.exp * 1000).toLocaleString("ar-EG");
  } catch (_) {
    return "";
  }
}

function showLogin() {
  if (els.loginScreen) {
    els.loginScreen.hidden = false;
    els.loginScreen.removeAttribute("hidden");
  }
  if (els.appScreen) {
    els.appScreen.hidden = true;
    els.appScreen.setAttribute("hidden", "");
  }
}

function showApp() {
  if (els.loginScreen) {
    els.loginScreen.hidden = true;
    els.loginScreen.setAttribute("hidden", "");
  }
  if (els.appScreen) {
    els.appScreen.hidden = false;
    els.appScreen.removeAttribute("hidden");
  }
  updateLedgerBadge();
}

function applyTheme(theme) {
  const next = theme === "light" ? "light" : "dark";
  document.documentElement.setAttribute("data-theme", next);
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute("content", next === "light" ? "#eef1f6" : "#0b0f14");
  const icon = next === "light" ? "☀" : "◐";
  if (els.themeToggle) els.themeToggle.textContent = icon;
  if (els.loginThemeToggle) els.loginThemeToggle.textContent = icon;
  try {
    localStorage.setItem(THEME_KEY, next);
  } catch (_) {}
}

function initTheme() {
  try {
    applyTheme(localStorage.getItem(THEME_KEY) || "dark");
  } catch (_) {
    applyTheme("dark");
  }
}

function toggleTheme() {
  const current = document.documentElement.getAttribute("data-theme") === "light" ? "light" : "dark";
  applyTheme(current === "light" ? "dark" : "light");
}

function syncMobileNav() {
  if (!els.mobileNav) return;
  const value = navState.view === "ledger" ? "ledger" : `create-${navState.tab}`;
  if (els.mobileNav.value !== value) els.mobileNav.value = value;
}

function handleMobileNavChange(value) {
  if (value === "ledger") {
    setView("ledger");
    return;
  }
  const tab = String(value || "").replace(/^create-/, "") || "batch";
  setView("create");
  setTab(tab);
}

function setTab(tab) {
  navState.tab = tab;
  document.querySelectorAll(".create-tabs .tab").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.tab === tab);
  });
  if (els.panelBatch || document.getElementById("panelBatch")) {
    document.getElementById("panelBatch").hidden = tab !== "batch";
    document.getElementById("panelEach").hidden = tab !== "each";
    if (els.panelManual) els.panelManual.hidden = tab !== "manual";
  }
  syncMobileNav();
}

function setView(view) {
  navState.view = view;
  document.querySelectorAll(".view-tabs .tab").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.view === view);
  });
  if (els.createView) els.createView.hidden = view !== "create";
  if (els.ledgerView) els.ledgerView.hidden = view !== "ledger";
  if (els.createSideNav) els.createSideNav.hidden = view !== "create";
  if (view === "ledger") renderLedger();
  syncMobileNav();
}

function pickUserDisplayName(user) {
  if (!user || typeof user !== "object") return "";
  const first = String(user.first_name || user.firstName || "").trim();
  const last = String(user.last_name || user.lastName || "").trim();
  const combined = [first, last].filter(Boolean).join(" ").trim();
  const candidates = [
    user.full_name,
    user.fullName,
    user.name,
    user.Name,
    combined,
    user.displayName,
    user.DisplayName,
    user.email,
    user.username,
  ];
  for (const value of candidates) {
    const text = String(value || "").trim();
    if (text) return text;
  }
  return "";
}

function subscriptionLabel(sub) {
  const name = String(sub?.name || "").trim();
  if (name && name !== sub?.ownerKey && !/^owner[_-]/i.test(name)) return name;
  if (WP().platformState.userDisplayName) return WP().platformState.userDisplayName;
  return "حساب وكيد";
}

function currentCompanyName() {
  const key = String(els.subscription?.value || els.ownerKey?.value || "").trim();
  const subs = WP().platformState.subscriptions || [];
  const sub = subs.find((item) => item.ownerKey === key);
  if (sub) return subscriptionLabel(sub);
  const selected = els.subscription?.selectedOptions?.[0];
  const text = String(selected?.textContent || "").trim();
  if (text && !/^owner[_-]/i.test(text)) return text;
  return "";
}

function hasActiveSession() {
  return Boolean(String(els.token?.value || "").trim() && credentials().ownerKey);
}

function syncSessionBadge(currencyName = "") {
  if (!state.connected && !hasActiveSession()) return;
  const user = String(WP().platformState.userDisplayName || "").trim();
  const company = currentCompanyName();
  const display = user || (company && company !== "حساب وكيد" ? company : "");
  let label = "متصل";
  if (display) label += ` · ${display}`;
  else if (currencyName) label += ` · ${currencyName}`;
  setConnected(true, label);
}

function applySessionIdentity(data = {}) {
  const user = data.user || null;
  const name =
    String(data.userDisplayName || "").trim() ||
    pickUserDisplayName(user) ||
    String(els.username?.value || "").trim();
  if (name) {
    state.userDisplayName = name;
    WP().platformState.userDisplayName = name;
  }
  if (Array.isArray(data.subscriptions) && data.subscriptions.length) {
    state.subscriptions = data.subscriptions;
    WP().platformState.subscriptions = data.subscriptions;
  }
}

function pickSubscriptionNameClient(item) {
  const nested = item?.subscription || item?.Subscription || item?.account || item?.Account || null;
  const candidates = [
    item?.companyName,
    item?.CompanyName,
    item?.businessName,
    item?.BusinessName,
    item?.accountName,
    item?.AccountName,
    item?.displayName,
    item?.DisplayName,
    item?.name,
    item?.Name,
    item?.full_name,
    item?.fullName,
    nested?.companyName,
    nested?.CompanyName,
    nested?.name,
    nested?.Name,
    nested?.displayName,
    nested?.DisplayName,
  ];
  for (const value of candidates) {
    const text = String(value || "").trim();
    if (text && !/^owner[_-]/i.test(text)) return text;
  }
  return "";
}

function mapSubscriptions(list) {
  return (list || [])
    .map((item) => {
      const ownerKey = normalizeAccountKey(
        item.ownerKey || item.OwnerKey || item.owner_key || item.id || ""
      );
      const rawName = String(item.name || item.Name || "").trim() || pickSubscriptionNameClient(item);
      const name =
        rawName && rawName !== ownerKey && !/^owner[_-]/i.test(rawName) ? rawName : "";
      return { id: item.id || item.Id || "", name, ownerKey };
    })
    .filter((item) => item.ownerKey);
}

async function refreshSessionIdentity() {
  if (!els.token.value || !credentials().ownerKey) return;
  try {
    const [profile, subsRaw] = await Promise.all([
      api("GET", "/user-api/my-profile").catch(() => null),
      api("GET", "/user-api/my-subscriptions").catch(() => null),
    ]);
    const user = profile?.data || profile?.user || profile || null;
    const name = pickUserDisplayName(user);
    if (name) {
      state.userDisplayName = name;
      WP().platformState.userDisplayName = name;
    }
    const subs = mapSubscriptions(asList(subsRaw));
    if (subs.length) {
      state.subscriptions = subs;
      WP().platformState.subscriptions = subs;
      fillSubscriptions(subs, els.subscription?.value || els.ownerKey?.value);
    }
    saveLocal();
    syncSessionBadge();
  } catch (_) {}
}

function scheduleSaveLocal() {
  if (saveLocalTimer) clearTimeout(saveLocalTimer);
  saveLocalTimer = setTimeout(function () {
    saveLocal().catch(function () {});
  }, 400);
}

async function saveLocal() {
  if (!WP().platformState.sessionToken) return;
  const settings = {
    ownerKey: els.ownerKey.value,
    username: els.username?.value || "",
    debitAccount: els.debitAccount.value,
    debitDefaults: state.debitDefaults || {},
    notes: els.notes?.value || "",
    notesEach: els.notesEach?.value || "",
    table: els.data.value,
    tableEach: els.dataEach?.value || "",
    manualEntries: state.manualEntries || [],
    userDisplayName: WP().platformState.userDisplayName || "",
    subscriptions: WP().platformState.subscriptions || [],
  };
  await API().syncSaveSettings(settings, document.documentElement.getAttribute("data-theme") || "dark");
  await API().syncSaveWakeed({
    ownerKey: els.ownerKey.value,
    username: els.username?.value || "",
    server: els.server?.value || WP().platformState.server,
    buildNumber: els.buildNumber?.value || WP().platformState.buildNumber,
    userDisplayName: WP().platformState.userDisplayName,
    subscriptions: WP().platformState.subscriptions,
  });
}

async function loadLocal() {
  if (!WP().platformState.sessionToken) return;
  try {
    const data = await API().syncLoadAll();
    const settings = data.settings || {};
    if (settings.server && els.server) els.server.value = settings.server;
    if (settings.buildNumber && els.buildNumber) els.buildNumber.value = settings.buildNumber;
    if (settings.ownerKey) els.ownerKey.value = settings.ownerKey;
    if (settings.username && els.username) els.username.value = settings.username;
    if (settings.debitDefaults && typeof settings.debitDefaults === "object") {
      state.debitDefaults = settings.debitDefaults;
    }
    if (settings.debitAccount) state.pendingDebitCode = settings.debitAccount;
    if (settings.notes && els.notes) els.notes.value = settings.notes;
    if (settings.notesEach && els.notesEach) els.notesEach.value = settings.notesEach;
    if (settings.userDisplayName) WP().platformState.userDisplayName = settings.userDisplayName;
    if (Array.isArray(settings.subscriptions)) WP().platformState.subscriptions = settings.subscriptions;
    if (Array.isArray(settings.manualEntries) && settings.manualEntries.length) {
      state.manualEntries = settings.manualEntries.map(function (entry) {
        return {
          id: entry.id || manualEntryId(),
          name: entry.name || "",
          amount: entry.amount || "",
          credit: entry.credit || "",
          note: entry.note || "",
        };
      });
    }
    if (settings.table) els.data.value = settings.table;
    if (settings.tableEach && els.dataEach) els.dataEach.value = settings.tableEach;
    if (WP().platformState.server && els.server) els.server.value = WP().platformState.server;
    if (WP().platformState.buildNumber && els.buildNumber) els.buildNumber.value = WP().platformState.buildNumber;
    if (WP().platformState.ownerKey && !els.ownerKey.value) els.ownerKey.value = WP().platformState.ownerKey;
    if (WP().platformState.subscriptions.length && els.subscription) {
      fillSubscriptions(WP().platformState.subscriptions, settings.ownerKey || WP().platformState.ownerKey);
    }
    if (data.theme) applyTheme(data.theme);
    serverLedgerCache = data.ledger || [];
    if (WP().platformState.wakeedToken) els.token.value = "server-held";
  } catch (_) {}
}

function credentials() {
  const fromSub = els.subscription?.value || "";
  return {
    server: (els.server?.value || WP().platformState.server || "server1.wakeed.app").trim(),
    token: WP().platformState.wakeedToken ? "server-held" : "",
    ownerKey: ownerKeyVariants(fromSub || els.ownerKey.value)[0] || "",
    buildNumber: String(els.buildNumber?.value || WP().platformState.buildNumber || "3996").trim() || "3996",
  };
}

function formatApiError(payload) {
  const data = payload?.data !== undefined ? payload.data : payload;
  if (!data) return payload?.error || `HTTP ${payload?.status || "?"}`;
  if (typeof data === "string") return data;
  if (data.Message) return data.Message;
  if (data.message) return data.message;
  if (data.errors) {
    const parts = Object.entries(data.errors).map(([k, v]) => `${k}: ${(Array.isArray(v) ? v : [v]).join("، ")}`);
    return parts.join(" | ") || data.message || data.Message || "خطأ في التحقق";
  }
  if (data.title && data.errors) {
    const parts = Object.entries(data.errors).map(([k, v]) => `${k}: ${(Array.isArray(v) ? v : [v]).join("، ")}`);
    return `${data.title} — ${parts.join(" | ")}`;
  }
  if (data.title) return data.title;
  if (data.error) return data.error;
  try {
    return JSON.stringify(data).slice(0, 500);
  } catch (_) {
    return String(data);
  }
}

function splitPath(path) {
  const raw = String(path || "");
  const qIndex = raw.indexOf("?");
  if (qIndex < 0) return { path: raw, query: {} };
  const query = {};
  new URLSearchParams(raw.slice(qIndex + 1)).forEach((value, key) => {
    query[key] = value;
  });
  return { path: raw.slice(0, qIndex), query };
}

async function api(method, path, body, options = {}) {
  return API().wakeedProxy(method, path, body, options);
}

function pickAccountCode(acc) {
  return String(acc?.AccountCode || acc?.accountCode || acc?.Code || acc?.code || "").trim();
}

function accountLabel(acc) {
  const code = pickAccountCode(acc);
  const name = acc?.AccountName || acc?.accountName || acc?.Name || acc?.name || "";
  return `${code}${name ? " — " + name : ""}`;
}

function isPostableAccount(acc) {
  if (!acc || !pickAccountCode(acc)) return false;
  const children = acc.Children || acc.children;
  if (Array.isArray(children) && children.length) return false;
  if (acc.IsParent === true || acc.isParent === true) return false;
  if (acc.HasChildren === true || acc.hasChildren === true) return false;
  if (acc.IsLeaf === false || acc.isLeaf === false) return false;
  return true;
}

function flattenAccounts(nodes, out = []) {
  for (const node of nodes || []) {
    const children = node.Children || node.children || [];
    if (isPostableAccount(node)) out.push(node);
    if (children.length) flattenAccounts(children, out);
  }
  return out;
}

function currentOwnerKey() {
  return credentials().ownerKey || els.ownerKey?.value || "";
}

function preferredDebitCode() {
  const owner = currentOwnerKey();
  return (
    (owner && state.debitDefaults?.[owner]) ||
    state.pendingDebitCode ||
    ""
  );
}

function updateDebitDefaultHint() {
  if (!els.debitDefaultHint) return;
  const owner = currentOwnerKey();
  const code = owner && state.debitDefaults?.[owner];
  if (!code) {
    els.debitDefaultHint.textContent = "لم يُحفظ افتراضي بعد.";
    return;
  }
  const acc = state.accounts.find((a) => pickAccountCode(a) === code);
  els.debitDefaultHint.textContent = "الافتراضي: " + (acc ? accountLabel(acc) : code);
}

function selectedDebitAccount() {
  const code = String(els.debitAccount.value || "").trim();
  return state.accounts.find((a) => pickAccountCode(a) === code) || null;
}

function syncDebitAccountUI() {
  const selected = selectedDebitAccount();
  const code = String(els.debitAccount.value || preferredDebitCode() || "").trim();
  if (code && !els.debitAccount.value) els.debitAccount.value = code;
  if (els.debitAccountLabel) {
    els.debitAccountLabel.textContent = selected
      ? accountLabel(selected)
      : code
        ? code
        : state.accounts.length
          ? "اختر من دليل الحسابات"
          : "يُحمَّل الدليل بعد الدخول";
  }
  updateDebitDefaultHint();
}

function filteredAccounts(filter = "") {
  const q = String(filter || "").trim().toLowerCase();
  if (!q) return state.accounts;
  return state.accounts.filter(
    (a) => accountLabel(a).toLowerCase().includes(q) || pickAccountCode(a).toLowerCase().includes(q)
  );
}

function renderAccountModalList(filter = "") {
  if (!els.accountModalList) return;
  const selected = String(els.debitAccount.value || "").trim();
  const list = filteredAccounts(filter);
  const max = 120;
  const shown = list.slice(0, max);
  if (els.accountModalMeta) {
    els.accountModalMeta.textContent = list.length
      ? `عرض ${shown.length} من ${list.length} حساب`
      : "لا توجد نتائج";
  }
  if (!shown.length) {
    els.accountModalList.innerHTML = `<div class="muted">لا توجد حسابات مطابقة.</div>`;
    return;
  }
  els.accountModalList.innerHTML = shown
    .map((acc) => {
      const code = pickAccountCode(acc);
      const name = acc.AccountName || acc.accountName || acc.Name || acc.name || "";
      const active = code === selected ? " active" : "";
      return `<button type="button" class="account-item${active}" data-code="${escapeHtml(code)}">
        <b>${escapeHtml(code)}</b>
        <span>${escapeHtml(name)}</span>
      </button>`;
    })
    .join("");
}

function openAccountModal(target = "debit") {
  if (!els.accountModal) return;
  state.accountPickTarget = target;
  if (els.accountModalTitle) {
    els.accountModalTitle.textContent =
      target === "debit" ? "دليل الحسابات — المدين" : "دليل الحسابات — الدائن";
  }
  els.accountModal.hidden = false;
  renderAccountModalList(els.debitAccountSearch?.value || "");
  setTimeout(() => els.debitAccountSearch?.focus(), 30);
}

function closeAccountModal() {
  if (els.accountModal) els.accountModal.hidden = true;
  state.accountPickTarget = "debit";
}

function selectDebitAccount(code) {
  const value = String(code || "").trim();
  if (!value) return;
  els.debitAccount.value = value;
  state.pendingDebitCode = value;
  saveLocal();
  syncDebitAccountUI();
  closeAccountModal();
  els.data.dispatchEvent(new Event("input"));
  els.dataEach.dispatchEvent(new Event("input"));
  renderPreviewManual();
}

function selectManualCreditAccount(entryId, code) {
  const value = String(code || "").trim();
  if (!value) return;
  const entry = state.manualEntries.find((item) => item.id === entryId);
  if (!entry) return;
  entry.credit = value;
  renderManualEntries();
  renderPreviewManual();
  saveLocal();
  closeAccountModal();
}

function onAccountPicked(code) {
  const target = state.accountPickTarget;
  if (target === "debit") {
    selectDebitAccount(code);
    return;
  }
  if (target?.type === "credit") {
    selectManualCreditAccount(target.entryId, code);
    return;
  }
  selectDebitAccount(code);
}

function fillDebitAccounts() {
  const preferred = preferredDebitCode();
  if (preferred && state.accounts.some((a) => pickAccountCode(a) === preferred)) {
    els.debitAccount.value = preferred;
  } else if (!els.debitAccount.value && state.accounts.length) {
    const fallback = state.accounts.find((a) => pickAccountCode(a) === "555") || state.accounts[0];
    els.debitAccount.value = pickAccountCode(fallback);
  }
  syncDebitAccountUI();
}

async function loadChartAccounts() {
  const attempts = [
    "/api/NormalAccount?leafNormalAccounts=true&withBalance=false",
    "/api/NormalAccount?leafNormalAccounts=true",
    "/api/NormalAccount",
  ];
  let list = [];
  for (const path of attempts) {
    const data = await api("GET", path).catch(() => null);
    list = flattenAccounts(asList(data));
    if (list.length) {
      logLine("دليل الحسابات: " + list.length + " حساباً من " + path.replace("/api/", ""));
      break;
    }
  }
  list.sort((a, b) => pickAccountCode(a).localeCompare(pickAccountCode(b), "ar", { numeric: true }));
  state.accounts = list;
  for (const acc of list) {
    const code = pickAccountCode(acc);
    if (code) state.accountCache.set(code, acc);
  }
  fillDebitAccounts();
  if (!list.length) logLine("تعذر تحميل دليل الحسابات أو لا توجد حسابات ورقية.");
}

function saveDebitDefault() {
  const code = String(els.debitAccount.value || "").trim();
  const owner = currentOwnerKey();
  if (!code) {
    showSubmitError("حساب افتراضي", "اختر حساباً من الدليل ثم احفظه كافتراضي.");
    return;
  }
  if (!owner) {
    showSubmitError("غير متصل", "سجّل الدخول أولاً.");
    return;
  }
  state.debitDefaults[owner] = code;
  saveLocal();
  updateDebitDefaultHint();
  const acc = selectedDebitAccount();
  const label = acc ? accountLabel(acc) : code;
  showSubmitSuccess("تم الحفظ", "تم حفظ الحساب الافتراضي.", label);
}

function pickId(obj) {
  return obj?.Id || obj?.id || obj?.Key || obj?.key || "";
}

function pickName(obj) {
  return (
    obj?.DisplayName ||
    obj?.displayName ||
    obj?.AccountName ||
    obj?.accountName ||
    obj?.Name ||
    obj?.name ||
    obj?.Value ||
    obj?.value ||
    obj?.CenterName ||
    obj?.FullName ||
    obj?.Code ||
    obj?.AccountCode ||
    ""
  );
}

function flattenCostCenters(nodes, out = [], prefix = "") {
  for (const node of nodes || []) {
    const name = node.Name || node.CenterName || node.name || node.centerName || "";
    const code = node.Code || node.CenterCode || node.code || node.centerCode || "";
    const label = `${prefix}${code ? code + " — " : ""}${name}`.trim();
    const id = node.Id || node.id;
    if (id) out.push({ Id: id, label, raw: node });
    const children = node.Children || node.children;
    if (children?.length) flattenCostCenters(children, out, prefix + "— ");
  }
  return out;
}

function isRemittanceType(item) {
  const text = `${pickName(item)} ${item.Value || ""} ${item.DisplayName || ""}`;
  return /حوالة|تحويل|remit|transfer/i.test(text);
}

function fillSelect(select, items, getValue, getLabel, preferred) {
  select.innerHTML = "";
  if (!items.length) {
    const opt = document.createElement("option");
    opt.value = "";
    opt.textContent = "لا توجد بيانات";
    select.appendChild(opt);
    return;
  }
  for (const item of items) {
    const opt = document.createElement("option");
    opt.value = getValue(item);
    opt.textContent = getLabel(item);
    select.appendChild(opt);
  }
  if (preferred) {
    const found =
      typeof preferred === "function"
        ? items.find((item) => preferred(item))
        : items.find((item) => getValue(item) === preferred);
    if (found) select.value = getValue(found);
  }
}

function currentJournalType() {
  return state.journalTypes.find((t) => pickId(t) === els.journalType.value) || null;
}

function fillSubscriptions(list, preferred) {
  const items = mapSubscriptions(list);
  if (!items.length) {
    els.subscription.innerHTML = `<option value="">لا يوجد اشتراك ظاهر</option>`;
    state.subscriptions = [];
    return;
  }
  state.subscriptions = items;
  fillSelect(
    els.subscription,
    items,
    (s) => s.ownerKey,
    (s) => subscriptionLabel(s),
    preferred || items[0].ownerKey
  );
  els.ownerKey.value = els.subscription.value;
  syncSessionBadge();
}

async function loginCloud() {
  const username = String(els.username?.value || "").trim();
  const password = String(els.password?.value || "");
  if (!username || !password) {
    setConnStatus("أدخل البريد/اسم المستخدم وكلمة المرور.", "error");
    return;
  }
  els.loginBtn.disabled = true;
  setConnStatus("جارٍ تسجيل الدخول إلى وكيد...");
  try {
    const data = await API().wakeedLogin(username, password, {
      server: els.server?.value || WP().platformState.server,
      buildNumber: els.buildNumber?.value || WP().platformState.buildNumber,
      ownerKey: els.ownerKey.value,
      deviceName: WP().getDeviceName(),
    });
    els.token.value = "server-held";
    applySessionIdentity({ userDisplayName: data.userDisplayName, subscriptions: data.subscriptions });
    fillSubscriptions(data.subscriptions, data.ownerKey);
    if (!els.ownerKey.value && data.ownerKey) els.ownerKey.value = data.ownerKey;
    if (els.password) els.password.value = "";
    await saveLocal();
    const name = WP().platformState.userDisplayName || username;
    setConnStatus(`تم الدخول باسم ${name}. جارٍ تحميل بيانات الشركة...`, "ok");
    if (!credentials().ownerKey) {
      setConnStatus("تم الدخول لكن لم يُعثر على شركة مرتبطة بالحساب.", "error");
      return;
    }
    const connected = await connect();
    if (!connected) {
      throw new Error("تعذر تحميل بيانات الشركة من وكيد.");
    }
  } catch (err) {
    if (!state.connected) {
      setConnected(false, "فشل الدخول");
      const msg = err.message || String(err);
      setConnStatus(msg, "error");
      showLogin();
    }
  } finally {
    els.loginBtn.disabled = false;
  }
}

let connectPromise = null;

async function connect() {
  if (connectPromise) return connectPromise;
  connectPromise = connectOnce().finally(() => {
    connectPromise = null;
  });
  return connectPromise;
}

async function connectOnce() {
  applyOwnerFromUrl();
  const creds = credentials();
  if (!WP().platformState.wakeedToken || !creds.ownerKey) {
    setConnStatus("سجّل الدخول أولاً.", "error");
    return false;
  }
  setConnStatus("جارٍ الاتصال بخادم وكيد...");
  try {
    const [types, currency, centers, lastEntry, accounts] = await Promise.all([
      api("GET", "/api/JournalType"),
      api("GET", "/api/Currency/GetBaseCurrency"),
      api("GET", "/api/CostCenter/GetTree").catch(() => []),
      api("GET", "/api/JournalEntry/GetLast").catch(() => null),
      api("GET", "/api/NormalAccount?leafNormalAccounts=true&withBalance=false").catch(() => null),
    ]);

    state.journalTypes = Array.isArray(types) ? types : [];
    state.currency = currency;
    state.costCenters = flattenCostCenters(Array.isArray(centers) ? centers : []);
    state.sampleEntry = lastEntry;
    const details = lastEntry?.JournalEntryDetails || lastEntry?.journalEntryDetails || [];
    state.sampleDetail = details[0] || null;
    state.accountCache.clear();
    state.accounts = flattenAccounts(asList(accounts));
    if (!state.accounts.length) {
      await loadChartAccounts();
    } else {
      state.accounts.sort((a, b) => pickAccountCode(a).localeCompare(pickAccountCode(b), "ar", { numeric: true }));
      for (const acc of state.accounts) {
        const code = pickAccountCode(acc);
        if (code) state.accountCache.set(code, acc);
      }
      fillDebitAccounts();
      logLine("دليل الحسابات: " + state.accounts.length + " حساباً.");
    }

    fillSelect(
      els.journalType,
      state.journalTypes,
      (t) => pickId(t),
      (t) => pickName(t) || pickId(t),
      isRemittanceType
    );
    if (!els.journalType.value && state.journalTypes[0]) {
      els.journalType.value = pickId(state.journalTypes[0]);
    }

    const centerItems = [{ Id: "", label: "بدون / الافتراضي" }, ...state.costCenters];
    const preferredCenter =
      currentJournalType()?.CostCenterId || lastEntry?.JournalEntryDetails?.[0]?.CostCenterId || "";
    fillSelect(els.costCenter, centerItems, (c) => c.Id, (c) => c.label, preferredCenter);

    const exp = decodeJwtExp(creds.token);
    const curName = currency?.Code || currency?.Name || "عملة الأساس";
    state.connected = true;
    await refreshSessionIdentity();
    syncSessionBadge(curName);
    saveLocal();
    const who = state.userDisplayName || currentCompanyName();
    const msg =
      (who ? `مرحباً ${who}. ` : "تم الاتصال. ") +
      `العملة: ${curName}` +
      (exp ? ` · الجلسة صالحة حتى ${exp}` : "") +
      (state.sampleDetail ? " · تم قراءة شكل القيود من آخر سند." : "");
    setConnStatus(msg, "ok");
    renderPreview();
    renderPreviewEach();
    renderPreviewManual();
    updateLedgerBadge();
    showApp();
    return true;
  } catch (err) {
    state.connected = false;
    setConnected(false, "فشل الاتصال");
    const msg = err.message || String(err);
    setConnStatus(msg, "error");
    showLogin();
    return false;
  }
}

function currentRows(source) {
  const debitAcc = String(els.debitAccount.value || "").trim();
  const text = source === "each" ? els.dataEach?.value : els.data.value;
  return parseRowsFromTable(text || "", debitAcc);
}

function totals(rows) {
  let debit = 0;
  let credit = 0;
  for (const row of rows) {
    debit += Number(row.debit || 0);
    credit += Number(row.credit || 0);
  }
  return { debit, credit };
}

function renderPreview(resolved = null) {
  const rows = currentRows("batch");
  const { debit, credit } = totals(rows);
  els.countCustomers.textContent = String(Math.ceil(rows.length / 2));
  els.countLines.textContent = String(rows.length);
  els.sumDebit.textContent = String(debit);
  els.sumCredit.textContent = String(credit);

  if (!rows.length) {
    els.previewBody.innerHTML = `<tr><td class="muted" colspan="6">—</td></tr>`;
    return rows;
  }

  els.previewBody.innerHTML = rows
    .map((row, i) => {
      const acc = resolved?.get(normalizeAccountKey(row.account));
      const accLabel = acc
        ? `${acc.AccountCode || acc.Code || acc.accountCode || row.account} — ${acc.AccountName || acc.Name || acc.accountName || ""}`
        : "لم يُحل بعد";
      return `<tr>
        <td>${i + 1}</td>
        <td>${escapeHtml(composeNote(row.description, sectionNote("batch")))}</td>
        <td>${escapeHtml(row.account)}</td>
        <td class="debit">${row.debit || ""}</td>
        <td class="credit">${row.credit || ""}</td>
        <td>${escapeHtml(accLabel)}</td>
      </tr>`;
    })
    .join("");
  return rows;
}

function renderPreviewEach(resolved = null) {
  const rows = currentRows("each");
  const groups = groupCustomerRows(rows);
  const { debit, credit } = totals(rows);
  els.countVouchersEach.textContent = String(groups.length);
  els.countCustomersEach.textContent = String(groups.length);
  els.sumDebitEach.textContent = String(debit);
  els.sumCreditEach.textContent = String(credit);

  if (!rows.length) {
    els.previewBodyEach.innerHTML = `<tr><td class="muted" colspan="7">—</td></tr>`;
    return rows;
  }

  let lineNo = 0;
  els.previewBodyEach.innerHTML = groups
    .map((group, gi) =>
      group.rows
        .map((row) => {
          lineNo += 1;
          const acc = resolved?.get(normalizeAccountKey(row.account));
          const accLabel = acc
            ? `${acc.AccountCode || acc.Code || acc.accountCode || row.account} — ${acc.AccountName || acc.Name || acc.accountName || ""}`
            : "لم يُحل بعد";
          return `<tr>
            <td>${gi + 1}</td>
            <td>${lineNo}</td>
            <td>${escapeHtml(composeNote(row.description, sectionNote("each")))}</td>
            <td>${escapeHtml(row.account)}</td>
            <td class="debit">${row.debit || ""}</td>
            <td class="credit">${row.credit || ""}</td>
            <td>${escapeHtml(accLabel)}</td>
          </tr>`;
        })
        .join("")
    )
    .join("");
  return rows;
}

function manualRows() {
  const debitAcc = String(els.debitAccount.value || "").trim();
  const rows = [];
  for (const entry of state.manualEntries || []) {
    const name = String(entry.name || "").trim();
    const credit = String(entry.credit || "").trim();
    const amt = cleanAmount(entry.amount);
    if (!name || !amt || !credit) continue;
    const clientNote = String(entry.note || "").trim();
    rows.push({ account: debitAcc, description: name, debit: amt, credit: "", clientNote });
    rows.push({ account: credit, description: name, debit: "", credit: amt, clientNote });
  }
  return rows;
}

function renderManualEntries() {
  ensureManualEntries();
  if (!els.manualEntriesList) return;
  const canRemove = state.manualEntries.length > 1;
  els.manualEntriesList.innerHTML = state.manualEntries
    .map((entry, index) => {
      const removeDisabled = canRemove ? "" : " disabled";
      return `<article class="manual-entry" data-id="${escapeHtml(entry.id)}">
        <div class="manual-entry-head">
          <span class="manual-entry-no">سند ${index + 1}</span>
          <button type="button" class="ghost manual-entry-remove"${removeDisabled}>حذف</button>
        </div>
        <div class="manual-entry-fields">
          <div>
            <label>الاسم</label>
            <input type="text" class="manual-name" value="${escapeHtml(entry.name || "")}" placeholder="اسم العميل" autocomplete="off">
          </div>
          <div>
            <label>المبلغ</label>
            <input type="text" class="manual-amount" value="${escapeHtml(entry.amount || "")}" inputmode="decimal" placeholder="1500" autocomplete="off">
          </div>
          <div>
            <label>الدائن</label>
            <div class="manual-credit-field">
              <input type="text" class="manual-credit" value="${escapeHtml(entry.credit || "")}" placeholder="9830" autocomplete="off">
              <button type="button" class="ghost manual-credit-pick btn-sm">اختر</button>
            </div>
          </div>
        </div>
        <div class="manual-entry-note">
          <label>البيان</label>
          <input type="text" class="manual-note" value="${escapeHtml(entry.note || "")}" placeholder="ملاحظة هذا العميل" autocomplete="off">
        </div>
      </article>`;
    })
    .join("");
  if (els.manualEntryCount) {
    els.manualEntryCount.textContent = String(state.manualEntries.length);
  }
}

function addManualEntry() {
  ensureManualEntries();
  state.manualEntries.push({ id: manualEntryId(), name: "", amount: "", credit: "", note: "" });
  renderManualEntries();
  renderPreviewManual();
  saveLocal();
  const lastName = els.manualEntriesList?.lastElementChild?.querySelector(".manual-name");
  lastName?.focus();
}

function removeManualEntry(id) {
  if (state.manualEntries.length <= 1) return;
  state.manualEntries = state.manualEntries.filter((entry) => entry.id !== id);
  renderManualEntries();
  renderPreviewManual();
  saveLocal();
}

function syncManualEntryFromEl(entryEl) {
  const id = entryEl.dataset.id;
  const entry = state.manualEntries.find((item) => item.id === id);
  if (!entry) return;
  entry.name = entryEl.querySelector(".manual-name")?.value || "";
  entry.amount = entryEl.querySelector(".manual-amount")?.value || "";
  entry.credit = entryEl.querySelector(".manual-credit")?.value || "";
  entry.note = entryEl.querySelector(".manual-note")?.value || "";
}

function renderPreviewManual(resolved = null) {
  const rows = manualRows();
  const groups = groupCustomerRows(rows);
  const { debit, credit } = totals(rows);
  if (els.countVouchersManual) els.countVouchersManual.textContent = String(groups.length);
  if (els.sumDebitManual) els.sumDebitManual.textContent = String(debit);
  if (els.sumCreditManual) els.sumCreditManual.textContent = String(credit);
  if (!els.previewBodyManual) return rows;

  if (!rows.length) {
    els.previewBodyManual.innerHTML = `<tr><td class="muted" colspan="7">—</td></tr>`;
    return rows;
  }

  let lineNo = 0;
  els.previewBodyManual.innerHTML = groups
    .map((group, gi) =>
      group.rows
        .map((row) => {
          lineNo += 1;
          const acc = resolved?.get(normalizeAccountKey(row.account));
          const accLabel = acc
            ? `${acc.AccountCode || acc.Code || acc.accountCode || row.account} — ${acc.AccountName || acc.Name || acc.accountName || ""}`
            : "لم يُحل بعد";
          return `<tr>
            <td>${gi + 1}</td>
            <td>${lineNo}</td>
            <td>${escapeHtml(composeNote(row.description, row.clientNote || ""))}</td>
            <td>${escapeHtml(row.account)}</td>
            <td class="debit">${row.debit || ""}</td>
            <td class="credit">${row.credit || ""}</td>
            <td>${escapeHtml(accLabel)}</td>
          </tr>`;
        })
        .join("")
    )
    .join("");
  return rows;
}

function escapeHtml(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function normalizeAccountKey(value) {
  return String(value || "").trim();
}

function asList(data) {
  if (!data) return [];
  if (Array.isArray(data)) return data;
  if (Array.isArray(data.Items)) return data.Items;
  if (Array.isArray(data.items)) return data.items;
  if (Array.isArray(data.Data)) return data.Data;
  if (Array.isArray(data.data)) return data.data;
  if (Array.isArray(data.Result)) return data.Result;
  if (Array.isArray(data.result)) return data.result;
  if (data.Id || data.id) return [data];
  return [];
}

async function resolveAccount(query) {
  const key = normalizeAccountKey(query);
  if (!key) throw new Error("حساب فارغ");
  if (state.accountCache.has(key)) return state.accountCache.get(key);

  const fromChart = state.accounts.find((a) => pickAccountCode(a) === key);
  if (fromChart && pickId(fromChart)) {
    state.accountCache.set(key, fromChart);
    return fromChart;
  }

  let found = null;
  if (/^\d/.test(key)) {
    found = await api("GET", `/api/NormalAccount/GetByCode?code=${encodeURIComponent(key)}`).catch(() => null);
  }
  if (!found || !pickId(found)) {
    const list = asList(
      await api(
        "GET",
        `/api/NormalAccount?accountName=${encodeURIComponent(key)}&nameOrCode=${encodeURIComponent(key)}&limit=20`
      ).catch(() => [])
    );
    found =
      list.find((a) => String(a.AccountCode || a.Code || a.accountCode || "") === key) ||
      list.find((a) => String(a.AccountName || a.Name || a.accountName || "") === key) ||
      list[0] ||
      null;
  }
  if (!found || !pickId(found)) {
    throw new Error(`تعذر إيجاد الحساب: ${key}`);
  }
  state.accountCache.set(key, found);
  return found;
}

async function resolveRows(rows) {
  const unique = [...new Set(rows.map((r) => normalizeAccountKey(r.account)).filter(Boolean))];
  const map = new Map();
  await Promise.all(
    unique.map(async (acc) => {
      map.set(acc, await resolveAccount(acc));
    })
  );
  return map;
}

function toIsoDate(dateValue) {
  const value = String(dateValue || "").trim() || todayInputValue();
  return `${value}T00:00:00.000Z`;
}

function num(v) {
  const n = Number(v || 0);
  return Number.isFinite(n) ? n : 0;
}

function sectionNote(section) {
  if (section === "each") return String(els.notesEach?.value || "").trim();
  if (section === "batch") return String(els.notes?.value || "").trim();
  return "";
}

function composeNote(name, extra = "") {
  const note = String(extra || "").trim();
  const who = String(name || "").trim();
  if (who && note) return `${who} — ${note}`;
  return who || note;
}

function groupClientNote(group) {
  return String(group.rows[0]?.clientNote || group.rows[1]?.clientNote || "").trim();
}

function groupStatement(group, section) {
  const extra = section === "manual" ? groupClientNote(group) : sectionNote(section);
  return composeNote(group.name, extra);
}

function updateNotesPreviewBatch() {
  const extra = sectionNote("batch");
  const text = extra
    ? `ستظهر في البيان: اسم العميل — ${extra}`
    : "بدون ملاحظة إضافية — سيظهر اسم العميل كبيان.";
  if (els.notesPreview) els.notesPreview.textContent = text;
}

function updateNotesPreviewEach() {
  const extra = sectionNote("each");
  const text = extra
    ? `ستظهر في البيان: اسم العميل — ${extra}`
    : "بدون ملاحظة إضافية — سيظهر اسم العميل كبيان.";
  if (els.notesPreviewEach) els.notesPreviewEach.textContent = text;
}

function clearBatchForm() {
  if (els.notes) els.notes.value = "";
  if (els.data) els.data.value = "";
  updateNotesPreviewBatch();
  renderPreview();
  saveLocal();
}

function clearEachForm() {
  if (els.notesEach) els.notesEach.value = "";
  if (els.dataEach) els.dataEach.value = "";
  updateNotesPreviewEach();
  renderPreviewEach();
  saveLocal();
}

function clearManualForm() {
  state.manualEntries = [{ id: manualEntryId(), name: "", amount: "", credit: "", note: "" }];
  renderManualEntries();
  renderPreviewManual();
  saveLocal();
}

function buildDetail(row, account, index, dateIso, extras) {
  const amount = num(row.debit || row.credit);
  const isDebit = Boolean(row.debit);
  const currencyId = pickId(state.currency);
  const rate = num(state.currency?.Rate || state.currency?.rate || 1) || 1;
  const accountId = pickId(account);
  const note =
    extras.lineNote ||
    composeNote(
      row.description,
      extras.section === "manual" ? row.clientNote : sectionNote(extras.section || "batch")
    );
  const detail = {
    normalAccountId: accountId,
    AccountID: accountId,
    debit: isDebit ? amount : 0,
    credit: isDebit ? 0 : amount,
    isDebit,
    notes: note,
    currencyID: currencyId || undefined,
    rate,
    date: dateIso,
    orderInJournal: index,
    discountGiving: 0,
    discountTaking: 0,
    amountAfterDiscount: amount,
  };

  if (extras.costCenterId) detail.costCenterID = extras.costCenterId;
  if (extras.correspondingId) {
    detail.correspondingAccountID = extras.correspondingId;
    detail.oppositeAccountID = extras.correspondingId;
  }
  return detail;
}

function selectedCostCenterId() {
  if (!els.includeCostCenter?.checked) return "";
  return (
    els.costCenter.value ||
    currentJournalType()?.CostCenterId ||
    currentJournalType()?.costCenterId ||
    state.sampleDetail?.CostCenterId ||
    state.sampleDetail?.costCenterId ||
    state.sampleDetail?.costCenterID ||
    ""
  );
}

function buildJournal(rows, resolved, options = {}) {
  const dateIso = toIsoDate(els.entryDate.value);
  const costCenterId = selectedCostCenterId();
  const typeId = els.journalType.value;
  if (!typeId) throw new Error("اختر نوع السند (سند حوالة).");
  const section = options.section || "batch";

  const details = rows.map((row, i) => {
    const opposite = i % 2 === 0 ? rows[i + 1] : rows[i - 1];
    const correspondingId =
      els.useOpposite?.checked && opposite
        ? pickId(resolved.get(normalizeAccountKey(opposite.account)))
        : "";
    const lineExtra =
      options.lineNote != null
        ? options.lineNote
        : section === "manual"
          ? row.clientNote
          : sectionNote(section);
    return buildDetail(row, resolved.get(normalizeAccountKey(row.account)), i, dateIso, {
      costCenterId,
      correspondingId,
      section,
      lineNote: composeNote(row.description, lineExtra),
    });
  });

  const { debit, credit } = totals(rows);
  if (Math.abs(debit - credit) > 0.001) {
    throw new Error(`القيد غير متوازن: مدين ${debit} ≠ دائن ${credit}`);
  }

  const notes =
    options.notes ||
    (section === "manual" ? "" : sectionNote(section)) ||
    "سند حوالة";
  const scopeId =
    currentJournalType()?.scopeId ||
    currentJournalType()?.ScopeId ||
    state.sampleEntry?.scopeId ||
    state.sampleEntry?.ScopeId ||
    undefined;

  return {
    date: dateIso,
    dateEntry1: dateIso,
    defaultPosting: dateIso,
    notes,
    journalEntryNumber: 0,
    journalEntryDetails: details,
    jornalTypeId: typeId,
    isChecked: false,
    isLocked: false,
    isJournalRemittance: true,
    offLineNumber: "",
    fromCache: false,
    costCenterId: costCenterId || undefined,
    scopeId,
  };
}

async function previewAndResolve(kind = "batch", options = {}) {
  const isEach = kind === "each";
  const rows =
    options.rows ??
    (options.source === "manual" ? renderPreviewManual() : isEach ? renderPreviewEach() : renderPreview());
  const previewBtn =
    options.previewBtn ??
    (options.source === "manual" ? els.previewBtnManual : isEach ? els.previewBtnEach : els.previewBtn);
  const emptyMessage =
    options.emptyMessage ||
    (options.source === "manual"
      ? "أكمل الاسم والمبلغ والدائن لسند واحد على الأقل."
      : "الصق بيانات صالحة: الاسم | المبلغ | الدائن.");
  if (!rows.length) {
    showSubmitError("بيانات ناقصة", emptyMessage, "", options.forSubmit);
    return null;
  }
  if (!String(els.debitAccount.value || "").trim()) {
    showSubmitError("حساب المدين", "اختر حساب المدين من دليل الحسابات.", "", options.forSubmit);
    return null;
  }
  if (!state.connected) {
    showSubmitError("غير متصل", "سجّل الدخول أولاً.", "", options.forSubmit);
    return null;
  }
  if (previewBtn) previewBtn.disabled = true;
  try {
    const resolved = await resolveRows(rows);
    if (options.source === "manual") renderPreviewManual(resolved);
    else if (isEach) renderPreviewEach(resolved);
    else renderPreview(resolved);
    const section =
      options.source === "manual" ? "manual" : isEach ? "each" : "batch";
    return { rows, resolved, section, source: options.source || section };
  } catch (err) {
    showSubmitError("تعذر التحقق", err.message || String(err), "", options.forSubmit);
    return null;
  } finally {
    if (previewBtn) previewBtn.disabled = false;
  }
}

async function previewAndResolveManual(kind = "batch", options = {}) {
  return previewAndResolve(kind, { ...options, source: "manual" });
}

async function postJournal(body) {
  const query = "reconciliationCheck=false&ignoreBudget=false";
  if (state.journalPostPath) {
    return api("POST", `${state.journalPostPath}?${query}`, body, { asForm: true });
  }
  try {
    const created = await api("POST", `/api/JournalEntry/AddJournalEntry?${query}`, body, { asForm: true });
    state.journalPostPath = "/api/JournalEntry/AddJournalEntry";
    return created;
  } catch (err) {
    const created = await api("POST", `/api/JournalEntry?${query}`, body, { asForm: true });
    state.journalPostPath = "/api/JournalEntry";
    return created;
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isTransientError(err) {
  const msg = String(err?.message || err).toLowerCase();
  return (
    msg.includes("econnreset") ||
    msg.includes("enotfound") ||
    msg.includes("pending stream") ||
    msg.includes("etimedout") ||
    msg.includes("socket hang") ||
    msg.includes("تعذر الاتصال") ||
    msg.includes("مهلة")
  );
}

function friendlyError(err) {
  const msg = String(err?.message || err);
  if (/econnreset|pending stream|enotfound|etimedout|socket hang|تعذر الاتصال/i.test(msg)) {
    return "انقطع الاتصال بخادم وكيد — أُعيدت المحاولة تلقائياً";
  }
  return msg;
}

async function postJournalWithRetry(body, attempts = 4) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      return await postJournal(body);
    } catch (err) {
      lastErr = err;
      if (!isTransientError(err) || i === attempts - 1) throw err;
      await sleep(450 * (i + 1));
    }
  }
  throw lastErr;
}

async function mapPool(items, limit, worker) {
  const out = new Array(items.length);
  let cursor = 0;
  async function run() {
    while (cursor < items.length) {
      const index = cursor++;
      out[index] = await worker(items[index], index);
    }
  }
  const n = Math.max(1, Math.min(limit, items.length));
  await Promise.all(Array.from({ length: n }, run));
  return out;
}

function loadLedgerAll() {
  return serverLedgerCache.slice();
}

function saveLedgerAll(rows) {
  serverLedgerCache = Array.isArray(rows) ? rows.slice() : [];
}

function ownerLedger() {
  const owner = currentOwnerKey();
  return loadLedgerAll().filter((row) => !owner || !row.ownerKey || row.ownerKey === owner);
}

function pickJournalNumber(obj) {
  if (!obj || typeof obj !== "object") return "";
  const n =
    obj.JournalEntryNumber ??
    obj.journalEntryNumber ??
    obj.Number ??
    obj.number ??
    obj.journalNumber ??
    obj.JournalNumber;
  if (n === 0 || n === "0" || n == null || n === "") return "";
  return String(n);
}

function unwrapCreated(created) {
  if (Array.isArray(created)) return unwrapCreated(created[0]);
  if (created && typeof created === "object" && created.data && typeof created.data === "object" && !created.journalEntryNumber && !created.JournalEntryNumber) {
    return unwrapCreated(created.data);
  }
  return created;
}

async function enrichCreated(created) {
  created = unwrapCreated(created);
  const number = pickJournalNumber(created);
  const id = pickId(created);
  if (number) return created;
  if (!id) return created;
  const attempts = [`/api/JournalEntry/${id}`, `/api/JournalEntry/GetById?id=${encodeURIComponent(id)}`];
  for (const path of attempts) {
    try {
      const full = unwrapCreated(await api("GET", path));
      if (pickJournalNumber(full)) return full;
    } catch (_) {}
  }
  return created;
}

function resolvedAccount(resolved, code) {
  const acc = resolved?.get(normalizeAccountKey(code));
  return {
    code: String(code || "").trim(),
    name: acc
      ? String(acc.AccountName || acc.accountName || acc.Name || acc.name || "").trim()
      : "",
  };
}

function makeId() {
  if (typeof crypto !== "undefined" && crypto.randomUUID) return crypto.randomUUID();
  return `r-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function appendLedgerEntries({ kind, groups, resolved, created, extra, entryDate, section = "batch" }) {
  const journalNumber = pickJournalNumber(created);
  const journalId = pickId(created);
  const now = new Date().toISOString();
  const date = String(entryDate || els.entryDate?.value || todayInputValue());
  const rows = (groups || []).map((group) => {
    const debitRow = group.rows.find((r) => r.debit);
    const creditRow = group.rows.find((r) => r.credit);
    const debit = resolvedAccount(resolved, debitRow?.account);
    const credit = resolvedAccount(resolved, creditRow?.account);
    const amount = Number(debitRow?.debit || creditRow?.credit || 0) || 0;
    return {
      id: makeId(),
      ownerKey: currentOwnerKey(),
      createdAt: now,
      entryDate: date,
      journalNumber,
      journalId,
      kind,
      name: group.name || "",
      amount,
      debitAccount: debit.code,
      debitAccountName: debit.name,
      creditAccount: credit.code,
      creditAccountName: credit.name,
      notes: extra || "",
      statement: groupStatement(group, section),
    };
  });
  if (!rows.length) return [];
  const all = loadLedgerAll();
  const seenIds = new Set(all.map((r) => r.journalId).filter(Boolean));
  const seenKeys = new Set(
    all.filter((r) => r.journalNumber).map((r) => `${r.journalNumber}|${r.name}|${r.entryDate}`)
  );
  const fresh = rows.filter((row) => {
    if (row.journalId && seenIds.has(row.journalId)) return false;
    if (row.journalNumber && seenKeys.has(`${row.journalNumber}|${row.name}|${row.entryDate}`)) return false;
    return true;
  });
  if (!fresh.length) return [];
  serverLedgerCache = fresh.concat(all);
  API().syncAppendLedger(fresh).catch(function () {});
  updateLedgerBadge();
  if (els.ledgerView && !els.ledgerView.hidden) renderLedger();
  return fresh;
}

function isGroupAlreadyLogged(group, entryDate) {
  const name = String(group.name || "").trim();
  const debitRow = group.rows.find((r) => r.debit);
  const creditRow = group.rows.find((r) => r.credit);
  const amount = Number(debitRow?.debit || creditRow?.credit || 0);
  const creditAccount = String(creditRow?.account || "").trim();
  const date = String(entryDate || els.entryDate?.value || todayInputValue());
  return ownerLedger().some(
    (row) =>
      row.name === name &&
      row.entryDate === date &&
      Number(row.amount) === amount &&
      row.creditAccount === creditAccount &&
      Boolean(row.journalNumber || row.journalId)
  );
}

function pendingCustomerGroups(groups, entryDate) {
  const skipped = [];
  const pending = [];
  for (const group of groups) {
    if (isGroupAlreadyLogged(group, entryDate)) skipped.push(group);
    else pending.push(group);
  }
  return { pending, skipped };
}

function ledgerKindLabel(kind) {
  return kind === "each" ? "لكل عميل" : "جماعي";
}

function formatLedgerWhen(iso) {
  if (!iso) return "";
  try {
    return new Intl.DateTimeFormat("ar-SY", { dateStyle: "short", timeStyle: "short" }).format(new Date(iso));
  } catch (_) {
    return String(iso).slice(0, 16).replace("T", " ");
  }
}

function sortedLedger(rows) {
  return [...rows].sort((a, b) => String(b.createdAt || "").localeCompare(String(a.createdAt || "")));
}

function filteredLedger() {
  const q = String(els.ledgerSearch?.value || "").trim().toLowerCase();
  const from = String(els.ledgerFrom?.value || "").trim();
  const to = String(els.ledgerTo?.value || "").trim();
  const kind = String(els.ledgerKind?.value || "").trim();
  const rows = ownerLedger().filter((row) => {
    const date = String(row.entryDate || "").slice(0, 10);
    if (from && date && date < from) return false;
    if (to && date && date > to) return false;
    if (kind && row.kind !== kind) return false;
    if (!q) return true;
    const hay = [
      row.journalNumber,
      row.name,
      row.amount,
      row.debitAccount,
      row.debitAccountName,
      row.creditAccount,
      row.creditAccountName,
      row.notes,
      row.statement,
      ledgerKindLabel(row.kind),
    ]
      .join(" ")
      .toLowerCase();
    return hay.includes(q);
  });
  return sortedLedger(rows);
}

function updateLedgerBadge() {
  if (els.ledgerCountBadge) els.ledgerCountBadge.textContent = String(ownerLedger().length);
}

function renderLedger() {
  const rows = filteredLedger();
  const vouchers = new Set(rows.map((r) => r.journalNumber || r.journalId || r.id));
  const sum = rows.reduce((n, r) => n + Number(r.amount || 0), 0);
  if (els.ledgerVoucherCount) els.ledgerVoucherCount.textContent = String(vouchers.size);
  if (els.ledgerNameCount) els.ledgerNameCount.textContent = String(rows.length);
  if (els.ledgerSum) els.ledgerSum.textContent = String(sum);
  updateLedgerBadge();
  if (!els.ledgerBody) return;
  if (!rows.length) {
    const empty = ownerLedger().length
      ? "لا نتائج لهذه الفلترة."
      : "لا يوجد سندات في السجل بعد. أنشئ سنداً ليظهر هنا برقم وكيد.";
    els.ledgerBody.innerHTML = `<tr><td colspan="9" class="muted">${empty}</td></tr>`;
    return;
  }
  els.ledgerBody.innerHTML = rows
    .map((row) => {
      const debit = row.debitAccountName
        ? `${row.debitAccount} — ${row.debitAccountName}`
        : row.debitAccount || "";
      const credit = row.creditAccountName
        ? `${row.creditAccount} — ${row.creditAccountName}`
        : row.creditAccount || "";
      return `<tr>
        <td class="journal-no">${escapeHtml(row.journalNumber || "—")}</td>
        <td>${escapeHtml(row.entryDate || "")}</td>
        <td class="muted">${escapeHtml(formatLedgerWhen(row.createdAt))}</td>
        <td>${escapeHtml(row.name || "")}</td>
        <td class="debit">${escapeHtml(row.amount || 0)}</td>
        <td>${escapeHtml(debit)}</td>
        <td>${escapeHtml(credit)}</td>
        <td>${escapeHtml(row.statement || row.notes || "")}</td>
        <td>${escapeHtml(ledgerKindLabel(row.kind))}</td>
      </tr>`;
    })
    .join("");
}

function ledgerTsv(rows) {
  const header = [
    "رقم السند",
    "تاريخ السند",
    "وقت الإنشاء",
    "الاسم",
    "المبلغ",
    "المدين",
    "اسم المدين",
    "الدائن",
    "اسم الدائن",
    "البيان",
    "الملاحظة",
    "النوع",
  ];
  const lines = [header.join("\t")];
  for (const row of rows) {
    lines.push(
      [
        row.journalNumber || "",
        row.entryDate || "",
        formatLedgerWhen(row.createdAt),
        row.name || "",
        row.amount || 0,
        row.debitAccount || "",
        row.debitAccountName || "",
        row.creditAccount || "",
        row.creditAccountName || "",
        row.statement || "",
        row.notes || "",
        ledgerKindLabel(row.kind),
      ].join("\t")
    );
  }
  return lines.join("\n");
}

function ledgerFileName(rows) {
  const from = els.ledgerFrom?.value || (rows[rows.length - 1]?.entryDate || "");
  const to = els.ledgerTo?.value || (rows[0]?.entryDate || todayInputValue());
  const part = from && to ? `${from}_إلى_${to}` : todayInputValue();
  return `سجل-سندات-وكيد-${part}.tsv`;
}

async function exportLedgerSheets() {
  const rows = filteredLedger();
  if (!rows.length) {
    showSubmitError("لا توجد بيانات", "لا توجد صفوف في الفلترة الحالية للتنزيل.");
    return;
  }
  try {
    await navigator.clipboard.writeText(ledgerTsv(rows));
    window.open("https://docs.google.com/spreadsheets/create", "_blank");
    showSubmitSuccess(
      "جاهز للصق",
      `تم نسخ ${rows.length} صفاً.`,
      "افتح Google Sheets والصق في الخلية A1 بـ Ctrl+V."
    );
  } catch (_) {
    showSubmitError("تعذر النسخ", "استخدم «تنزيل ملف الجدول» بدلاً من ذلك.");
  }
}

function downloadLedgerFile() {
  const rows = filteredLedger();
  if (!rows.length) {
    showSubmitError("لا توجد بيانات", "لا توجد صفوف في الفلترة الحالية للتنزيل.");
    return;
  }
  const blob = new Blob(["\uFEFF" + ledgerTsv(rows)], {
    type: "text/tab-separated-values;charset=utf-8",
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = ledgerFileName(rows);
  a.click();
  URL.revokeObjectURL(url);
  showSubmitSuccess("تم التنزيل", `تم تنزيل ${rows.length} صفاً حسب الفلترة الحالية.`);
}

function clearLedgerFilters() {
  if (els.ledgerSearch) els.ledgerSearch.value = "";
  if (els.ledgerFrom) els.ledgerFrom.value = "";
  if (els.ledgerTo) els.ledgerTo.value = "";
  if (els.ledgerKind) els.ledgerKind.value = "";
  renderLedger();
}

function openSubmitModeModal(summary) {
  if (!els.submitModeModal) return;
  if (els.submitModeSummary) els.submitModeSummary.textContent = summary;
  els.submitModeModal.hidden = false;
}

function closeSubmitModeModal() {
  if (els.submitModeModal) els.submitModeModal.hidden = true;
}

function openManualRegisterModal() {
  if (!guardSubmitJob()) return;
  const rows = renderPreviewManual();
  if (!rows.length) {
    showSubmitError("بيانات ناقصة", "أكمل الاسم والمبلغ والدائن لسند واحد على الأقل.");
    return;
  }
  if (!String(els.debitAccount.value || "").trim()) {
    showSubmitError("حساب المدين", "اختر حساب المدين من دليل الحسابات.");
    return;
  }
  if (!state.connected) {
    showSubmitError("غير متصل", "سجّل الدخول أولاً.");
    return;
  }
  submitManualJournal();
}

async function executeBatchJournalSubmit(prepared) {
  const entryDate = els.entryDate.value;
  const allGroups = groupCustomerRows(prepared.rows);
  const { pending, skipped } = pendingCustomerGroups(allGroups, entryDate);
  if (!pending.length) {
    showSubmitSuccess(
      "موجود في السجل",
      `كل العملاء (${allGroups.length}) مسجّلون مسبقاً في السجل لهذا التاريخ.`,
      skipped.map((g) => g.name).join("\n"),
      true
    );
    return;
  }
  const pendingRows = pending.flatMap((group) => group.rows);
  const body = buildJournal(pendingRows, prepared.resolved, { section: "batch" });
  let created = await enrichCreated(await postJournalWithRetry(body));
    if (!pickJournalNumber(created)) {
      try {
        created = await enrichCreated(await api("GET", "/api/JournalEntry/GetLast"));
      } catch (_) {}
    }
    const number = pickJournalNumber(created);
    const id = pickId(created);
    const skipNote = skipped.length ? `\n(${skipped.length} عميلاً موجود مسبقاً في السجل — تم تخطيهم)` : "";
    appendLedgerEntries({
      kind: "batch",
      groups: pending,
      resolved: prepared.resolved,
      created,
      extra: sectionNote("batch"),
      entryDate,
      section: "batch",
    });
    const details = [
      number ? `رقم السند في وكيد: ${number}` : "",
      pending.length ? `عدد العملاء في السند: ${pending.length}` : "",
      id ? `المعرف: ${id}` : "",
      skipNote.trim(),
      "تمت إضافة السجل — راجع تبويب «السجل».",
    ]
      .filter(Boolean)
      .join("\n");
  showSubmitSuccess(
    "تم التسجيل بنجاح",
    `تم حفظ السند الجماعي في وكيد.${skipNote}`,
    details,
    true
  );
  clearBatchForm();
}

async function executeEachJournalSubmit(prepared) {
  const section = prepared.section || "each";
  const groups = groupCustomerRows(prepared.rows);
  if (!groups.length) {
      showSubmitError("بيانات ناقصة", "لا توجد أزواج مدين/دائن صالحة.", "", true);
      return;
    }
  const entryDate = els.entryDate.value;
  const { pending, skipped } = pendingCustomerGroups(groups, entryDate);
  if (!pending.length) {
      showSubmitSuccess(
        "موجود في السجل",
        `كل العملاء (${groups.length}) مسجّلون مسبقاً في السجل لهذا التاريخ.`,
        skipped.map((g) => g.name).join("\n"),
        true
      );
      if (section === "manual") clearManualForm();
      else clearEachForm();
      return;
    }
  const ok = [];
  const failed = [];
  let done = 0;
  const total = pending.length;
    const skipNote = skipped.length ? `\n(${skipped.length} عميلاً موجود مسبقاً في السجل — تم تخطيهم)` : "";
    await mapPool(pending, JOURNAL_PARALLEL, async (group) => {
      const notes = groupStatement(group, section) || sectionNote(section) || "سند حوالة";
      try {
        const body = buildJournal(group.rows, prepared.resolved, { notes, section });
        const created = await enrichCreated(await postJournalWithRetry(body));
        const number = pickJournalNumber(created);
        appendLedgerEntries({
          kind: "each",
          groups: [group],
          resolved: prepared.resolved,
          created,
          extra: section === "manual" ? groupClientNote(group) : sectionNote(section),
          entryDate,
          section,
        });
        ok.push({ name: group.name, number });
      } catch (err) {
        failed.push({ name: group.name, msg: friendlyError(err) });
      } finally {
        done += 1;
        openSubmitModal({
          phase: "loading",
          title: "جارٍ الإنشاء...",
          message: `تم ${done} من ${total} سنداً.\nمسجّل في السجل: ${ok.length}${skipNote}`,
          job: true,
        });
      }
    });
    if (!failed.length) {
      const lines = ok.map((item) =>
        item.number ? `${item.name} — رقم ${item.number}` : item.name
      );
      showSubmitSuccess(
        "تم التسجيل بنجاح",
        `تم حفظ ${ok.length} سنداً في وكيد.${skipNote}`,
        lines.join("\n") + "\nكل سند حُفظ في السجل فور نجاحه — راجع تبويب «السجل».",
        true
      );
      if (section === "manual") clearManualForm();
      else clearEachForm();
    } else {
      const lines = [
        ...ok.map((item) => `✓ ${item.name}${item.number ? ` — رقم ${item.number}` : ""} (في السجل)`),
        ...failed.map((f) => `✗ ${f.name}: ${f.msg}`),
      ];
      showSubmitSuccess(
        "اكتمل جزئياً",
        `نجح ${ok.length} سنداً (محفوظ في السجل) وفشل ${failed.length}.${skipNote}\nأعد الإنشاء لإكمال المتبقي — المنجز موجود في السجل.`,
        lines.join("\n"),
        true
      );
    }
}

async function runJournalSubmit(mode, getPrepared, loadingMessage) {
  if (!guardSubmitJob()) return;
  beginSubmitJob();
  openSubmitModal({
    phase: "loading",
    title: "جارٍ الإنشاء...",
    message: loadingMessage,
    job: true,
  });
  try {
    const prepared = await getPrepared();
    if (!prepared) return;
    if (mode === "batch") await executeBatchJournalSubmit(prepared);
    else await executeEachJournalSubmit(prepared);
  } catch (err) {
    showSubmitError("فشل الإنشاء", err.message || String(err), "", true);
  } finally {
    finishSubmitJob();
  }
}

async function submitJournal() {
  return runJournalSubmit(
    "batch",
    () => previewAndResolve("batch", { forSubmit: true }),
    "يتم الآن تسجيل السند الجماعي في وكيد. يرجى الانتظار."
  );
}

async function submitEachJournal() {
  return runJournalSubmit(
    "each",
    () => previewAndResolve("each", { forSubmit: true }),
    "يتم الآن تسجيل السندات في وكيد. يرجى الانتظار."
  );
}

async function submitManualJournal() {
  closeSubmitModeModal();
  return runJournalSubmit(
    "each",
    () => previewAndResolveManual("each", { forSubmit: true }),
    "يتم الآن تسجيل سند منفصل لكل عميل. يرجى الانتظار."
  );
}

function showLicenseScreen() {
  const license = document.getElementById("licenseScreen");
  if (license) {
    license.hidden = false;
    license.removeAttribute("hidden");
  }
  const block = document.getElementById("blockScreen");
  if (block) block.hidden = true;
  if (els.loginScreen) {
    els.loginScreen.hidden = true;
    els.loginScreen.setAttribute("hidden", "");
  }
  if (els.appScreen) {
    els.appScreen.hidden = true;
    els.appScreen.setAttribute("hidden", "");
  }
}

function showBlockScreen(message) {
  const block = document.getElementById("blockScreen");
  const msg = document.getElementById("blockMessage");
  if (msg) msg.textContent = message || "التطبيق متوقف.";
  if (block) block.hidden = false;
  document.getElementById("licenseScreen") && (document.getElementById("licenseScreen").hidden = true);
  if (els.loginScreen) els.loginScreen.hidden = true;
  if (els.appScreen) els.appScreen.hidden = true;
}

async function logout() {
  try {
    await API().wakeedLogout();
  } catch (_) {}
  els.token.value = "";
  els.ownerKey.value = "";
  if (els.password) els.password.value = "";
  state.connected = false;
  WP().platformState.userDisplayName = "";
  WP().platformState.subscriptions = [];
  WP().platformState.wakeedToken = "";
  state.accountCache.clear();
  if (els.subscription) els.subscription.innerHTML = "";
  setConnected(false, "غير متصل");
  setConnStatus("تم تسجيل الخروج. أدخل حساب وكيد للدخول مجدداً.");
  showLogin();
}

async function copyTemplate() {
  try {
    await navigator.clipboard.writeText(SHEET_TEMPLATE);
    window.open("https://docs.google.com/spreadsheets/create", "_blank");
    showSubmitSuccess("تم نسخ القالب", "الصق في Google Sheets من الخلية A1 بـ Ctrl+V.");
  } catch (_) {
    showSubmitError("تعذر النسخ", "لم يتم نسخ القالب.");
  }
}

els.entryDate.value = todayInputValue();
initTheme();

WP().onBlock(function (message) {
  showBlockScreen(message);
});

document.getElementById("licenseActivateBtn")?.addEventListener("click", async function () {
  const input = document.getElementById("licenseKeyInput");
  const status = document.getElementById("licenseStatus");
  const key = String(input?.value || "").trim();
  if (!key) {
    if (status) status.textContent = "أدخل مفتاح الترخيص.";
    return;
  }
  try {
    if (status) status.textContent = "جارٍ التفعيل...";
    await WP().activateLicense(key);
    if (status) status.textContent = "تم التفعيل.";
    document.getElementById("licenseScreen").hidden = true;
    await bootApp();
  } catch (err) {
    if (status) status.textContent = err.message || "فشل التفعيل.";
  }
});

document.getElementById("blockRetryBtn")?.addEventListener("click", async function () {
  const ok = await WP().heartbeat();
  if (ok) {
    document.getElementById("blockScreen").hidden = true;
    if (state.connected) showApp();
    else showLogin();
  }
});

async function bootApp() {
  if (WP().platformState.blocked) return;
  updateNotesPreviewBatch();
  updateNotesPreviewEach();
  setTab("batch");
  setView("create");
  await loadLocal();
  renderPreview();
  renderPreviewEach();
  ensureManualEntries();
  renderManualEntries();
  renderPreviewManual();
  updateLedgerBadge();
  if (WP().platformState.wakeedToken) {
    setConnStatus("جارٍ استعادة الجلسة...");
    try {
      await connect();
    } catch (_) {
      showLogin();
    }
  } else {
    showLogin();
  }
}

(async function platformBoot() {
  showLicenseScreen();
  const hasSession = await WP().initPlatform();
  if (hasSession) {
    document.getElementById("licenseScreen").hidden = true;
    await bootApp();
  }
})();

els.loginBtn.addEventListener("click", loginCloud);
els.logoutBtn.addEventListener("click", logout);
els.themeToggle?.addEventListener("click", toggleTheme);
els.loginThemeToggle?.addEventListener("click", toggleTheme);
els.mobileNav?.addEventListener("change", (ev) => handleMobileNavChange(ev.target.value));
els.password.addEventListener("keydown", (ev) => {
  if (ev.key === "Enter") loginCloud();
});
els.username.addEventListener("keydown", (ev) => {
  if (ev.key === "Enter") els.password.focus();
});
els.subscription.addEventListener("change", () => {
  if (els.subscription.value) {
    els.ownerKey.value = els.subscription.value;
    if (els.token.value) connect();
    else fillDebitAccounts();
    updateLedgerBadge();
    if (els.ledgerView && !els.ledgerView.hidden) renderLedger();
  }
});
els.copyTemplate.addEventListener("click", copyTemplate);
els.copyTemplateEach.addEventListener("click", copyTemplate);
els.previewBtn.addEventListener("click", () => previewAndResolve("batch"));
els.submitBtn.addEventListener("click", submitJournal);
els.previewBtnEach.addEventListener("click", () => previewAndResolve("each"));
els.submitBtnEach.addEventListener("click", submitEachJournal);
els.addManualEntryBtn?.addEventListener("click", addManualEntry);
els.previewBtnManual?.addEventListener("click", () => previewAndResolveManual("each"));
els.submitBtnManual?.addEventListener("click", openManualRegisterModal);
els.submitModeEach?.addEventListener("click", () => submitManualJournal());
els.submitModeCancel?.addEventListener("click", closeSubmitModeModal);
els.submitModeBackdrop?.addEventListener("click", closeSubmitModeModal);
els.manualEntriesList?.addEventListener("input", (ev) => {
  const entryEl = ev.target.closest(".manual-entry");
  if (!entryEl) return;
  syncManualEntryFromEl(entryEl);
  renderPreviewManual();
  saveLocal();
});
els.manualEntriesList?.addEventListener("click", (ev) => {
  const entryEl = ev.target.closest(".manual-entry");
  if (!entryEl) return;
  if (ev.target.closest(".manual-entry-remove")) {
    removeManualEntry(entryEl.dataset.id);
    return;
  }
  if (ev.target.closest(".manual-credit-pick")) {
    openAccountModal({ type: "credit", entryId: entryEl.dataset.id });
  }
});
document.querySelectorAll(".create-tabs .tab").forEach((btn) => {
  btn.addEventListener("click", () => setTab(btn.dataset.tab));
});
document.querySelectorAll(".view-tabs .tab").forEach((btn) => {
  btn.addEventListener("click", () => setView(btn.dataset.view));
});
els.data.addEventListener("input", () => {
  renderPreview();
});
els.dataEach.addEventListener("input", () => {
  renderPreviewEach();
});
els.notes?.addEventListener("input", () => {
  updateNotesPreviewBatch();
  renderPreview();
  saveLocal();
});
els.notesEach?.addEventListener("input", () => {
  updateNotesPreviewEach();
  renderPreviewEach();
  saveLocal();
});
els.ledgerSearch?.addEventListener("input", renderLedger);
els.ledgerFrom?.addEventListener("change", renderLedger);
els.ledgerTo?.addEventListener("change", renderLedger);
els.ledgerKind?.addEventListener("change", renderLedger);
els.ledgerSheetsBtn?.addEventListener("click", exportLedgerSheets);
els.ledgerFileBtn?.addEventListener("click", downloadLedgerFile);
els.ledgerClearFilters?.addEventListener("click", clearLedgerFilters);
els.submitModalClose?.addEventListener("click", closeSubmitModal);
els.submitModalMinimize?.addEventListener("click", collapseSubmitModal);
els.submitModalDock?.addEventListener("click", expandSubmitModal);
els.submitModalBackdrop?.addEventListener("click", () => {
  if (submitJob.active && submitJob.phase === "loading") {
    collapseSubmitModal();
    return;
  }
  if (els.submitModalClose && !els.submitModalClose.hidden) closeSubmitModal();
});
els.debitAccountBtn.addEventListener("click", () => openAccountModal("debit"));
els.accountModalBackdrop.addEventListener("click", closeAccountModal);
els.accountModalClose.addEventListener("click", closeAccountModal);
els.accountModalList.addEventListener("click", (ev) => {
  const btn = ev.target.closest("[data-code]");
  if (btn) onAccountPicked(btn.dataset.code);
});
els.debitAccountSearch.addEventListener("input", () => {
  renderAccountModalList(els.debitAccountSearch.value);
});
els.debitAccountSearch.addEventListener("keydown", (ev) => {
  if (ev.key === "Enter") {
    ev.preventDefault();
    const first = filteredAccounts(els.debitAccountSearch.value)[0];
    if (first) onAccountPicked(pickAccountCode(first));
  } else if (ev.key === "Escape") {
    closeAccountModal();
  }
});
document.addEventListener("keydown", (ev) => {
  if (ev.key === "Escape" && els.submitModeModal && !els.submitModeModal.hidden) closeSubmitModeModal();
  if (ev.key === "Escape" && els.accountModal && !els.accountModal.hidden) closeAccountModal();
  if (ev.key === "Escape" && submitJob.active && submitJob.phase === "loading" && !els.submitModal?.hidden) {
    collapseSubmitModal();
    return;
  }
  if (ev.key === "Escape" && els.submitModal && !els.submitModal.hidden && els.submitModalClose && !els.submitModalClose.hidden) {
    closeSubmitModal();
  }
});
els.saveDebitDefault.addEventListener("click", saveDebitDefault);
els.journalType.addEventListener("change", () => {
  const type = currentJournalType();
  const centerId = type?.CostCenterId || type?.costCenterId;
  if (centerId && [...els.costCenter.options].some((o) => o.value === centerId)) {
    els.costCenter.value = centerId;
  }
});
