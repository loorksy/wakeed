function cleanAmount(v) {
  const t = String(v ?? "")
    .replace(/,/g, "")
    .replace(/٫/g, "")
    .trim();
  if (!t) return "";
  if (!/^\d+(\.\d+)?$/.test(t)) return "";
  return t;
}

function isAccount(v) {
  const t = String(v ?? "").trim();
  return /^\d{2,}([-\/]\S*)?$/.test(t);
}

function parseSide(v) {
  const t = String(v ?? "").trim();
  if (/^دائن|credit$/i.test(t)) return "credit";
  if (/^مدين|debit$/i.test(t)) return "debit";
  return "";
}

function pushLine(rows, name, acc, amount, side) {
  const amt = cleanAmount(amount);
  if (!amt || !name) return;
  if (side === "credit") {
    rows.push({ account: acc, description: name, debit: "", credit: amt });
  } else {
    rows.push({ account: acc, description: name, debit: amt, credit: "" });
  }
}

function parseRowsFromTable(text, defaultDebitAcc = "555", defaultCreditAcc = "9830") {
  const raw = String(text || "").replace(/^\uFEFF/, "").trim();
  if (!raw) return [];
  const lines = raw.split(/\r?\n/).filter((l) => l.trim());
  if (!lines.length) return [];

  const delim = lines[0].includes("\t") ? "\t" : lines[0].includes(";") ? ";" : ",";
  const split = (line) => line.split(delim).map((c) => c.trim().replace(/^"|"$/g, ""));

  const firstRow = split(lines[0]);
  const hasHeader = firstRow.some((h) =>
    /حساب|بيان|عميل|مدين|دائن|مبلغ|نوع|account|customer|name|debit|credit|type/i.test(h)
  );
  const startIdx = hasHeader ? 1 : 0;
  const rows = [];
  const pending = [];

  for (let i = startIdx; i < lines.length; i++) {
    const cells = split(lines[i]).filter((c, idx, arr) => c || idx < arr.length - 1);
    if (!cells.some(Boolean)) continue;

    if (cells.length >= 6) {
      const dName = cells[0];
      const dAcc = cells[1] || defaultDebitAcc;
      const dVal = cleanAmount(cells[2]);
      const cName = cells[3] || dName;
      const cAcc = cells[4] || defaultCreditAcc;
      const cVal = cleanAmount(cells[5]) || dVal;
      if (dVal) rows.push({ account: dAcc, description: dName, debit: dVal, credit: "" });
      if (cVal) rows.push({ account: cAcc, description: cName, debit: "", credit: cVal });
      continue;
    }

    if (cells.length === 5) {
      const name = cells[0];
      const dAcc = cells[1] || defaultDebitAcc;
      const dVal = cleanAmount(cells[2]);
      const cAcc = cells[3] || defaultCreditAcc;
      const cVal = cleanAmount(cells[4]) || dVal;
      if (dVal) rows.push({ account: dAcc, description: name, debit: dVal, credit: "" });
      if (cVal) rows.push({ account: cAcc, description: name, debit: "", credit: cVal });
      continue;
    }

    if (cells.length === 4) {
      const side = parseSide(cells[3]);
      if (side && isAccount(cells[1]) && cleanAmount(cells[2])) {
        pushLine(rows, cells[0], cells[1], cells[2], side);
        continue;
      }
      if (isAccount(cells[0])) {
        const dVal = cleanAmount(cells[2]);
        const cVal = cleanAmount(cells[3]);
        rows.push({
          account: cells[0],
          description: cells[1],
          debit: dVal,
          credit: cVal,
        });
        continue;
      }
      const dVal = cleanAmount(cells[2]);
      const cVal = cleanAmount(cells[3]);
      rows.push({
        account: isAccount(cells[1]) ? cells[1] : dVal ? defaultDebitAcc : defaultCreditAcc,
        description: cells[0],
        debit: dVal,
        credit: cVal,
      });
      continue;
    }

    if (cells.length === 3) {
      const name = cells[0];
      const amt = cleanAmount(cells[1]);
      const creditAcc = String(cells[2] || "").trim();
      if (amt && creditAcc) {
        rows.push({ account: defaultDebitAcc, description: name, debit: amt, credit: "" });
        rows.push({ account: creditAcc, description: name, debit: "", credit: amt });
        continue;
      }
      continue;
    }

    if (cells.length === 2) {
      const name = cells[0];
      const amt = cleanAmount(cells[1]);
      if (amt) {
        rows.push({ account: defaultDebitAcc, description: name, debit: amt, credit: "" });
        rows.push({ account: defaultCreditAcc, description: name, debit: "", credit: amt });
      }
    }
  }

  for (let i = 0; i < pending.length; i += 2) {
    const a = pending[i];
    const b = pending[i + 1];
    pushLine(rows, a.name, a.acc, a.amt, "debit");
    if (b) pushLine(rows, b.name, b.acc, b.amt, "credit");
  }

  return rows;
}

function groupCustomerRows(rows) {
  const groups = [];
  for (let i = 0; i < (rows || []).length; i += 2) {
    const pair = rows.slice(i, i + 2);
    if (pair.length < 2) continue;
    groups.push({
      name: pair[0].description || pair[1].description || "",
      rows: pair,
    });
  }
  return groups;
}

const SHEET_TEMPLATE = [
  ["الاسم", "المبلغ", "الدائن"],
  ["احمد الاحمد", "1500", "9830"],
  ["محمد الاحمد", "2000", "9830"],
  ["خالد الخالد", "3500", "9830"],
]
  .map((row) => row.join("\t"))
  .join("\n");
