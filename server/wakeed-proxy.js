import http2 from "node:http2";

const ALLOWED_HOSTS = new Set([
  "server1.wakeed.app",
  "devserver1.wakeed.app",
  "devserver2.wakeed.app",
  "devserver3.wakeed.app",
  "devserver4.wakeed.app",
]);

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".png": "image/png",
};

function json(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}

function safePublicPath(urlPath) {
  const decoded = decodeURIComponent(urlPath.split("?")[0]);
  const rel = decoded === "/" ? "/index.html" : decoded;
  const full = path.normalize(path.join(PUBLIC_DIR, rel));
  if (!full.startsWith(PUBLIC_DIR)) return null;
  return full;
}

function isAllowedServer(host) {
  const h = String(host || "").trim().toLowerCase().replace(/^https?:\/\//, "").split("/")[0];
  if (ALLOWED_HOSTS.has(h)) return h;
  if (/^(dev)?server\d+\.wakeed\.app$/.test(h)) return h;
  return null;
}

function normalizeOwnerKey(raw) {
  const text = String(raw || "").trim();
  if (!text) return "";
  const hash = text.includes("#") ? text.split("#").pop() : text;
  const segment = hash.replace(/^\/+/, "").split(/[/?]/).filter(Boolean)[0] || "";
  if (/^owner[_-][a-z0-9]+$/i.test(segment)) return segment;
  if (/^owner[_-][a-z0-9]+$/i.test(text) && !/[\/#]/.test(text)) return text;
  return text.replace(/^#\/?/, "");
}

function ownerKeyVariants(raw) {
  const key = normalizeOwnerKey(raw);
  if (!key) return [""];
  const variants = [key];
  if (/^owner_/i.test(key)) variants.push(key.replace(/^owner_/i, ""));
  else variants.push(`owner_${key}`);
  return [...new Set(variants)];
}

function isOwnerKeyError(data) {
  const text = typeof data === "string" ? data : data?.message || data?.Message || "";
  return /owner key not found/i.test(String(text));
}

function flattenDioForm(value, prefix, out = []) {
  if (value === undefined || value === null) return out;
  if (Array.isArray(value)) {
    value.forEach((item, i) => {
      if (item !== null && typeof item === "object") flattenDioForm(item, `${prefix}[${i}]`, out);
      else flattenDioForm(item, prefix, out);
    });
    return out;
  }
  if (typeof value === "object") {
    for (const [key, nested] of Object.entries(value)) {
      if (nested === undefined || nested === null) continue;
      flattenDioForm(nested, prefix ? `${prefix}[${key}]` : key, out);
    }
    return out;
  }
  if (typeof value === "boolean" || typeof value === "number" || typeof value === "string") {
    out.push([prefix, String(value)]);
  }
  return out;
}

function flattenAspNetForm(value, prefix, out = []) {
  if (value === undefined || value === null) return out;
  if (Array.isArray(value)) {
    value.forEach((item, i) => {
      flattenAspNetForm(item, `${prefix}[${i}]`, out);
    });
    return out;
  }
  if (typeof value === "object") {
    for (const [key, nested] of Object.entries(value)) {
      if (nested === undefined || nested === null) continue;
      const pascal = key.charAt(0).toUpperCase() + key.slice(1);
      flattenAspNetForm(nested, prefix ? `${prefix}.${pascal}` : pascal, out);
    }
    return out;
  }
  if (typeof value === "boolean" || typeof value === "number" || typeof value === "string") {
    out.push([prefix, String(value)]);
  }
  return out;
}

function encodeMultipart(fields) {
  const boundary = "----WakeedFormBoundary" + Date.now().toString(16) + Math.random().toString(16).slice(2, 10);
  const chunks = [];
  for (const [name, value] of fields) {
    const safeName = String(name).replace(/[\r\n"]/g, "");
    chunks.push(
      `--${boundary}\r\nContent-Disposition: form-data; name="${safeName}"\r\n\r\n${value}\r\n`
    );
  }
  chunks.push(`--${boundary}--\r\n`);
  return {
    boundary,
    buffer: Buffer.from(chunks.join(""), "utf8"),
  };
}

async function proxyWakeed(payload) {
  const server = isAllowedServer(payload.server || "server1.wakeed.app");
  if (!server) {
    return { status: 400, data: { message: "خادم وكيد غير مسموح." } };
  }

  let apiPath = String(payload.path || "");
  if (!apiPath.startsWith("/")) apiPath = `/${apiPath}`;
  if (!apiPath.startsWith("/api/") && !apiPath.startsWith("/user-api/")) {
    return { status: 400, data: { message: "مسار API غير مسموح." } };
  }

  const url = new URL(`https://${server}${apiPath}`);
  const query = payload.query && typeof payload.query === "object" ? payload.query : {};
  for (const [key, value] of Object.entries(query)) {
    if (value === undefined || value === null || value === "") continue;
    url.searchParams.set(key, String(value));
  }

  const token = String(payload.token || "").trim().replace(/^Bearer\s+/i, "");
  const ownerKeyRaw = String(payload.ownerKey || "").trim();
  const ownerKey = normalizeOwnerKey(ownerKeyRaw);
  const buildNumber = String(payload.buildNumber || "3996").trim() || "3996";
  const method = String(payload.method || "GET").toUpperCase();

  const headers = {
    accept: "application/json, text/plain, */*",
    "user-agent": "WakeedRemittanceApp/1.0",
    "build-number": buildNumber,
    "build-name": "7.0.1.3996",
    platform: "web",
    "application_type": "Web",
    device_name: "Chrome",
    "time-zone": String(-Math.round(new Date().getTimezoneOffset() / 60)),
  };
  if (token) {
    headers.authentication = `Bearer ${token}`;
    headers.authorization = `Bearer ${token}`;
  }

  let bodyBuf = null;
  if (payload.body !== undefined && payload.body !== null && method !== "GET" && method !== "HEAD") {
    if (payload.asForm) {
      const obj = typeof payload.body === "string" ? JSON.parse(payload.body) : payload.body;
      const fields = [...flattenDioForm(obj), ...flattenAspNetForm(obj)];
      const seen = new Set();
      const unique = fields.filter(([name]) => {
        if (seen.has(name)) return false;
        seen.add(name);
        return true;
      });
      const encoded = encodeMultipart(unique);
      bodyBuf = encoded.buffer;
      headers["content-type"] = `multipart/form-data; boundary=${encoded.boundary}`;
    } else {
      bodyBuf = Buffer.from(
        typeof payload.body === "string" ? payload.body : JSON.stringify(payload.body),
        "utf8"
      );
      headers["content-type"] = payload.contentType || "application/json; charset=utf-8";
    }
    headers["content-length"] = String(bodyBuf.length);
  }

  const keysToTry = ownerKey ? ownerKeyVariants(ownerKey) : [""];
  let last = { status: 0, data: null };
  for (const key of keysToTry) {
    const reqHeaders = { ...headers };
    if (key) reqHeaders["owner-key"] = key;
    let text;
    try {
      text = await http2Request({
        origin: `https://${server}`,
        method,
        pathWithQuery: `${url.pathname}${url.search}`,
        headers: reqHeaders,
        body: bodyBuf,
      });
    } catch (err) {
      return {
        status: 503,
        data: { message: err?.message || "تعذر الاتصال بخادم وكيد." },
      };
    }
    let data = text.body;
    try {
      data = text.body ? JSON.parse(text.body) : null;
    } catch {
      data = { raw: text.body };
    }
    last = { status: text.status, data };
    if (text.status >= 200 && text.status < 300) return last;
    if (!key || !isOwnerKeyError(data)) return last;
  }
  return last;
}

function pickToken(data) {
  if (!data) return "";
  if (typeof data === "string" && data.length > 40) return data.replace(/^Bearer\s+/i, "");
  const inner = data.data && typeof data.data === "object" ? data.data : data;
  return String(
    inner.access_token ||
      inner.accessToken ||
      inner.token ||
      inner.Token ||
      data.access_token ||
      data.token ||
      ""
  ).replace(/^Bearer\s+/i, "");
}

function asList(data) {
  if (!data) return [];
  if (Array.isArray(data)) return data;
  if (Array.isArray(data.data)) return data.data;
  if (Array.isArray(data.Data)) return data.Data;
  if (Array.isArray(data.Items)) return data.Items;
  if (Array.isArray(data.subscriptions)) return data.subscriptions;
  if (data.data && Array.isArray(data.data.subscriptions)) return data.data.subscriptions;
  return [];
}

function pickSubscriptionName(item) {
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
    if (!text) continue;
    if (/^owner[_-]/i.test(text)) continue;
    return text;
  }
  return "";
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

function pickOwnerKey(item) {
  const nested = item?.subscriptions?.[0] || item?.subscriptionAccounts?.[0] || item?.Subscriptions?.[0];
  return (
    item?.ownerKey ||
    item?.OwnerKey ||
    item?.owner_key ||
    nested?.ownerKey ||
    nested?.OwnerKey ||
    item?.id ||
    ""
  );
}

async function loginWakeed(payload) {
  const identifier = String(payload.username || payload.email || payload.phone || "").trim();
  const password = String(payload.password || "");
  if (!identifier || !password) {
    return { status: 400, data: { message: "أدخل البريد/اسم المستخدم وكلمة المرور." } };
  }

  const deviceName = String(payload.deviceName || "Chrome");
  const looksEmail = identifier.includes("@");
  const looksPhone = /^\+?\d{8,15}$/.test(identifier.replace(/[\s-]/g, ""));

  const attempts = [];
  if (looksEmail) {
    attempts.push({
      path: "/user-api/login-by-email",
      body: { email: identifier, password, device_name: deviceName, application_type: "Web" },
    });
  } else if (looksPhone) {
    attempts.push({
      path: "/user-api/login-by-phone",
      body: { phone: identifier, password, device_name: deviceName, application_type: "Web" },
    });
  } else {
    attempts.push({
      path: "/user-api/login-by-username",
      body: { username: identifier, password, device_name: deviceName, application_type: "Web" },
    });
    attempts.push({
      path: "/user-api/login-by-email",
      body: { email: identifier, password, device_name: deviceName, application_type: "Web" },
    });
  }

  let last = { status: 400, data: { message: "تعذر تسجيل الدخول." } };
  for (const attempt of attempts) {
    last = await proxyWakeed({
      server: payload.server,
      method: "POST",
      path: attempt.path,
      buildNumber: payload.buildNumber || "3996",
      body: attempt.body,
    });
    const token = pickToken(last.data);
    if (last.status >= 200 && last.status < 300 && token) {
      const subsRes = await proxyWakeed({
        server: payload.server,
        method: "GET",
        path: "/user-api/my-subscriptions",
        token,
        buildNumber: payload.buildNumber || "3996",
      });
      const subscriptions = asList(subsRes.data).map((item) => {
        const ownerKey = normalizeOwnerKey(pickOwnerKey(item));
        const name = pickSubscriptionName(item) || pickUserDisplayName(item) || "";
        return {
          id: item.id || item.Id || "",
          name: name && name !== ownerKey ? name : "",
          ownerKey,
        };
      }).filter((s) => s.ownerKey);
      const profileRes = await proxyWakeed({
        server: payload.server,
        method: "GET",
        path: "/user-api/my-profile",
        token,
        buildNumber: payload.buildNumber || "3996",
      }).catch(() => ({ data: null }));
      const profileUser =
        profileRes.data?.data || profileRes.data?.user || profileRes.data || null;
      const loginUser = last.data?.user || last.data?.data?.user || null;
      const user = profileUser || loginUser;
      const userDisplayName = pickUserDisplayName(user);
      return {
        status: 200,
        data: {
          token,
          refreshToken:
            last.data?.refresh_token ||
            last.data?.data?.refresh_token ||
            last.data?.refreshToken ||
            "",
          user,
          userDisplayName,
          subscriptions,
          ownerKey: subscriptions.find((s) => s.ownerKey)?.ownerKey || "",
        },
      };
    }
    if (last.status !== 404 && last.status !== 500) break;
  }
  return last;
}

const h2Sessions = new Map();
const h2Limiters = new Map();
const H2_MAX_CONCURRENT = 2;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

class OriginLimiter {
  constructor(max) {
    this.max = max;
    this.active = 0;
    this.waiters = [];
  }
  async run(task) {
    if (this.active >= this.max) {
      await new Promise((resolve) => this.waiters.push(resolve));
    }
    this.active += 1;
    try {
      return await task();
    } finally {
      this.active -= 1;
      const next = this.waiters.shift();
      if (next) next();
    }
  }
}

function getOriginLimiter(origin) {
  if (!h2Limiters.has(origin)) h2Limiters.set(origin, new OriginLimiter(H2_MAX_CONCURRENT));
  return h2Limiters.get(origin);
}

function isTransientNetworkError(err) {
  const code = String(err?.code || "").toLowerCase();
  const msg = String(err?.message || err || "").toLowerCase();
  return (
    code === "econnreset" ||
    code === "enotfound" ||
    code === "etimedout" ||
    code === "econnrefused" ||
    code === "epipe" ||
    msg.includes("econnreset") ||
    msg.includes("enotfound") ||
    msg.includes("pending stream has been canceled") ||
    msg.includes("socket hang up") ||
    msg.includes("session closed")
  );
}

function closeH2Session(origin) {
  const client = h2Sessions.get(origin);
  h2Sessions.delete(origin);
  if (client && !client.closed && !client.destroyed) {
    try {
      client.close();
    } catch (_) {}
  }
}

function getH2Session(origin) {
  const existing = h2Sessions.get(origin);
  if (existing && !existing.closed && !existing.destroyed) return existing;
  const client = http2.connect(origin);
  const drop = () => {
    if (h2Sessions.get(origin) === client) h2Sessions.delete(origin);
  };
  client.on("error", drop);
  client.on("close", drop);
  client.on("goaway", drop);
  h2Sessions.set(origin, client);
  return client;
}

function http2RequestOnce({ origin, method, pathWithQuery, headers, body, timeoutMs = 90000 }) {
  return new Promise((resolve, reject) => {
    let settled = false;
    const done = (err, value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      if (err) reject(err);
      else resolve(value);
    };
    const timer = setTimeout(() => done(new Error("انتهت مهلة الاتصال بخادم وكيد")), timeoutMs);

    let client;
    try {
      client = getH2Session(origin);
    } catch (err) {
      done(err);
      return;
    }

    const reqHeaders = {
      ":method": method,
      ":path": pathWithQuery,
      ":scheme": "https",
      ":authority": new URL(origin).host,
    };
    for (const [key, value] of Object.entries(headers || {})) {
      if (value == null || value === "") continue;
      reqHeaders[String(key).toLowerCase()] = String(value);
    }

    let req;
    try {
      req = client.request(reqHeaders);
    } catch (err) {
      closeH2Session(origin);
      done(err);
      return;
    }

    const chunks = [];
    let status = 0;
    req.on("response", (hdrs) => {
      status = Number(hdrs[":status"] || 0);
    });
    req.on("data", (chunk) => chunks.push(chunk));
    req.on("end", () => {
      done(null, { status, body: Buffer.concat(chunks).toString("utf8") });
    });
    req.on("error", (err) => {
      closeH2Session(origin);
      done(err);
    });
    if (body) req.end(body);
    else req.end();
  });
}

async function http2Request(opts) {
  const origin = opts.origin;
  const limiter = getOriginLimiter(origin);
  const maxAttempts = 4;
  let lastErr;
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await limiter.run(() => http2RequestOnce(opts));
    } catch (err) {
      lastErr = err;
      closeH2Session(origin);
      if (!isTransientNetworkError(err) || attempt === maxAttempts - 1) throw err;
      await sleep(300 * (attempt + 1));
    }
  }
  throw lastErr;
}

export { proxyWakeed, loginWakeed, normalizeOwnerKey, ownerKeyVariants };
