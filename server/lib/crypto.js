import crypto from "node:crypto";
import bcrypt from "bcryptjs";

function keyFromSecret(secret) {
  return crypto.createHash("sha256").update(String(secret || "dev-secret")).digest();
}

export function encryptText(plain, secret) {
  const text = String(plain ?? "");
  if (!text) return "";
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", keyFromSecret(secret), iv);
  const enc = Buffer.concat([cipher.update(text, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, enc]).toString("base64");
}

export function decryptText(encoded, secret) {
  const raw = String(encoded ?? "");
  if (!raw) return "";
  const buf = Buffer.from(raw, "base64");
  const iv = buf.subarray(0, 12);
  const tag = buf.subarray(12, 28);
  const data = buf.subarray(28);
  const decipher = crypto.createDecipheriv("aes-256-gcm", keyFromSecret(secret), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(data), decipher.final()]).toString("utf8");
}

export function hashAdminPassword(password) {
  return bcrypt.hashSync(String(password), 10);
}

export function verifyAdminPassword(password, hash) {
  return bcrypt.compareSync(String(password), String(hash));
}

export function hashAdminToken() {
  return crypto.randomBytes(32).toString("hex");
}
