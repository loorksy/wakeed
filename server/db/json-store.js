import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = process.env.DB_PATH
  ? path.dirname(path.resolve(process.env.DB_PATH))
  : path.join(__dirname, "..", "data");

const FILES = {
  admins: "admins.json",
  licenses: "licenses.json",
  sessions: "sessions.json",
  user_settings: "user_settings.json",
  wakeed_credentials: "wakeed_credentials.json",
  ledger_entries: "ledger_entries.json",
};

let cache = {};
let nextIds = {};

function filePath(name) {
  return path.join(DATA_DIR, FILES[name]);
}

function load(name) {
  if (cache[name]) return cache[name];
  fs.mkdirSync(DATA_DIR, { recursive: true });
  const fp = filePath(name);
  if (!fs.existsSync(fp)) {
    cache[name] = [];
    nextIds[name] = 1;
    return cache[name];
  }
  const rows = JSON.parse(fs.readFileSync(fp, "utf8"));
  cache[name] = Array.isArray(rows) ? rows : [];
  nextIds[name] = cache[name].reduce((m, r) => Math.max(m, Number(r.id) || 0), 0) + 1;
  return cache[name];
}

function save(name) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.writeFileSync(filePath(name), JSON.stringify(cache[name] || [], null, 2), "utf8");
}

function table(name) {
  return {
    all(filterFn) {
      const rows = load(name);
      return filterFn ? rows.filter(filterFn) : [...rows];
    },
    get(filterFn) {
      return load(name).find(filterFn) || null;
    },
    insert(row) {
      const rows = load(name);
      const id = row.id ?? nextIds[name]++;
      const record = { ...row, id };
      rows.push(record);
      save(name);
      return { lastInsertRowid: id, changes: 1 };
    },
    update(filterFn, patch) {
      const rows = load(name);
      let changes = 0;
      for (let i = 0; i < rows.length; i++) {
        if (filterFn(rows[i])) {
          rows[i] = { ...rows[i], ...patch, id: rows[i].id };
          changes++;
        }
      }
      if (changes) save(name);
      return { changes };
    },
    delete(filterFn) {
      const rows = load(name);
      const kept = rows.filter((r) => !filterFn(r));
      const changes = rows.length - kept.length;
      cache[name] = kept;
      if (changes) save(name);
      return { changes };
    },
    upsert(keyFn, row) {
      const existing = load(name).find(keyFn);
      if (existing) {
        this.update((r) => keyFn(r), row);
        return existing.id;
      }
      return this.insert(row).lastInsertRowid;
    },
  };
}

export function getDb() {
  return {
    table,
    prepare() {
      throw new Error("Use table() API");
    },
  };
}

export function generateLicenseKey() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const part = () =>
    Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join("");
  return `WKD-${part()}-${part()}-${part()}`;
}

export function generateSessionToken() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

// Compatibility layer used by routes
export const dbApi = {
  admins: () => table("admins"),
  licenses: () => table("licenses"),
  sessions: () => table("sessions"),
  user_settings: () => table("user_settings"),
  wakeed_credentials: () => table("wakeed_credentials"),
  ledger_entries: () => table("ledger_entries"),
};
