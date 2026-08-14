import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { cors, json, readBody, fail } from "./lib/http.js";
import { seedAdmin } from "./lib/admin-auth.js";
import { requireLicense } from "./lib/middleware.js";
import {
  handleLicenseActivate,
  handleLicenseHeartbeat,
  handleLicenseStatus,
} from "./routes/license.js";
import { handleGetUserData, handlePutUserData } from "./routes/user-data.js";
import { handleGetLedger, handlePostLedger } from "./routes/ledger.js";
import {
  handleWakeedLogin,
  handleWakeedProxy,
  handleWakeedLogout,
} from "./routes/wakeed.js";
import {
  handleAdminLogin,
  handleAdminLogout,
  handleAdminListLicenses,
  handleAdminCreateLicense,
  handleAdminUpdateLicense,
  handleAdminMe,
} from "./routes/admin.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, "..");
const CLIENT_DIR = path.join(ROOT, "client");
const WEB_APP_DIR = path.join(ROOT, "web-app");
const ADMIN_DIR = path.join(ROOT, "admin");
const DOWNLOAD_DIR = path.join(ROOT, "download");
const RELEASES_DIR = path.join(ROOT, "releases");

const PORT = Number(process.env.PORT || 3780);
const HOST = process.env.HOST || "0.0.0.0";

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".wasm": "application/wasm",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".otf": "font/otf",
  ".map": "application/json",
  ".txt": "text/plain; charset=utf-8",
  ".apk": "application/vnd.android.package-archive",
};

function loadEnv() {
  const envPath = path.join(__dirname, ".env");
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, "utf8").split(/\r?\n/)) {
    const t = line.trim();
    if (!t || t.startsWith("#")) continue;
    const i = t.indexOf("=");
    if (i < 1) continue;
    const k = t.slice(0, i).trim();
    let v = t.slice(i + 1).trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
      v = v.slice(1, -1);
    }
    if (!process.env[k]) process.env[k] = v;
  }
}

