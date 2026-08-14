export function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

export async function readJson(req) {
  const raw = await readBody(req);
  try {
    return JSON.parse(raw.toString("utf8") || "{}");
  } catch {
    return null;
  }
}

export function json(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  });
  res.end(body);
}

export function ok(res, data = {}) {
  json(res, 200, { ok: true, data });
}

export function fail(res, status, message, extra = {}) {
  json(res, status, { ok: false, message, ...extra });
}

export function getBearer(req) {
  const h = String(req.headers.authorization || req.headers.authentication || "");
  const m = h.match(/^Bearer\s+(.+)$/i);
  return m ? m[1].trim() : "";
}

export function getSessionToken(req) {
  return getBearer(req) || String(req.headers["x-session-token"] || "").trim();
}

export function getAdminToken(req) {
  return getBearer(req) || String(req.headers["x-admin-token"] || "").trim();
}

export function cors(res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Session-Token, X-Admin-Token, X-Device-Id");
}
