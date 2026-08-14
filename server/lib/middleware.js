import { getLicenseBySession, touchLicenseSeen } from "./session.js";
import { fail, getSessionToken } from "./http.js";

export function requireLicense(req, res) {
  const token = getSessionToken(req);
  if (!token) {
    fail(res, 401, "جلسة غير صالحة — أدخل مفتاح الترخيص.");
    return null;
  }
  const license = getLicenseBySession(token);
  if (!license || license.invalidReason) {
    const reason = license?.invalidReason || "invalid";
    const msg =
      reason === "suspended"
        ? "تم إيقاف الترخيص."
        : reason === "deleted"
          ? "تم حذف الترخيص."
          : reason === "expired"
            ? "انتهت الجلسة — أعد التفعيل."
            : "الترخيص غير صالح.";
    fail(res, 403, msg, { code: reason });
    return null;
  }
  const deviceId = String(req.headers["x-device-id"] || "").trim();
  if (license.device_id && deviceId && license.device_id !== deviceId) {
    fail(res, 403, "هذا الترخيص مربوط بجهاز آخر.", { code: "device_mismatch" });
    return null;
  }
  touchLicenseSeen(license.id);
  return { token, license };
}
