import { dbApi } from "../db/index.js";
import { readJson, ok, fail } from "../lib/http.js";

export function listLedger(licenseId, ownerKey = "") {
  let rows = dbApi.ledger_entries().all((r) => r.license_id === licenseId);
  rows.sort((a, b) => String(b.created_at || "").localeCompare(String(a.created_at || "")));
  if (!ownerKey) return rows;
  return rows.filter((r) => !r.owner_key || r.owner_key === ownerKey);
}

export function appendLedger(licenseId, entries) {
  let added = 0;
  const existing = dbApi.ledger_entries().all((r) => r.license_id === licenseId);
  const ids = new Set(existing.map((r) => r.id));
  for (const row of entries || []) {
    const id = row.id;
    if (!id || ids.has(id)) continue;
    dbApi.ledger_entries().insert({
      id,
      license_id: licenseId,
      owner_key: row.ownerKey || row.owner_key || "",
      created_at: row.createdAt || row.created_at || new Date().toISOString(),
      entry_date: row.entryDate || row.entry_date || "",
      journal_number: row.journalNumber || row.journal_number || "",
      journal_id: row.journalId || row.journal_id || "",
      kind: row.kind || "each",
      name: row.name || "",
      amount: Number(row.amount || 0),
      debit_account: row.debitAccount || row.debit_account || "",
      debit_account_name: row.debitAccountName || row.debit_account_name || "",
      credit_account: row.creditAccount || row.credit_account || "",
      credit_account_name: row.creditAccountName || row.credit_account_name || "",
      notes: row.notes || "",
      statement: row.statement || "",
    });
    ids.add(id);
    added++;
  }
  return added;
}

export async function handleGetLedger(req, res, ctx) {
  const ownerKey = String(new URL(req.url, "http://x").searchParams.get("ownerKey") || "");
  ok(res, { rows: listLedger(ctx.license.id, ownerKey) });
}

export async function handlePostLedger(req, res, ctx) {
  const body = await readJson(req);
  const entries = Array.isArray(body?.entries) ? body.entries : [];
  if (!entries.length) return fail(res, 400, "لا توجد سجلات.");
  const added = appendLedger(ctx.license.id, entries);
  ok(res, { added });
}

export async function handleReplaceLedger(req, res, ctx) {
  const body = await readJson(req);
  const entries = Array.isArray(body?.entries) ? body.entries : [];
  dbApi.ledger_entries().delete((r) => r.license_id === ctx.license.id);
  appendLedger(ctx.license.id, entries);
  ok(res, { count: entries.length });
}