function safeFile(baseDir, urlPath) {
  const decoded = decodeURIComponent(urlPath.split("?")[0]);
  let rel = decoded;
  if (rel === "/" || rel === "") rel = "/index.html";
  const full = path.normalize(path.join(baseDir, rel.replace(/^\//, "")));
  if (!full.startsWith(baseDir)) return null;
  return full;
}

function appWebDir() {
  if (fs.existsSync(path.join(WEB_APP_DIR, "index.html"))) return WEB_APP_DIR;
  return CLIENT_DIR;
}

function serveExisting(res, filePath, fallbackDir) {
  if (filePath && fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    return serveStatic(res, filePath);
  }
  if (fallbackDir) {
    const index = path.join(fallbackDir, "index.html");
    if (fs.existsSync(index)) return serveStatic(res, index);
  }
  return fail(res, 404, "الملف غير موجود.");
}

function serveStatic(res, filePath) {
  fs.readFile(filePath, (err, buf) => {
    if (err) {
      fail(res, 404, "الملف غير موجود.");
      return;
    }
    const ext = path.extname(filePath);
    res.writeHead(200, {
      "Content-Type": MIME[ext] || "application/octet-stream",
      "Cache-Control": ext === ".html" ? "no-store" : "no-cache",
    });
    res.end(buf);
  });
}

async function routeApi(req, res, url) {
  const pathname = url.pathname;

  if (pathname === "/api/health" && req.method === "GET") {
    return json(res, 200, { ok: true });
  }

  if (pathname === "/api/license/activate" && req.method === "POST") {
    return handleLicenseActivate(req, res);
  }

  if (pathname.startsWith("/api/admin/")) {
    if (pathname === "/api/admin/login" && req.method === "POST") return handleAdminLogin(req, res);
    if (pathname === "/api/admin/logout" && req.method === "POST") return handleAdminLogout(req, res);
    if (pathname === "/api/admin/me" && req.method === "GET") return handleAdminMe(req, res);
    if (pathname === "/api/admin/licenses" && req.method === "GET") return handleAdminListLicenses(req, res);
    if (pathname === "/api/admin/licenses" && req.method === "POST") return handleAdminCreateLicense(req, res);
    const m = pathname.match(/^\/api\/admin\/licenses\/(\d+)\/(suspend|activate|delete)$/);
    if (m && req.method === "POST") return handleAdminUpdateLicense(req, res, m[1], m[2]);
    return fail(res, 404, "مسار غير موجود.");
  }

  const ctx = requireLicense(req, res);
  if (!ctx) return;

  if (pathname === "/api/license/heartbeat" && req.method === "POST") {
    return handleLicenseHeartbeat(req, res, ctx);
  }
  if (pathname === "/api/license/status" && req.method === "GET") {
    return handleLicenseStatus(req, res, ctx);
  }
  if (pathname === "/api/user-data" && req.method === "GET") {
    return handleGetUserData(req, res, ctx);
  }
  if (pathname === "/api/user-data" && req.method === "PUT") {
    return handlePutUserData(req, res, ctx);
  }
  if (pathname === "/api/ledger" && req.method === "GET") {
    return handleGetLedger(req, res, ctx);
  }
  if (pathname === "/api/ledger" && req.method === "POST") {
    return handlePostLedger(req, res, ctx);
  }
  if (pathname === "/api/wakeed/login" && req.method === "POST") {
    return handleWakeedLogin(req, res, ctx);
  }
  if (pathname === "/api/wakeed/logout" && req.method === "POST") {
    return handleWakeedLogout(req, res, ctx);
  }
  if (pathname === "/api/wakeed/proxy" && req.method === "POST") {
    return handleWakeedProxy(req, res, ctx);
  }
  if (pathname === "/api/proxy" && req.method === "POST") {
    return handleWakeedProxy(req, res, ctx);
  }
  if (pathname === "/api/login" && req.method === "POST") {
    return handleWakeedLogin(req, res, ctx);
  }

  return fail(res, 404, "مسار API غير موجود.");
}

async function routeStatic(req, res, url) {
  const p = url.pathname;

  if (p.startsWith("/releases/")) {
    const filePath = safeFile(RELEASES_DIR, p.replace("/releases", ""));
    if (!filePath) return fail(res, 403, "مسار غير صالح.");
    return serveStatic(res, filePath);
  }

  if (p.startsWith("/admin")) {
    const sub = p.replace(/^\/admin\/?/, "") || "index.html";
    const filePath = safeFile(ADMIN_DIR, sub === "" ? "index.html" : sub);
    if (!filePath) return fail(res, 403, "مسار غير صالح.");
    return serveStatic(res, filePath);
  }

  if (p.startsWith("/download")) {
    const sub = p.replace(/^\/download\/?/, "") || "index.html";
    const filePath = safeFile(DOWNLOAD_DIR, sub === "" ? "index.html" : sub);
    if (!filePath) return fail(res, 403, "مسار غير صالح.");
    return serveStatic(res, filePath);
  }

  if (p.startsWith("/legacy")) {
    const sub = p.replace(/^\/legacy\/?/, "") || "index.html";
    const filePath = safeFile(CLIENT_DIR, sub === "" ? "index.html" : sub);
    if (!filePath) return fail(res, 403, "مسار غير صالح.");
    return serveExisting(res, filePath, CLIENT_DIR);
  }

  const webDir = appWebDir();
  const filePath = safeFile(webDir, p);
  if (!filePath) return fail(res, 403, "مسار غير صالح.");
  return serveExisting(res, filePath, webDir);
}

const server = http.createServer(async (req, res) => {
  cors(res);
  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    if (url.pathname.startsWith("/api/")) {
      await routeApi(req, res, url);
      return;
    }
    if (req.method !== "GET" && req.method !== "HEAD") {
      fail(res, 405, "طريقة غير مدعومة.");
      return;
    }
    await routeStatic(req, res, url);
  } catch (err) {
    fail(res, 500, err?.message || "خطأ في الخادم.");
  }
});

loadEnv();
seedAdmin();

server.listen(PORT, HOST, () => {
  console.log(`Wakeed Platform: http://${HOST}:${PORT}`);
});
